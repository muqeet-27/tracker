# HSE Tracker (Offline, SQLite, PIN Lock)

**App name:** HSE Tracker  
**Features:** Daily attendance, customizable shifts, per-hour/per-shift wages, per-worker custom rates, weekly wages & payments, English+Hindi labels, PIN lock (default 1234).

## First Run
- Default PIN is **1234**. Tap **Change PIN** to set your own.

## Build & Run (Android)
1. Install Flutter (macOS): https://docs.flutter.dev/get-started/install/macos
2. In Terminal:
   ```bash
   cd ~/Downloads/hse_tracker
   flutter create .
   flutter pub get
   flutter run
   ```
3. Build APK:
   ```bash
   flutter build apk --release
   # APK: build/app/outputs/flutter-apk/app-release.apk
   ```

## Wage Formula
`earned = (hours_override OR shift.default_hours) × (worker.custom_rate OR shift.hourly_rate)`
