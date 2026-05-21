const crypto = require('crypto');
const {google} = require('googleapis');

const DEFAULT_PACKAGE_NAME = 'com.intelliumdigital.sweldotrack';
const DEFAULT_PRODUCT_ID = 'sweldotrack_premium_monthly';
const DEFAULT_SUCCESS_MESSAGE = 'Premium active';
const RECOVERABLE_FAILURE_MESSAGE =
  'Premium verification could not be completed right now.';
const PURCHASE_NOT_CONFIRMED_MESSAGE = 'Purchase could not be confirmed.';
const SUBSCRIPTION_NOT_ACTIVE_MESSAGE = 'Subscription is not active.';
const VERIFICATION_MODE = 'google_play';
const ANDROID_PUBLISHER_SCOPE =
  'https://www.googleapis.com/auth/androidpublisher';
const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);
const LEGACY_ACTIVE_PAYMENT_STATES = new Set([1, 2, 3]);
const VERIFIABLE_PURCHASE_STATUSES = new Set(['purchased', 'restored']);
const PRODUCT_ID_PATTERN = /^[a-z0-9][a-z0-9._]*$/;
const PACKAGE_NAME_PATTERN =
  /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/;
const ACKNOWLEDGED_STATE = 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
const PENDING_ACKNOWLEDGEMENT_STATE = 'ACKNOWLEDGEMENT_STATE_PENDING';
const MAX_PURCHASE_TOKEN_LENGTH = 4096;
const rateLimitBuckets = new Map();
let defaultReferralStore = null;

function trimString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function parsePositiveInteger(value, fallback) {
  const parsed = Number.parseInt(`${value || ''}`.trim(), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function parseExpiryDate(value) {
  if (value == null) return null;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (/^\d+$/.test(trimmed)) {
      const parsedInteger = Number.parseInt(trimmed, 10);
      return new Date(parsedInteger).toISOString();
    }
    const parsedDate = Date.parse(trimmed);
    return Number.isFinite(parsedDate) ? new Date(parsedDate).toISOString() : null;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return new Date(value).toISOString();
  }
  return null;
}

function toExpiryTimeMillis(expiryDate) {
  if (!expiryDate) return null;
  const parsed = Date.parse(expiryDate);
  return Number.isFinite(parsed) ? `${parsed}` : null;
}

function buildEntitlement({
  verified,
  active,
  recoverable = false,
  reason = null,
  productId = DEFAULT_PRODUCT_ID,
  packageName = DEFAULT_PACKAGE_NAME,
  expiryDate = null,
  message = null,
  verificationMode = VERIFICATION_MODE,
  subscriptionState = null,
  acknowledgementState = null,
  latestOrderId = null,
  isTestPurchase = false,
}) {
  const normalizedExpiryDate = parseExpiryDate(expiryDate);
  return {
    verified: Boolean(verified),
    active: Boolean(active),
    recoverable: Boolean(recoverable),
    reason: trimString(reason) || null,
    productId,
    packageName,
    expiryDate: normalizedExpiryDate,
    expiryTimeMillis: toExpiryTimeMillis(normalizedExpiryDate),
    message: trimString(message) || null,
    verificationMode,
    subscriptionState,
    acknowledgementState,
    latestOrderId,
    isTestPurchase: Boolean(isTestPurchase),
  };
}

function toPublicEntitlementFields(entitlement) {
  const verified = Boolean(entitlement?.verified);
  const active = Boolean(entitlement?.active);
  return {
    verified,
    active,
    isPremium: verified && active,
    recoverable: Boolean(entitlement?.recoverable),
    reason: entitlement?.reason ?? null,
    productId: entitlement?.productId ?? DEFAULT_PRODUCT_ID,
    packageName: entitlement?.packageName ?? DEFAULT_PACKAGE_NAME,
    expiryDate: entitlement?.expiryDate ?? null,
    expiryTimeMillis: entitlement?.expiryTimeMillis ?? null,
    message: entitlement?.message ?? null,
    verificationMode: entitlement?.verificationMode ?? VERIFICATION_MODE,
  };
}

function buildAcceptedResponse(entitlement) {
  const publicFields = toPublicEntitlementFields(entitlement);
  return {
    ok: Boolean(publicFields.verified && publicFields.active),
    ...publicFields,
    entitlement,
  };
}

function buildErrorResponse({
  code,
  message,
  productId = DEFAULT_PRODUCT_ID,
  packageName = DEFAULT_PACKAGE_NAME,
  recoverable = true,
}) {
  const entitlement = buildEntitlement({
    verified: false,
    active: false,
    recoverable,
    reason: code,
    productId,
    packageName,
    message,
  });

  return {
    ok: false,
    error: {
      code,
      message,
    },
    ...toPublicEntitlementFields(entitlement),
    entitlement,
  };
}

function sendJson(res, statusCode, body, extraHeaders = {}) {
  res.status(statusCode).set({
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
    ...extraHeaders,
  });
  res.send(body);
}

function timingSafeEqualString(left, right) {
  if (!left || !right) return false;
  const leftBuffer = Buffer.from(left, 'utf8');
  const rightBuffer = Buffer.from(right, 'utf8');
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function readRequestBody(req) {
  const {body} = req;
  if (body == null) return {};
  if (typeof body === 'string') {
    const trimmed = body.trim();
    return trimmed ? JSON.parse(trimmed) : {};
  }
  if (Buffer.isBuffer(body)) {
    const text = body.toString('utf8').trim();
    return text ? JSON.parse(text) : {};
  }
  if (typeof body === 'object') {
    return body;
  }
  throw new Error('Invalid JSON body.');
}

function resolveSharedSecret(env = process.env) {
  return (
    trimString(env.SWELDOTRACK_PREMIUM_VERIFY_AUTH) ||
    trimString(env.VERIFY_AUTH) ||
    trimString(env.API_KEY) ||
    trimString(env.VERIFY_API_KEY)
  );
}

function resolveVerifierConfig(env = process.env) {
  const packageNameFromEnv = trimString(env.PACKAGE_NAME);
  const productIdFromEnv = trimString(env.EXPECTED_PRODUCT_ID);
  const sharedSecret = resolveSharedSecret(env);

  return {
    packageName: packageNameFromEnv || DEFAULT_PACKAGE_NAME,
    expectedProductId: productIdFromEnv || DEFAULT_PRODUCT_ID,
    sharedSecret,
    packageNameConfigured: packageNameFromEnv.length > 0,
    productIdConfigured: productIdFromEnv.length > 0,
    authConfigured: sharedSecret.length > 0,
    rateLimitMax: parsePositiveInteger(
      env.PREMIUM_VERIFY_RATE_LIMIT_MAX,
      60,
    ),
    rateLimitWindowMs: parsePositiveInteger(
      env.PREMIUM_VERIFY_RATE_LIMIT_WINDOW_MS,
      60000,
    ),
  };
}

function getDefaultReferralStore() {
  if (!defaultReferralStore) {
    defaultReferralStore = require('./referral-store');
  }
  return defaultReferralStore;
}

function resolveGoogleCredentials(env = process.env) {
  const serviceAccountJson = trimString(env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON);
  if (serviceAccountJson) {
    const parsed = JSON.parse(serviceAccountJson);
    return {
      client_email: trimString(parsed.client_email),
      private_key: trimString(parsed.private_key).replace(/\\n/g, '\n'),
      project_id:
        trimString(parsed.project_id) ||
        trimString(env.GOOGLE_PLAY_SERVICE_ACCOUNT_PROJECT_ID),
    };
  }

  const clientEmail = trimString(env.GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL);
  const privateKey = trimString(
    env.GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY,
  ).replace(/\\n/g, '\n');
  const projectId =
    trimString(env.GOOGLE_PLAY_SERVICE_ACCOUNT_PROJECT_ID) ||
    trimString(env.GOOGLE_CLOUD_PROJECT);

  if (!clientEmail || !privateKey) {
    return null;
  }

  return {
    client_email: clientEmail,
    private_key: privateKey,
    project_id: projectId || undefined,
  };
}

function getGoogleAuthOptions(env = process.env) {
  const credentials = resolveGoogleCredentials(env);
  if (!credentials) {
    return {
      scopes: [ANDROID_PUBLISHER_SCOPE],
    };
  }

  return {
    scopes: [ANDROID_PUBLISHER_SCOPE],
    credentials,
  };
}

async function isGoogleAuthAvailable(env = process.env, deps = {}) {
  if (typeof deps.googleAuthAvailable === 'boolean') {
    return deps.googleAuthAvailable;
  }

  try {
    const authFactory =
      deps.getGoogleAuthClient ||
      (async () => {
        const auth = new google.auth.GoogleAuth(getGoogleAuthOptions(env));
        return auth.getClient();
      });
    await authFactory();
    return true;
  } catch (_) {
    return false;
  }
}

async function buildConfigCheckResponse(env = process.env, deps = {}) {
  const verifierConfig = resolveVerifierConfig(env);
  const googleAuthAvailable = await isGoogleAuthAvailable(env, deps);
  const ok =
    verifierConfig.packageNameConfigured &&
    verifierConfig.productIdConfigured &&
    verifierConfig.authConfigured &&
    googleAuthAvailable;

  return {
    ok,
    packageNameConfigured: verifierConfig.packageNameConfigured,
    productIdConfigured: verifierConfig.productIdConfigured,
    authConfigured: verifierConfig.authConfigured,
    googleAuthAvailable,
  };
}

async function createAndroidPublisherClient(env = process.env) {
  const auth = new google.auth.GoogleAuth(getGoogleAuthOptions(env));
  const authClient = await auth.getClient();
  return google.androidpublisher({
    version: 'v3',
    auth: authClient,
  });
}

function getAuthorizationToken(req) {
  const authorizationHeader = trimString(req.headers.authorization);
  if (authorizationHeader) {
    const bearerMatch = authorizationHeader.match(/^Bearer\s+(.+)$/i);
    if (bearerMatch) {
      return bearerMatch[1].trim();
    }

    return authorizationHeader;
  }

  const verifyAuthHeader = trimString(req.headers['x-verify-auth']);
  if (verifyAuthHeader) {
    return verifyAuthHeader;
  }

  const apiKeyHeader = trimString(req.headers['x-api-key']);
  if (apiKeyHeader) {
    return apiKeyHeader;
  }

  return '';
}

function getClientKey(req) {
  const forwardedFor = trimString(req.headers['x-forwarded-for']);
  if (forwardedFor) {
    return forwardedFor.split(',')[0].trim();
  }
  return (
    trimString(req.headers['x-real-ip']) ||
    trimString(req.socket?.remoteAddress) ||
    'unknown'
  );
}

function hashTokenFingerprint(token) {
  const normalized = trimString(token);
  if (!normalized) return null;
  return crypto
    .createHash('sha256')
    .update(normalized)
    .digest('hex')
    .slice(0, 16);
}

function buildSafeRequestMeta(body = {}) {
  const purchaseToken =
    trimString(body.purchaseToken) || trimString(body.serverVerificationData);
  return {
    packageName: trimString(body.packageName) || null,
    productId: trimString(body.productId) || null,
    platform: trimString(body.platform).toLowerCase() || null,
    purchaseStatus: trimString(body.purchaseStatus).toLowerCase() || null,
    hasPurchaseToken: purchaseToken.length > 0,
    tokenFingerprint: hashTokenFingerprint(purchaseToken),
  };
}

function logVerifierEvent(event, meta = {}, level = 'info') {
  const payload = {
    severity: level.toUpperCase(),
    component: 'premium_verifier',
    event,
    ...meta,
  };

  if (level === 'error') {
    console.error(JSON.stringify(payload));
    return;
  }
  if (level === 'warn') {
    console.warn(JSON.stringify(payload));
    return;
  }
  console.log(JSON.stringify(payload));
}

function enforceRateLimit(req, verifierConfig) {
  const maxRequests = verifierConfig.rateLimitMax;
  const windowMs = verifierConfig.rateLimitWindowMs;
  if (maxRequests <= 0 || windowMs <= 0) {
    return null;
  }

  const key = getClientKey(req);
  const now = Date.now();
  const existing = rateLimitBuckets.get(key);

  if (!existing || now >= existing.resetAt) {
    rateLimitBuckets.set(key, {
      count: 1,
      resetAt: now + windowMs,
    });
    return null;
  }

  existing.count += 1;
  if (existing.count <= maxRequests) {
    return null;
  }

  return Math.max(1, Math.ceil((existing.resetAt - now) / 1000));
}

function normalizeLineItems(subscriptionPurchase) {
  if (!subscriptionPurchase || !Array.isArray(subscriptionPurchase.lineItems)) {
    return [];
  }

  return subscriptionPurchase.lineItems.filter(
    (item) => item && typeof item === 'object',
  );
}

function resolveExpiryDate(lineItems) {
  const expiryTimestamps = lineItems
    .map((item) => parseExpiryDate(item.expiryTime))
    .filter(Boolean)
    .map((value) => Date.parse(value))
    .filter((value) => Number.isFinite(value))
    .sort((left, right) => right - left);

  if (expiryTimestamps.length === 0) {
    return null;
  }

  return new Date(expiryTimestamps[0]).toISOString();
}

function buildHandledFailureResponse({
  code,
  message,
  verifierConfig,
  payload,
}) {
  return buildErrorResponse({
    code,
    message,
    productId: verifierConfig.expectedProductId,
    packageName: payload?.packageName || verifierConfig.packageName,
    recoverable: false,
  });
}

function validateRequestPayload(body, verifierConfig) {
  const productId = trimString(body.productId);
  const packageName = trimString(body.packageName);
  const purchaseToken =
    trimString(body.purchaseToken) || trimString(body.serverVerificationData);
  const platform = trimString(body.platform).toLowerCase();
  const purchaseStatus = trimString(body.purchaseStatus).toLowerCase();
  const userId = trimString(body.userId);
  const purchaseId = trimString(body.purchaseId);

  if (!productId) {
    return {
      statusCode: 400,
      code: 'missing_product_id',
      message: 'Missing required field: productId.',
    };
  }
  if (!PRODUCT_ID_PATTERN.test(productId)) {
    return {
      statusCode: 400,
      code: 'invalid_product_id',
      message: 'Invalid productId format.',
      productId,
    };
  }
  if (!packageName) {
    return {
      statusCode: 400,
      code: 'missing_package_name',
      message: 'Missing required field: packageName.',
      productId,
      packageName: verifierConfig.packageName,
    };
  }
  if (packageName && !PACKAGE_NAME_PATTERN.test(packageName)) {
    return {
      statusCode: 400,
      code: 'invalid_package_name',
      message: 'Invalid packageName format.',
      productId,
      packageName,
    };
  }
  if (!purchaseToken) {
    return {
      statusCode: 400,
      code: 'missing_purchase_token',
      message: 'Missing required field: purchaseToken.',
      productId,
      packageName: verifierConfig.packageName,
    };
  }
  if (purchaseToken.length > MAX_PURCHASE_TOKEN_LENGTH) {
    return {
      statusCode: 400,
      code: 'invalid_purchase_token',
      message: 'Invalid purchaseToken length.',
      productId,
      packageName: verifierConfig.packageName,
    };
  }
  if (!purchaseStatus) {
    return {
      statusCode: 400,
      code: 'missing_purchase_status',
      message: 'Missing required field: purchaseStatus.',
      productId,
      packageName: verifierConfig.packageName,
    };
  }
  if (!platform) {
    return {
      statusCode: 400,
      code: 'missing_platform',
      message: 'Missing required field: platform.',
      productId,
      packageName: verifierConfig.packageName,
    };
  }
  if (platform !== 'android') {
    return {
      statusCode: 400,
      code: 'invalid_platform',
      message: 'Only Android purchases can be verified by this endpoint.',
      productId,
      packageName: verifierConfig.packageName,
    };
  }

  if (productId !== verifierConfig.expectedProductId) {
    return {
      statusCode: 403,
      code: 'product_mismatch',
      message: PURCHASE_NOT_CONFIRMED_MESSAGE,
      productId: verifierConfig.expectedProductId,
      packageName: verifierConfig.packageName,
    };
  }

  if (packageName !== verifierConfig.packageName) {
    return {
      statusCode: 403,
      code: 'package_mismatch',
      message: PURCHASE_NOT_CONFIRMED_MESSAGE,
      productId: verifierConfig.expectedProductId,
      packageName: verifierConfig.packageName,
    };
  }

  if (!VERIFIABLE_PURCHASE_STATUSES.has(purchaseStatus)) {
    return {
      handledResponse: buildHandledFailureResponse({
        code: 'subscription_not_active',
        message: SUBSCRIPTION_NOT_ACTIVE_MESSAGE,
        verifierConfig,
        payload: {
          packageName: verifierConfig.packageName,
        },
      }),
    };
  }

  return {
    payload: {
      productId: verifierConfig.expectedProductId,
      packageName: verifierConfig.packageName,
      purchaseToken,
      purchaseStatus,
      userId: userId || null,
      purchaseId: purchaseId || null,
    },
  };
}

function extractGoogleStatusCode(error) {
  return (
    Number(error?.response?.status) ||
    Number(error?.status) ||
    Number(error?.statusCode) ||
    0
  );
}

function extractGoogleErrorText(error) {
  return [
    trimString(error?.message),
    trimString(error?.response?.data?.error?.message),
    trimString(error?.response?.statusText),
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
}

function shouldFallbackToLegacySubscriptionGet(error) {
  const statusCode = extractGoogleStatusCode(error);
  const errorText = extractGoogleErrorText(error);
  if (![400, 404, 405, 501].includes(statusCode)) {
    return false;
  }
  return (
    errorText.includes('subscriptionsv2') ||
    errorText.includes('method not found') ||
    errorText.includes('unsupported') ||
    errorText.includes('not implemented') ||
    errorText.includes('unrecognized')
  );
}

function resolveRejectedGoogleReason(error) {
  const statusCode = extractGoogleStatusCode(error);
  const errorText = extractGoogleErrorText(error);

  if (
    errorText.includes('invalid purchase token') ||
    errorText.includes('token is invalid') ||
    errorText.includes('invalid token') ||
    errorText.includes('invalid value')
  ) {
    return 'invalid_purchase_token';
  }
  if (errorText.includes('purchase token was not found')) {
    return 'purchase_not_found';
  }
  if (errorText.includes('package name')) {
    return 'package_mismatch';
  }
  if (errorText.includes('product') || errorText.includes('subscription id')) {
    return 'product_mismatch';
  }
  if (statusCode === 404 || errorText.includes('not found')) {
    return 'purchase_not_found';
  }
  if (statusCode === 400) {
    return 'invalid_purchase_token';
  }
  return null;
}

function isGoogleConfigurationError(error) {
  const errorText = extractGoogleErrorText(error);
  return (
    errorText.includes('default credentials') ||
    errorText.includes('private key') ||
    errorText.includes('client email') ||
    errorText.includes('could not load the default credentials') ||
    errorText.includes('service account') ||
    errorText.includes('jwt')
  );
}

function mapGoogleApiError(error, payload, verifierConfig) {
  const statusCode = extractGoogleStatusCode(error);
  const rejectedReason = resolveRejectedGoogleReason(error);
  const safeMeta = {
    googleStatusCode: statusCode || null,
    reason: rejectedReason || null,
  };

  if (rejectedReason) {
    logVerifierEvent('google_play_verification_rejected', safeMeta, 'warn');
    return {
      statusCode: 200,
      body: buildHandledFailureResponse({
        code: rejectedReason,
        message:
          rejectedReason === 'subscription_not_active'
            ? SUBSCRIPTION_NOT_ACTIVE_MESSAGE
            : PURCHASE_NOT_CONFIRMED_MESSAGE,
        verifierConfig,
        payload,
      }),
    };
  }

  if (statusCode === 401 || statusCode === 403) {
    logVerifierEvent(
      'google_play_permission_denied',
      safeMeta,
      'warn',
    );
    return {
      statusCode: 503,
      body: buildErrorResponse({
        code: 'play_api_permission_denied',
        message: RECOVERABLE_FAILURE_MESSAGE,
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: true,
      }),
    };
  }

  if (statusCode === 429) {
    logVerifierEvent('google_play_rate_limited', safeMeta, 'warn');
    return {
      statusCode: 503,
      body: buildErrorResponse({
        code: 'backend_error',
        message: RECOVERABLE_FAILURE_MESSAGE,
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: true,
      }),
    };
  }

  if (isGoogleConfigurationError(error)) {
    logVerifierEvent('google_auth_unavailable', safeMeta, 'warn');
    return {
      statusCode: 503,
      body: buildErrorResponse({
        code: 'server_config_missing',
        message: RECOVERABLE_FAILURE_MESSAGE,
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: true,
      }),
    };
  }

  logVerifierEvent('google_play_backend_error', safeMeta, 'error');
  return {
    statusCode: 502,
    body: buildErrorResponse({
      code: 'backend_error',
      message: RECOVERABLE_FAILURE_MESSAGE,
      productId: verifierConfig.expectedProductId,
      packageName: verifierConfig.packageName,
      recoverable: true,
    }),
  };
}

function isSubscriptionAcknowledged(acknowledgementState) {
  return trimString(acknowledgementState) === ACKNOWLEDGED_STATE;
}

function normalizeLegacyAcknowledgementState(value) {
  if (typeof value === 'string') {
    const trimmed = trimString(value);
    if (trimmed) return trimmed;
  }
  if (Number(value) === 1) {
    return ACKNOWLEDGED_STATE;
  }
  return PENDING_ACKNOWLEDGEMENT_STATE;
}

async function acknowledgeSubscriptionIfNeeded({
  androidpublisher,
  payload,
  acknowledgementState,
}) {
  if (isSubscriptionAcknowledged(acknowledgementState)) {
    return;
  }

  try {
    logVerifierEvent('google_play_acknowledge_started', {
      productId: payload.productId,
      packageName: payload.packageName,
      tokenFingerprint: hashTokenFingerprint(payload.purchaseToken),
    });
    await androidpublisher.purchases.subscriptions.acknowledge({
      packageName: payload.packageName,
      subscriptionId: payload.productId,
      token: payload.purchaseToken,
      requestBody: {},
    });
    logVerifierEvent('google_play_acknowledge_succeeded', {
      productId: payload.productId,
      packageName: payload.packageName,
      tokenFingerprint: hashTokenFingerprint(payload.purchaseToken),
    });
  } catch (error) {
    logVerifierEvent(
      'google_play_acknowledge_failed',
      {
        productId: payload.productId,
        packageName: payload.packageName,
        tokenFingerprint: hashTokenFingerprint(payload.purchaseToken),
        googleStatusCode: extractGoogleStatusCode(error) || null,
      },
      'warn',
    );
  }
}

async function verifyWithGooglePlayV2(androidpublisher, payload, verifierConfig) {
  logVerifierEvent('google_play_v2_started', {
    productId: payload.productId,
    packageName: payload.packageName,
    purchaseStatus: payload.purchaseStatus,
    tokenFingerprint: hashTokenFingerprint(payload.purchaseToken),
  });

  const {data} = await androidpublisher.purchases.subscriptionsv2.get({
    packageName: payload.packageName,
    token: payload.purchaseToken,
  });

  const lineItems = normalizeLineItems(data);
  const matchedLineItem = lineItems.find(
    (item) => trimString(item.productId) === payload.productId,
  );
  const subscriptionState = trimString(data.subscriptionState);
  const acknowledgementState = trimString(data.acknowledgementState);
  const latestOrderId =
    trimString(matchedLineItem?.latestSuccessfulOrderId) ||
    trimString(data.latestOrderId) ||
    null;
  const expiryDate = resolveExpiryDate(lineItems);
  const expiryTimestamp = expiryDate ? Date.parse(expiryDate) : Number.NaN;
  const hasFutureExpiry =
    Number.isFinite(expiryTimestamp) && expiryTimestamp > Date.now();
  const isVerified = Boolean(matchedLineItem);
  const isActive =
    isVerified &&
    ACTIVE_SUBSCRIPTION_STATES.has(subscriptionState) &&
    hasFutureExpiry;

  if (!isVerified) {
    return buildHandledFailureResponse({
      code: 'product_mismatch',
      message: PURCHASE_NOT_CONFIRMED_MESSAGE,
      verifierConfig,
      payload,
    });
  }

  if (!isActive) {
    return buildHandledFailureResponse({
      code: 'subscription_not_active',
      message: SUBSCRIPTION_NOT_ACTIVE_MESSAGE,
      verifierConfig,
      payload,
    });
  }

  await acknowledgeSubscriptionIfNeeded({
    androidpublisher,
    payload,
    acknowledgementState,
  });

  return buildAcceptedResponse(
    buildEntitlement({
      verified: true,
      active: true,
      productId: verifierConfig.expectedProductId,
      packageName: verifierConfig.packageName,
      expiryDate,
      message: DEFAULT_SUCCESS_MESSAGE,
      subscriptionState: subscriptionState || null,
      acknowledgementState: acknowledgementState || null,
      latestOrderId,
      isTestPurchase: Boolean(data.testPurchase),
    }),
  );
}

async function verifyWithGooglePlayLegacy(
  androidpublisher,
  payload,
  verifierConfig,
) {
  logVerifierEvent('google_play_legacy_started', {
    productId: payload.productId,
    packageName: payload.packageName,
    purchaseStatus: payload.purchaseStatus,
    tokenFingerprint: hashTokenFingerprint(payload.purchaseToken),
  });

  const {data} = await androidpublisher.purchases.subscriptions.get({
    packageName: payload.packageName,
    subscriptionId: payload.productId,
    token: payload.purchaseToken,
  });

  const expiryDate = parseExpiryDate(data.expiryTimeMillis);
  const expiryTimestamp = expiryDate ? Date.parse(expiryDate) : Number.NaN;
  const hasFutureExpiry =
    Number.isFinite(expiryTimestamp) && expiryTimestamp > Date.now();
  const cancelReason =
    data.cancelReason == null ? null : `${data.cancelReason}`.trim();
  const hasCancellation = cancelReason != null && cancelReason !== '';
  const paymentState =
    data.paymentState == null ? null : Number.parseInt(`${data.paymentState}`, 10);
  const paymentStateAllowsAccess =
    paymentState == null || LEGACY_ACTIVE_PAYMENT_STATES.has(paymentState);
  const acknowledgementState = normalizeLegacyAcknowledgementState(
    data.acknowledgementState,
  );
  const isActive =
    hasFutureExpiry && !hasCancellation && paymentStateAllowsAccess;

  if (!isActive) {
    return buildHandledFailureResponse({
      code: 'subscription_not_active',
      message: SUBSCRIPTION_NOT_ACTIVE_MESSAGE,
      verifierConfig,
      payload,
    });
  }

  await acknowledgeSubscriptionIfNeeded({
    androidpublisher,
    payload,
    acknowledgementState,
  });

  return buildAcceptedResponse(
    buildEntitlement({
      verified: true,
      active: true,
      productId: verifierConfig.expectedProductId,
      packageName: verifierConfig.packageName,
      expiryDate,
      message: DEFAULT_SUCCESS_MESSAGE,
      acknowledgementState,
      latestOrderId: trimString(data.orderId) || null,
      isTestPurchase: Number(data.purchaseType) === 0,
    }),
  );
}

async function verifyWithGooglePlay(
  payload,
  verifierConfig,
  env = process.env,
  deps = {},
) {
  const androidpublisher =
    deps.androidpublisher || (await createAndroidPublisherClient(env));

  try {
    return await verifyWithGooglePlayV2(
      androidpublisher,
      payload,
      verifierConfig,
    );
  } catch (error) {
    if (!shouldFallbackToLegacySubscriptionGet(error)) {
      throw error;
    }

    logVerifierEvent('google_play_v2_fallback_to_legacy', {
      productId: payload.productId,
      packageName: payload.packageName,
      googleStatusCode: extractGoogleStatusCode(error) || null,
      tokenFingerprint: hashTokenFingerprint(payload.purchaseToken),
    });
  }

  return verifyWithGooglePlayLegacy(
    androidpublisher,
    payload,
    verifierConfig,
  );
}

async function handlePremiumVerification(
  req,
  res,
  env = process.env,
  deps = {},
) {
  const verifierConfig = resolveVerifierConfig(env);

  if (req.method !== 'POST') {
    return sendJson(
      res,
      405,
      buildErrorResponse({
        code: 'method_not_allowed',
        message: 'Method not allowed. Use POST.',
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: false,
      }),
      {Allow: 'POST'},
    );
  }

  if (
    !verifierConfig.packageNameConfigured ||
    !verifierConfig.productIdConfigured ||
    !verifierConfig.authConfigured
  ) {
    return sendJson(
      res,
      503,
      buildErrorResponse({
        code: 'server_config_missing',
        message: RECOVERABLE_FAILURE_MESSAGE,
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: true,
      }),
    );
  }

  const providedToken = getAuthorizationToken(req);
  if (!timingSafeEqualString(providedToken, verifierConfig.sharedSecret)) {
    return sendJson(
      res,
      401,
      buildErrorResponse({
        code: 'unauthorized',
        message: 'Unauthorized verifier request.',
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: false,
      }),
    );
  }

  const retryAfterSeconds = enforceRateLimit(req, verifierConfig);
  if (retryAfterSeconds != null) {
    return sendJson(
      res,
      429,
      buildErrorResponse({
        code: 'rate_limited',
        message: 'Too many verification attempts. Please try again later.',
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: true,
      }),
      {'Retry-After': `${retryAfterSeconds}`},
    );
  }

  let body;
  try {
    body = readRequestBody(req);
  } catch (_) {
    return sendJson(
      res,
      400,
      buildErrorResponse({
        code: 'invalid_json',
        message: 'Invalid JSON request body.',
        productId: verifierConfig.expectedProductId,
        packageName: verifierConfig.packageName,
        recoverable: false,
      }),
    );
  }

  const safeRequestMeta = buildSafeRequestMeta(body);
  logVerifierEvent('verify_premium_received', safeRequestMeta);

  const validation = validateRequestPayload(body, verifierConfig);
  if (validation.statusCode) {
    return sendJson(
      res,
      validation.statusCode,
      buildErrorResponse({
        code: validation.code,
        message: validation.message,
        productId: validation.productId || verifierConfig.expectedProductId,
        packageName: validation.packageName || verifierConfig.packageName,
        recoverable: false,
      }),
    );
  }

  if (validation.handledResponse) {
    return sendJson(res, 200, validation.handledResponse);
  }

  try {
    const responseBody = await verifyWithGooglePlay(
      validation.payload,
      verifierConfig,
      env,
      deps,
    );

    if (
      responseBody?.entitlement?.verified &&
      responseBody?.entitlement?.active &&
      validation.payload.userId
    ) {
      try {
        const referralStore =
          deps.referralStore || getDefaultReferralStore();
        await referralStore.recordVerifiedPurchase({
          userId: validation.payload.userId,
          payload: validation.payload,
          entitlement: responseBody.entitlement,
        });
      } catch (error) {
        logVerifierEvent(
          'referral_purchase_bookkeeping_failed',
          {
            userId: validation.payload.userId,
            reason: trimString(error?.code) || 'unknown',
          },
          'warn',
        );
      }
    }

    return sendJson(res, 200, responseBody);
  } catch (error) {
    const mapped = mapGoogleApiError(error, validation.payload, verifierConfig);
    return sendJson(res, mapped.statusCode, mapped.body);
  }
}

module.exports = {
  DEFAULT_PACKAGE_NAME,
  DEFAULT_PRODUCT_ID,
  buildAcceptedResponse,
  buildConfigCheckResponse,
  buildErrorResponse,
  handlePremiumVerification,
  resolveVerifierConfig,
  verifyWithGooglePlay,
  acknowledgeSubscriptionIfNeeded,
  isSubscriptionAcknowledged,
  isGoogleAuthAvailable,
};
