# Power Kothi - Android app (Flutter)

The app connects to `https://erp.powerkothi.in/power/power-kothi/api/v1/`.
To use another server, build with `--dart-define=API_BASE=https://yourdomain.com/api/v1/`.

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

## Push notifications
Without this step the app works and push stays off.
Create a Firebase Android app, put `google-services.json` in `android/app/`, and add the Google Services Gradle plugin as Firebase's setup page shows.
Then paste the Firebase service account JSON in Admin > Settings.

## Maps
The app uses OpenStreetMap tiles. Their public server is for light use; for real traffic, switch `urlTemplate` to a paid tile provider.
