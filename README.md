# GYM Scale

BLE-only ESP32 load-cell scale firmware and a Flutter companion app. The scale filters HX711 readings and publishes a versioned measurement packet; the app handles BLE reception and local measurement / food workflows.

## Hardware and firmware

- ESP32 with HX711, DOUT on GPIO5 and clock on GPIO18; channel A, gain 128.
- Startup tare, a five-reading median window, and a Kalman-style denoiser.
- Configured scale factor: 420 counts/gram; configured capacity: 10,000 grams. Calibrate these values against the actual sensor before relying on measurements.
- A 16-byte version-1 BLE packet carries flags, sequence, uptime, filtered grams, and raw delta.
- Notifications are limited to one every 200 ms. Ready, warming-up, saturation, overload, and stale-sensor states are represented in the firmware.

Build firmware with `pio run`. The PlatformIO configuration declares HX711 and NimBLE-Arduino. This prototype is not a certified weighing instrument.

## Mobile app

See `mobile/gym_scale_app/README.md`. The allowlisted Dart source, tests, preparation script, package lockfile, and Bluetooth permission metadata are included. Generated Flutter runners, dependency caches, binaries, and signing files are excluded. Use the preparation script to generate the complete local runner scaffolding before building.

From `mobile/gym_scale_app`, run `flutter pub get` and `flutter test` after preparing the Flutter project. No GitHub Actions APK workflow is included in this initial upload; build an APK locally with `flutter build apk --release`.
