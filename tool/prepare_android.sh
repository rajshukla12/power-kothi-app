#!/usr/bin/env bash
# Creates the android/ folder and applies the Power Kothi settings. Run from the app folder.
set -e
flutter create . --platforms=android --org in.powerkothi --project-name power_kothi
rm -rf test
cp tool/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
sed -i.bak -E 's/(org\.jetbrains\.kotlin\.android" version ")[0-9.]+/\11.9.24/' android/settings.gradle
sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 23/' android/app/build.gradle
rm -f android/settings.gradle.bak android/app/build.gradle.bak
flutter pub get
dart run flutter_launcher_icons
