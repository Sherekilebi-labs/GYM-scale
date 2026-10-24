#include <Arduino.h>
#include <HX711.h>
#include <NimBLEDevice.h>

// Wiring from ESP32_HX711_Load_Cell_Wiring_Schematic.md
constexpr uint8_t LOADCELL_DOUT_PIN = 5;
constexpr uint8_t LOADCELL_SCK_PIN = 18;
constexpr uint8_t HX711_GAIN = 128;  // Channel A, gain 128.

constexpr char BLE_DEVICE_NAME[] = "GYM-Scale";
constexpr char SCALE_SERVICE_UUID[] = "7e57c000-6f7a-4b64-9c98-7fdc2d2f7c01";
constexpr char MEASUREMENT_CHARACTERISTIC_UUID[] = "7e57c001-6f7a-4b64-9c98-7fdc2d2f7c01";

// Calibrate this with a known mass. If weight moves negative when loaded,
// either make this value negative or swap A+ and A- on the HX711.
constexpr float CALIBRATION_COUNTS_PER_GRAM = 420.0f;
constexpr float LOAD_CELL_CAPACITY_GRAMS = 10000.0f;

constexpr uint8_t TARE_SAMPLE_COUNT = 20;
constexpr uint8_t MEDIAN_WINDOW = 5;
constexpr uint8_t STARTUP_DISCARD_READS = 4;

constexpr float ZERO_DEADBAND_GRAMS = 0.4f;
constexpr float LARGE_STEP_GRAMS = 60.0f;
constexpr uint32_t HX711_STALE_MS = 1500;
constexpr uint32_t BLE_NOTIFY_INTERVAL_MS = 200;
constexpr int32_t HX711_MIN_VALUE = -8388608;
constexpr int32_t HX711_MAX_VALUE = 8388607;

constexpr uint8_t MEASUREMENT_PACKET_VERSION = 1;
constexpr uint8_t MEASUREMENT_FLAG_READY = 1 << 0;
constexpr uint8_t MEASUREMENT_FLAG_SATURATED = 1 << 1;
constexpr uint8_t MEASUREMENT_FLAG_OVERLOAD = 1 << 2;
constexpr uint8_t MEASUREMENT_FLAG_WARMING_UP = 1 << 3;

class KalmanDenoiser {
 public:
  void reset() {
    initialized_ = false;
    estimate_ = 0.0f;
    error_ = 1.0f;
  }

  float update(float measurement) {
    if (!initialized_ || fabsf(measurement - estimate_) > LARGE_STEP_GRAMS) {
      initialized_ = true;
      estimate_ = measurement;
      error_ = 1.0f;
      return estimate_;
    }

    error_ += processNoise_;
    const float gain = error_ / (error_ + measurementNoise_);
    estimate_ += gain * (measurement - estimate_);
    error_ *= (1.0f - gain);
    return estimate_;
  }

  bool initialized() const {
    return initialized_;
  }

 private:
  bool initialized_ = false;
  float estimate_ = 0.0f;
  float error_ = 1.0f;
  const float processNoise_ = 0.08f;
  const float measurementNoise_ = 5.0f;
};

struct __attribute__((packed)) MeasurementPacket {
  uint8_t version;
  uint8_t flags;
  uint16_t sequence;
  uint32_t uptimeMs;
  float grossGrams;
  int32_t rawDelta;
};

static_assert(sizeof(MeasurementPacket) == 16, "MeasurementPacket must stay 16 bytes");

class ScaleServerCallbacks final : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &connInfo) override {
    connected = true;
    Serial.print("BLE connected: ");
    Serial.println(connInfo.getAddress().toString().c_str());
    server->updateConnParams(connInfo.getConnHandle(), 24, 48, 0, 180);
  }

  void onDisconnect(NimBLEServer *server, NimBLEConnInfo &connInfo, int reason) override {
    connected = false;
    Serial.print("BLE disconnected: ");
    Serial.print(connInfo.getAddress().toString().c_str());
    Serial.print(" reason=");
    Serial.println(reason);
    NimBLEDevice::startAdvertising();
  }

 public:
  bool connected = false;
};

HX711 scale;
KalmanDenoiser denoiser;
NimBLECharacteristic *measurementCharacteristic = nullptr;
ScaleServerCallbacks serverCallbacks;

bool tareActive = true;
int64_t tareAccumulator = 0;
uint8_t tareSamples = 0;
uint8_t startupDiscardReads = STARTUP_DISCARD_READS;

int32_t medianBuffer[MEDIAN_WINDOW] = {0};
uint8_t medianIndex = 0;
uint8_t medianCount = 0;

float filteredGrams = 0.0f;
bool hx711Saturated = false;
bool scaleOverloaded = false;
uint32_t lastSampleMs = 0;
uint32_t rawReadCount = 0;
uint32_t lastDebugPrintMs = 0;
uint32_t lastBleNotifyMs = 0;
uint16_t measurementSequence = 0;
int32_t lastRaw = 0;
int32_t lastMedianRaw = 0;
bool haveRaw = false;

bool isHx711Saturated(int32_t raw) {
  return raw <= HX711_MIN_VALUE + 4 || raw >= HX711_MAX_VALUE - 4;
}

bool scaleReady() {
  return !tareActive && denoiser.initialized() &&
         lastSampleMs != 0 &&
         millis() - lastSampleMs <= HX711_STALE_MS &&
         !hx711Saturated &&
         !scaleOverloaded;
}

int32_t medianOfRecentSamples(int32_t sample) {
  medianBuffer[medianIndex] = sample;
  medianIndex = (medianIndex + 1) % MEDIAN_WINDOW;
  if (medianCount < MEDIAN_WINDOW) {
    ++medianCount;
  }

  int32_t sorted[MEDIAN_WINDOW];
  for (uint8_t i = 0; i < medianCount; ++i) {
    sorted[i] = medianBuffer[i];
  }

  for (uint8_t i = 1; i < medianCount; ++i) {
    const int32_t key = sorted[i];
    int8_t j = i - 1;
    while (j >= 0 && sorted[j] > key) {
      sorted[j + 1] = sorted[j];
      --j;
    }
    sorted[j + 1] = key;
  }

  return sorted[medianCount / 2];
}

void resetFiltering() {
  denoiser.reset();
  medianIndex = 0;
  medianCount = 0;
  filteredGrams = 0.0f;
  scaleOverloaded = false;
}

void startStartupTare() {
  tareActive = true;
  tareAccumulator = 0;
  tareSamples = 0;
  resetFiltering();
}

void finishStartupTare() {
  if (tareSamples == 0) {
    return;
  }

  scale.set_offset(static_cast<long>(tareAccumulator / tareSamples));
  tareActive = false;
  resetFiltering();
}

void maybePrintDebugLine() {
  const uint32_t now = millis();
  if (now - lastDebugPrintMs < 500) {
    return;
  }

  lastDebugPrintMs = now;
  Serial.print("raw=");
  Serial.print(lastRaw);
  Serial.print(" median=");
  Serial.print(lastMedianRaw);
  Serial.print(" offset=");
  Serial.print(scale.get_offset());
  Serial.print(" rawDelta=");
  Serial.print(lastMedianRaw - scale.get_offset());
  Serial.print(" grossGrams=");
  Serial.print(filteredGrams, 2);
  Serial.print(" ready=");
  Serial.print(scaleReady() ? "yes" : "no");
  Serial.print(" taring=");
  Serial.print(tareActive ? "yes" : "no");
  Serial.print(" saturated=");
  Serial.print(hx711Saturated ? "yes" : "no");
  Serial.print(" overload=");
  Serial.print(scaleOverloaded ? "yes" : "no");
  Serial.print(" ble=");
  Serial.println(serverCallbacks.connected ? "connected" : "advertising");
}

void processScaleReading() {
  if (!scale.is_ready()) {
    return;
  }

  const int32_t raw = static_cast<int32_t>(scale.read());
  lastSampleMs = millis();
  lastRaw = raw;
  haveRaw = true;
  ++rawReadCount;

  hx711Saturated = isHx711Saturated(raw);
  if (hx711Saturated) {
    lastMedianRaw = raw;
    filteredGrams = 0.0f;
    scaleOverloaded = false;
    maybePrintDebugLine();
    return;
  }

  if (startupDiscardReads > 0) {
    --startupDiscardReads;
    maybePrintDebugLine();
    return;
  }

  if (tareActive) {
    tareAccumulator += raw;
    ++tareSamples;
    if (tareSamples >= TARE_SAMPLE_COUNT) {
      finishStartupTare();
    }
    maybePrintDebugLine();
    return;
  }

  lastMedianRaw = medianOfRecentSamples(raw);
  float grams = (static_cast<float>(lastMedianRaw) - scale.get_offset()) / scale.get_scale();
  if (fabsf(grams) < ZERO_DEADBAND_GRAMS) {
    grams = 0.0f;
  }

  filteredGrams = denoiser.update(grams);
  if (fabsf(filteredGrams) < ZERO_DEADBAND_GRAMS) {
    filteredGrams = 0.0f;
  }

  scaleOverloaded = fabsf(filteredGrams) > LOAD_CELL_CAPACITY_GRAMS;
  maybePrintDebugLine();
}

uint8_t currentMeasurementFlags() {
  uint8_t flags = 0;
  if (scaleReady()) {
    flags |= MEASUREMENT_FLAG_READY;
  }
  if (hx711Saturated) {
    flags |= MEASUREMENT_FLAG_SATURATED;
  }
  if (scaleOverloaded) {
    flags |= MEASUREMENT_FLAG_OVERLOAD;
  }
  if (tareActive || startupDiscardReads > 0 || !denoiser.initialized()) {
    flags |= MEASUREMENT_FLAG_WARMING_UP;
  }
  return flags;
}

MeasurementPacket buildMeasurementPacket() {
  MeasurementPacket packet = {};
  packet.version = MEASUREMENT_PACKET_VERSION;
  packet.flags = currentMeasurementFlags();
  packet.sequence = measurementSequence++;
  packet.uptimeMs = millis();
  packet.grossGrams = filteredGrams;
  packet.rawDelta = lastMedianRaw - scale.get_offset();
  return packet;
}

void publishBleMeasurement(bool forceReadValue = false) {
  if (measurementCharacteristic == nullptr) {
    return;
  }

  const uint32_t now = millis();
  if (!forceReadValue && now - lastBleNotifyMs < BLE_NOTIFY_INTERVAL_MS) {
    return;
  }

  lastBleNotifyMs = now;
  const MeasurementPacket packet = buildMeasurementPacket();
  measurementCharacteristic->setValue(reinterpret_cast<const uint8_t *>(&packet), sizeof(packet));
  if (serverCallbacks.connected) {
    measurementCharacteristic->notify();
  }
}

void setupBle() {
  NimBLEDevice::init(BLE_DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  NimBLEServer *server = NimBLEDevice::createServer();
  server->setCallbacks(&serverCallbacks);

  NimBLEService *service = server->createService(SCALE_SERVICE_UUID);
  measurementCharacteristic = service->createCharacteristic(
      MEASUREMENT_CHARACTERISTIC_UUID,
      NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

  publishBleMeasurement(true);
  NimBLEAdvertising *advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(SCALE_SERVICE_UUID);
  advertising->setName(BLE_DEVICE_NAME);
  advertising->enableScanResponse(true);
  advertising->start();

  Serial.print("BLE advertising as ");
  Serial.println(BLE_DEVICE_NAME);
  Serial.print("Service UUID: ");
  Serial.println(SCALE_SERVICE_UUID);
}

void setup() {
  Serial.begin(115200);
  delay(200);

  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN, HX711_GAIN);
  scale.set_scale(CALIBRATION_COUNTS_PER_GRAM);
  scale.set_offset(0);
  startStartupTare();

  setupBle();
}

void loop() {
  processScaleReading();
  publishBleMeasurement();
  delay(2);
}
