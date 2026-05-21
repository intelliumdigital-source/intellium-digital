# SweldoTrack Premium Verifier

This backend verifies Google Play Billing subscriptions for SweldoTrack.
It is intended for the premium product `sweldotrack_premium_monthly` on
Android only.

## Endpoint

- Route: `POST /verify-premium`
- Health check: `GET /healthz`

## Flutter build-time variables

Use these Flutter defines in release builds:

- `SWELDOTRACK_PREMIUM_VERIFY_URL`
- `SWELDOTRACK_PREMIUM_VERIFY_AUTH`

## Backend environment variables

Required:

- `SWELDOTRACK_PREMIUM_VERIFY_AUTH`
- `PACKAGE_NAME=com.intelliumdigital.sweldotrack`
- `EXPECTED_PRODUCT_ID=sweldotrack_premium_monthly`

Optional hardening:

- `PREMIUM_VERIFY_RATE_LIMIT_MAX`
- `PREMIUM_VERIFY_RATE_LIMIT_WINDOW_MS`

Google Play credentials:

Preferred on Cloud Run:

- No JSON key file in the repo
- Use the Cloud Run runtime service account with Google Play Android
  Developer API access

Optional fallback secret-based configuration:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

Optional split secret configuration:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY`
- `GOOGLE_PLAY_SERVICE_ACCOUNT_PROJECT_ID`

Do not commit real secrets.

## Request auth

The verifier expects:

- `Authorization: Bearer <SWELDOTRACK_PREMIUM_VERIFY_AUTH>`

No alternate Flutter auth define or fallback request header should be used.

## Request contract

The Flutter app sends:

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

The verifier accepts only:

- `productId=sweldotrack_premium_monthly`
- `packageName=com.intelliumdigital.sweldotrack`
- `platform=android`
- `purchaseStatus` of `purchased` or `restored`
- non-empty `purchaseToken`

Pending, canceled, failed, malformed, or unknown purchase states must not
unlock premium.

## Verification behavior

The verifier:

1. Validates the request body and auth header.
2. Calls Google Play Developer API using
   `purchases.subscriptionsv2.get`.
3. Uses the incoming `packageName` and `purchaseToken`.
4. Confirms the returned subscription is active.
5. Confirms the subscription has not expired.
6. Confirms the matching line item belongs to
   `sweldotrack_premium_monthly`.
7. If the verified active subscription is not yet acknowledged, calls
   `purchases.subscriptions.acknowledge` using:
   - `packageName`
   - `subscriptionId=productId`
   - `token=purchaseToken`
8. Fails closed if acknowledgement cannot be completed.

## Success response

Premium should unlock only when the verifier returns:

```json
{
  "verified": true,
  "active": true,
  "productId": "sweldotrack_premium_monthly",
  "expiryDate": "2026-06-05T00:00:00.000Z",
  "message": "Premium verified."
}
```

The backend may also include `ok` and a nested `entitlement` object, but
Flutter should rely on the fields above.

## Rejected purchase response

Receipt-level rejections return:

```json
{
  "verified": false,
  "active": false,
  "productId": "sweldotrack_premium_monthly",
  "message": "Receipt rejected."
}
```

Examples:

- invalid token
- expired subscription
- canceled or revoked subscription
- wrong product
- wrong package
- non-verifiable purchase status
- acknowledgement failure after verification

## Error responses

Malformed, unauthorized, rate-limited, or backend-level failures return
non-2xx JSON with an `error` object and a fail-closed premium state.

Examples:

- missing auth returns `401`
- malformed JSON returns `400`
- missing required fields return `400`
- Google Play auth/config issues return fail-closed responses

## Deployment outline

1. Create a Google Cloud project.
2. Enable Cloud Run and Google Play Android Developer API.
3. Deploy the verifier to Cloud Run.
4. Configure:
   - `SWELDOTRACK_PREMIUM_VERIFY_AUTH`
   - `PACKAGE_NAME=com.intelliumdigital.sweldotrack`
   - `EXPECTED_PRODUCT_ID=sweldotrack_premium_monthly`
5. Use the deployed URL plus `/verify-premium` as
   `SWELDOTRACK_PREMIUM_VERIFY_URL`.

## Production checklist

- Product `sweldotrack_premium_monthly` exists in Play Console
- Subscription is active
- Base plan is active
- Cloud Run service account has Google Play Android Developer API access
- Service account is invited in Play Console with subscription/order access
- App is installed from Google Play testing or production, not a direct APK
- Real production billing checks use a normal non-license-tester Google account
