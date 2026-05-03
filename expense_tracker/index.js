const functions = require('@google-cloud/functions-framework');
const {google} = require('googleapis');

const PACKAGE_NAME =
  process.env.PACKAGE_NAME || 'com.intelliumdigital.sweldotrack';
const EXPECTED_PRODUCT_ID =
  process.env.EXPECTED_PRODUCT_ID || 'sweldotrack_premium_monthly';
const ANDROID_PUBLISHER_SCOPE =
  'https://www.googleapis.com/auth/androidpublisher';

const ACTIVE_SUBSCRIPTION_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  'SUBSCRIPTION_STATE_ON_HOLD',
]);

function sendJson(res, statusCode, body) {
  res.status(statusCode).set('Content-Type', 'application/json').send(body);
}

function buildFailureResponse(message, productId = null) {
  return {
    isVerified: false,
    isActive: false,
    productId,
    expiryDate: null,
    message,
  };
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
    .map((item) => item.expiryTime)
    .filter((value) => typeof value === 'string' && value.trim().length > 0)
    .map((value) => Date.parse(value))
    .filter((value) => Number.isFinite(value))
    .sort((a, b) => b - a);

  if (expiryTimestamps.length === 0) {
    return null;
  }

  return new Date(expiryTimestamps[0]).toISOString();
}

functions.http('verifySubscription', async (req, res) => {
  if (req.method !== 'POST') {
    return sendJson(
      res,
      405,
      buildFailureResponse('Method not allowed. Use POST.'),
    );
  }

  const productId = `${req.body?.productId || ''}`.trim();
  const purchaseToken = `${req.body?.purchaseToken || ''}`.trim();

  if (!productId) {
    return sendJson(
      res,
      400,
      buildFailureResponse('Missing required field: productId.'),
    );
  }

  if (!purchaseToken) {
    return sendJson(
      res,
      400,
      buildFailureResponse('Missing required field: purchaseToken.', productId),
    );
  }

  if (productId !== EXPECTED_PRODUCT_ID) {
    return sendJson(
      res,
      400,
      buildFailureResponse('Product ID does not match the expected premium product.', productId),
    );
  }

  try {
    const auth = new google.auth.GoogleAuth({
      scopes: [ANDROID_PUBLISHER_SCOPE],
    });

    const authClient = await auth.getClient();
    const androidpublisher = google.androidpublisher({
      version: 'v3',
      auth: authClient,
    });

    const {data} = await androidpublisher.purchases.subscriptionsv2.get({
      packageName: PACKAGE_NAME,
      token: purchaseToken,
    });

    const lineItems = normalizeLineItems(data);
    const matchedLineItem = lineItems.find(
      (item) => item.productId === EXPECTED_PRODUCT_ID,
    );
    const resolvedProductId = matchedLineItem?.productId || productId;
    const subscriptionState = `${data.subscriptionState || ''}`.trim();
    const isVerified = Boolean(matchedLineItem);
    const isActive =
      isVerified && ACTIVE_SUBSCRIPTION_STATES.has(subscriptionState);
    const expiryDate = resolveExpiryDate(lineItems);

    let message = 'Subscription verification completed.';
    if (!isVerified) {
      message = 'Subscription purchase token did not match the expected product.';
    } else if (!isActive) {
      message = subscriptionState
        ? `Subscription is not active: ${subscriptionState}.`
        : 'Subscription is not active.';
    }

    return sendJson(res, 200, {
      isVerified,
      isActive,
      productId: resolvedProductId,
      expiryDate,
      message,
    });
  } catch (error) {
    const message =
      error instanceof Error && error.message
        ? `Subscription verification failed: ${error.message}`
        : 'Subscription verification failed.';

    return sendJson(res, 500, buildFailureResponse(message, productId));
  }
});
