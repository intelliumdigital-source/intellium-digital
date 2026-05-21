# SweldoTrack Premium Verifier on Cloud Run

This verifier is designed for Google Cloud Run and verifies the Android
subscription `sweldotrack_premium_monthly` for
`com.intelliumdigital.sweldotrack`.

## Service endpoint

- Health check: `GET /healthz`
- Verification: `POST /verify-premium`

Cloud Run URL format:

- `https://YOUR-SERVICE-NAME-<hash>-<region>.run.app/verify-premium`

Use that full verification URL for the Flutter define:

- `SWELDOTRACK_PREMIUM_VERIFY_URL=https://YOUR-CLOUD-RUN-URL/verify-premium`
- `SWELDOTRACK_PREMIUM_VERIFY_AUTH=YOUR_LONG_RANDOM_SECRET`

The Flutter app and backend use only this auth scheme:

- `Authorization: Bearer <SWELDOTRACK_PREMIUM_VERIFY_AUTH>`

## Environment variables

Required:

- `SWELDOTRACK_PREMIUM_VERIFY_AUTH`
- `PACKAGE_NAME=com.intelliumdigital.sweldotrack`
- `EXPECTED_PRODUCT_ID=sweldotrack_premium_monthly`

Optional:

- `PREMIUM_VERIFY_RATE_LIMIT_MAX`
- `PREMIUM_VERIFY_RATE_LIMIT_WINDOW_MS`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PROJECT_ID`

Do not commit real values.

## Google Cloud setup

1. Create or choose a Google Cloud project.
2. Enable these APIs:
   - Cloud Run API
   - Cloud Build API
   - Artifact Registry API
   - Google Play Android Developer API
3. Create a user-managed service account named
   `sweldotrack-premium-verifier`.
4. Deploy Cloud Run using that service account as the runtime identity.
5. Invite the service account email in Play Console under Users and
   permissions.
6. Grant these Play Console permissions:
   - View financial data, orders, and cancellation survey responses
   - Manage orders and subscriptions

## Why no JSON key is preferred

Cloud Run can call Google APIs with its runtime service account using
Application Default Credentials. That is the preferred production setup because
no long-lived private key has to be stored in Flutter or committed to the repo.

Only use `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` or the split
`GOOGLE_PLAY_SERVICE_ACCOUNT_*` secrets when you intentionally need a fallback
credential source outside standard Cloud Run service identity.

## Request contract

The Flutter app should send this JSON body to `POST /verify-premium`:

```json
{
  "productId": "sweldotrack_premium_monthly",
  "packageName": "com.intelliumdigital.sweldotrack",
  "purchaseToken": "purchase.verificationData.serverVerificationData",
  "localReceipt": "purchase.verificationData.localVerificationData",
  "verificationSource": "google_play",
  "purchaseStatus": "purchased",
  "purchaseId": "purchase-id",
  "transactionDateMillis": 1718409600000,
  "platform": "android"
}
```

The verifier requires:

- `productId` to match `sweldotrack_premium_monthly`
- `packageName` to match `com.intelliumdigital.sweldotrack`
- `purchaseToken` to be present
- `purchaseStatus` to be `purchased` or `restored`
- `platform` to be `android`

After the backend confirms a valid active subscription, it acknowledges the
initial subscription purchase from the backend when
`acknowledgementState` is not already acknowledged. If acknowledgement fails,
the backend fails closed and does not return premium as active.

## Response contract

Successful verification responses are Flutter-compatible:

```json
{
  "verified": true,
  "active": true,
  "productId": "sweldotrack_premium_monthly",
  "expiryDate": "2026-06-05T00:00:00.000Z",
  "message": "Premium verified."
}
```

Receipt-level rejections return:

```json
{
  "verified": false,
  "active": false,
  "productId": "sweldotrack_premium_monthly",
  "message": "Receipt rejected."
}
```

The backend may also include `ok` and a nested `entitlement` object.

## Flutter build commands

```powershell
flutter build apk --release --dart-define=SWELDOTRACK_PREMIUM_VERIFY_URL=https://YOUR-CLOUD-RUN-URL/verify-premium --dart-define=SWELDOTRACK_PREMIUM_VERIFY_AUTH=YOUR_AUTH_SECRET
```

```powershell
flutter build appbundle --release --dart-define=SWELDOTRACK_PREMIUM_VERIFY_URL=https://YOUR-CLOUD-RUN-URL/verify-premium --dart-define=SWELDOTRACK_PREMIUM_VERIFY_AUTH=YOUR_AUTH_SECRET
```

## Backend testing checklist

- `GET /healthz` returns `200` and `ok: true`
- `POST /verify-premium` without auth returns `401`
- `POST /verify-premium` with malformed JSON returns `400`
- `POST /verify-premium` with bad body returns `400`
- `POST /verify-premium` with missing `purchaseToken` returns `400`
- `POST /verify-premium` with missing `platform` returns `400`
- `POST /verify-premium` with invalid token returns `200` with
  `verified: false` and `active: false`
- active unacknowledged subscriptions are acknowledged by the backend
- Real internal-testing Play purchase returns `verified: true` and
  `active: true`

## Play Console setup

1. Ensure the product `sweldotrack_premium_monthly` exists as an active
   subscription.
2. Ensure the base plan is active.
3. Add testers to internal or closed testing when using Play test tracks.
4. Install the app from Play testing or production, not from a direct APK.
5. For a real live production billing check, use a normal non-license-tester
   Google account.

## Release build reminder

Use the same `SWELDOTRACK_PREMIUM_VERIFY_AUTH` value in both places:

- Cloud Run environment variables
- Flutter release build `--dart-define`
