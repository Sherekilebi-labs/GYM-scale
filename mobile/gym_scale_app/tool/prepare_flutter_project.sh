#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

flutter create . --platforms=android,ios

python3 - <<'PY'
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
manifest.write_text("""<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />

    <application
        android:label="GYM Scale"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
""")

main_activity = Path("android/app/src/main/kotlin/com/example/gym_scale_app/MainActivity.kt")
main_activity.parent.mkdir(parents=True, exist_ok=True)
main_activity.write_text("""package com.example.gym_scale_app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
""")

plist = Path("ios/Runner/Info.plist")
if plist.exists():
    text = plist.read_text()
    insert = """  <key>NSBluetoothAlwaysUsageDescription</key>
  <string>GYM Scale uses Bluetooth to read measurements from the ESP32 scale.</string>
  <key>NSBluetoothPeripheralUsageDescription</key>
  <string>GYM Scale uses Bluetooth to read measurements from the ESP32 scale.</string>
"""
    if "NSBluetoothAlwaysUsageDescription" not in text:
        text = text.replace("</dict>", insert + "</dict>")
        plist.write_text(text)
PY

flutter pub get
