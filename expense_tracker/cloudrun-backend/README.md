# SweldoTrack Cloud Run Backend

`/verify-premium` requires `Authorization: Bearer <SWELDOTRACK_PREMIUM_VERIFY_AUTH>` in production.
For backward compatibility, the verifier also accepts `x-verify-auth` and `x-api-key`.
Requests with a missing secret return `401`, wrong secrets return `403`, and requests are rejected before Google Play verification runs.

Referral storage uses Firestore by default.
Local file storage is only enabled when `REFERRAL_STORE_MODE=file` is set explicitly.
