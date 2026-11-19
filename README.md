# Power Kothi - Android app (Flutter)

The app connects to `https://erp.powerkothi.in/power/power-kothi/api/v1/`.
To use another server, build with `--dart-define=API_BASE=https://yourdomain.com/api/v1/`.

## Power Kothi Partner app (v1.1.0)
Flow: mobile number + OTP → one-time registration (name, phone, email, Aadhaar front/back, selfie) → Dashboard.
Bottom tabs: Dashboard (earnings, lead pipeline, leaderboard), Submit (owner, phone, property type, current location, camera photos), My leads (live status), Wallet & payouts.
No map in the app. Server routes are listed in `docs/PARTNER_API.md`.

## Make the APK online (no Flutter needed)
1. Create a free private repository on GitHub.
2. Upload everything in this folder, including the hidden `.github` folder.
3. Open the Actions tab, then "Build Power Kothi APK". It runs by itself after the upload; "Run workflow" starts it again.
4. When it turns green (about 10 minutes), open the run and download `power-kothi-apk` from Artifacts. The APK is inside that zip.

## Make the APK on your computer
Needs Flutter 3.27+, Android Studio and Git Bash on Windows.
```
bash tool/prepare_android.sh
flutter build apk --release
```
The APK is at `build/app/outputs/flutter-apk/app-release.apk`.

## Before Play Store
These APKs use a debug signature, fine for testing on phones. Play Store needs your own signing key and `flutter build appbundle`.

## v1.3.0
- Firebase push and share_plus removed (they broke the build/start without google-services.json).
- Login is by mobile OTP only (test OTP 1234). An extra Aadhaar OTP step can be switched on with Admin > Settings > KYC > `kyc_required_in_app` = 1.

## Maps
The app uses OpenStreetMap tiles. Their public server is for light use; for real traffic, switch `urlTemplate` to a paid tile provider.
