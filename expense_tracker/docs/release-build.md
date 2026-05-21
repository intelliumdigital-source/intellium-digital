# SweldoTrack Release Build

This project reads the premium verifier configuration from Flutter
`--dart-define` values. Premium remains fail-closed if the verifier URL or auth
secret is missing or verification fails.

## PowerShell environment variables

Set these in the same PowerShell session before building:

```powershell
$env:SWELDOTRACK_PREMIUM_VERIFY_URL="https://YOUR-CLOUD-RUN-URL/verify-premium"
```

```powershell
$env:SWELDOTRACK_PREMIUM_VERIFY_AUTH="YOUR_LONG_RANDOM_SECRET"
```

## Run the release build script

```powershell
.\tools\build_sweldotrack_release.ps1
```

The script runs these commands in order and stops on the first failure:

- `flutter clean`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --release ...`
- `flutter build appbundle --release ...`

## Expected outputs

APK:

- `build\app\outputs\flutter-apk\app-release.apk`

AAB:

- `build\app\outputs\bundle\release\app-release.aab`

APK is for local install and developer testing.

AAB is for Google Play Console upload.

## Install the APK locally

```powershell
adb devices
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

## Play Console upload

Upload the AAB to Play Console internal testing first.

## Cloud Run env reminder

The same auth secret used in PowerShell must also be configured on Cloud Run:

- `SWELDOTRACK_PREMIUM_VERIFY_AUTH=YOUR_LONG_RANDOM_SECRET`

Cloud Run must also have:

- `PACKAGE_NAME=com.intelliumdigital.sweldotrack`
- `EXPECTED_PRODUCT_ID=sweldotrack_premium_monthly`

## Play Console subscription reminder

The subscription product must exist in Play Console as:

- `sweldotrack_premium_monthly`

It must be a subscription with:

- active base plan
- pricing
- license testers
- internal or closed testing track testers

Install the app from the Play testing link for real billing tests.

## Important IAP testing note

Local APK testing can confirm that the app opens and the verifier URL is
configured, but Google Play Billing purchase testing should be done through a
Play Console internal or closed testing track. Do not mark IAP as
production-ready until purchase, cancel, pending, restore, already-owned, and
app restart behavior are tested.
