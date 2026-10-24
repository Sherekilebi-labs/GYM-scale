# GYM Scale Mobile App

Flutter app for the BLE-only ESP32 GYM Scale firmware.

## First-Time Flutter Setup

This repository contains the Dart app source plus permission metadata. On a machine with Flutter installed, generate the full Flutter runner scaffolding before building:

```sh
cd mobile/gym_scale_app
flutter create . --platforms=android,ios
flutter pub get
```

Or run the included preparation script, which also reapplies Bluetooth permission metadata:

```sh
cd mobile/gym_scale_app
bash tool/prepare_flutter_project.sh
```

If `flutter create` changes existing files, keep or re-apply these app-specific entries:

- Android: Bluetooth permissions in `android/app/src/main/AndroidManifest.xml`
- iOS: `NSBluetoothAlwaysUsageDescription` in `ios/Runner/Info.plist`

## Android Debug Install

1. Install Flutter SDK: https://docs.flutter.dev/install
2. Install Android Studio, Android SDK, platform tools, and a JDK: https://developer.android.com/studio
3. Run `flutter doctor` and resolve Android issues.
4. Enable Developer Options and USB Debugging on the Android phone.
5. Connect phone by USB and accept the RSA trust prompt.
6. Run:

```sh
cd mobile/gym_scale_app
flutter pub get
flutter run
```

## Android APK Install

Build the release APK:

```sh
cd mobile/gym_scale_app
flutter build apk --release
```

APK output:

```text
mobile/gym_scale_app/build/app/outputs/flutter-apk/app-release.apk
```

Transfer that APK to the phone, allow "Install unknown apps" for the file manager or browser used to open it, then install.

USB install after building:

```sh
cd mobile/gym_scale_app
flutter install
```

## ESP32 Pairing Flow

Flash the ESP32 firmware first, power the scale, then open the app. The app scans for the BLE service UUID and device name `GYM-Scale`, connects, and subscribes to measurement notifications.
