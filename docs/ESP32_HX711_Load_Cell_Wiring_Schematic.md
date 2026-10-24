# ESP32 + HX711 + Load Cell Wiring Schematic

Digital scale setup using a load cell, HX711 24-bit ADC/amplifier module, and an ESP32 with Wi-Fi and Bluetooth.

## Recommended ESP32 Board

Use an **ESP32-DevKitC V4 with ESP32-WROOM-32E**.

Why this board:

- ESP32-WROOM-32E provides **2.4 GHz Wi-Fi, Bluetooth, and Bluetooth LE**.
- ESP32-DevKitC V4 exposes most ESP32 GPIO pins on headers, which makes HX711 wiring simple.
- It uses 3.3 V GPIO logic, matching the recommended HX711 digital interface voltage for ESP32.
- It is widely supported by Arduino, ESP-IDF, MicroPython, and PlatformIO.

Avoid ESP32-C3/S3 boards if you specifically need **Bluetooth Classic**. They are fine for Wi-Fi and BLE projects, but the original ESP32-WROOM family is the safer default when "Wi-Fi/Bluetooth" is required.

## Parts

- ESP32-DevKitC V4, preferably ESP32-WROOM-32E variant
- HX711 load cell amplifier module
- 4-wire load cell
- Stable USB power supply for ESP32
- Jumper wires

## High-Level Schematic

```text
        4-wire load cell
   +------------------------+
   | Wheatstone bridge      |
   |                        |
   | Red    = Excitation +  |
   | Black  = Excitation -  |
   | Green  = Signal +      |
   | White  = Signal -      |
   +-----------+------------+
               |
               v
        +-------------+          +-------------------------------+
        | HX711 ADC   |          | ESP32-DevKitC V4              |
        | amplifier   |          | ESP32-WROOM-32E module        |
        |             |          | Wi-Fi + Bluetooth + BLE       |
        | E+ E- A+ A- |          |                               |
        | VCC GND     |<-------->| 3V3 GND                       |
        | DT  SCK     |<-------->| GPIO5 GPIO18                  |
        +-------------+          +-------------------------------+
```

## Pin-to-Pin Wiring

### Load Cell to HX711

Most 4-wire load cells use the color code below, but color codes are not universal. Check the load cell datasheet if available.

| Load cell wire | Function | HX711 pin |
| --- | --- | --- |
| Red | Excitation positive | `E+` |
| Black | Excitation negative | `E-` |
| Green | Signal positive | `A+` |
| White | Signal negative | `A-` |
| Shield/drain wire, if present | Cable shield | `GND`, at HX711/ESP32 end only |

Use HX711 **Channel A** (`A+` and `A-`) for the scale. Channel A is the normal load-cell input and supports the common high-gain scale modes.

### HX711 to ESP32

| HX711 pin | ESP32-DevKitC V4 pin | Purpose |
| --- | --- | --- |
| `VCC` or `VDD` | `3V3` | HX711 power and load-cell excitation |
| `GND` | `GND` | Common ground |
| `DT`, `DOUT`, or `DATA` | `GPIO5` | HX711 data output to ESP32 |
| `SCK`, `CLK`, or `PD_SCK` | `GPIO18` | ESP32 clock output to HX711 |
| `RATE`, if present | `GND` or leave default | 10 samples/sec, better noise rejection |

Recommended firmware constants:

```cpp
const int LOADCELL_DOUT_PIN = 5;
const int LOADCELL_SCK_PIN = 18;
```

## Complete Wiring Diagram

```text
ESP32-DevKitC V4                 HX711 module                 Load cell
ESP32-WROOM-32E

3V3 ---------------------------> VCC / VDD
GND ---------------------------> GND -----------------------> Shield/drain, optional

GPIO5 <------------------------- DT / DOUT / DATA
GPIO18 ------------------------> SCK / CLK / PD_SCK

                                  E+ ------------------------> Red
                                  E- ------------------------> Black
                                  A+ ------------------------> Green
                                  A- ------------------------> White

                                  B+ / B- -------------------> Not used
```

## Power and Logic Notes

- Power the HX711 from the ESP32 `3V3` pin for the safest wiring. The HX711 supports low-voltage operation, and this keeps the HX711 `DOUT` signal safe for the ESP32's 3.3 V GPIO pins.
- Do **not** power a typical HX711 breakout from 5 V unless you know its digital output level is 3.3 V safe or you add a level shifter on `DOUT`.
- The HX711 powers the load cell through `E+` and `E-`. Do not power the load cell directly from an ESP32 GPIO pin.
- Keep ESP32 ground, HX711 ground, and the load-cell shield/drain reference common.
- Put the HX711 close to the load cell when possible. The low-level analog signal between the load cell and HX711 is more noise-sensitive than the digital ESP32 connection.
- Twist `A+` with `A-`, and twist `E+` with `E-` for longer load-cell cable runs.
- Use 10 SPS mode for a scale unless faster readings are more important than noise performance.

## ESP32 GPIO Selection Notes

Recommended:

- `GPIO18` for HX711 `SCK`
- `GPIO5` for HX711 `DT/DOUT`

Avoid for this connection unless you have a specific reason:

- ESP32 boot strapping pins other than the requested `GPIO5`: `GPIO0`, `GPIO2`, `GPIO4`, `GPIO12`, `GPIO15`
- ESP32 input-only pins for `SCK`: `GPIO34` to `GPIO39`
- Pins already used by flash memory on some modules

`GPIO5` is also an ESP32 boot strapping pin. If the ESP32 fails to boot reliably with the HX711 connected, move `DT/DOUT` back to a non-strapping GPIO such as `GPIO19`, or make sure the HX711 `DOUT` line is not forced into a bad state during reset.

## Optional 6-Wire Load Cell Note

Some load cells have sense wires:

| 6-wire load cell function | HX711 connection if module has no sense pins |
| --- | --- |
| Excitation positive | `E+` |
| Sense positive | Tie to `E+` |
| Excitation negative | `E-` |
| Sense negative | Tie to `E-` |
| Signal positive | `A+` |
| Signal negative | `A-` |

## References

- Espressif ESP32-DevKitC V4 user guide: https://docs.espressif.com/projects/esp-dev-kits/en/latest/esp32/esp32-devkitc/user_guide.html
- Espressif ESP32-WROOM-32E / ESP32-WROOM-32UE datasheet: https://www.espressif.com/sites/default/files/documentation/esp32-wroom-32e_esp32-wroom-32ue_datasheet_en.pdf
- AVIA HX711 datasheet mirror: https://cdn.sparkfun.com/datasheets/Sensors/ForceFlex/hx711_english.pdf
