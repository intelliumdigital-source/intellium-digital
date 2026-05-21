const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildConfigCheckResponse,
  handlePremiumVerification,
} = require('./premium-verifier');

const baseEnv = {
  SWELDOTRACK_PREMIUM_VERIFY_AUTH: 'test-secret',
  VERIFY_AUTH: 'test-secret',
  API_KEY: 'test-secret',
  VERIFY_API_KEY: 'test-secret',
  PACKAGE_NAME: 'com.intelliumdigital.sweldotrack',
  EXPECTED_PRODUCT_ID: 'sweldotrack_premium_monthly',
  PREMIUM_VERIFY_RATE_LIMIT_MAX: '0',
  PREMIUM_VERIFY_RATE_LIMIT_WINDOW_MS: '0',
};

test('active unacknowledged subscription triggers acknowledge', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, true);
  assert.equal(response.body.active, true);
  assert.equal(response.body.isPremium, true);
  assert.equal(response.body.productId, 'sweldotrack_premium_monthly');
  assert.equal(
    response.body.entitlement.acknowledgementState,
    'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
  );
  assert.equal(response.body.message, 'Premium active');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 1);
});

test('verified premium purchase records referral bookkeeping when userId is present', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });
  const referralStore = {
    calls: 0,
    lastArgs: null,
    async recordVerifiedPurchase(args) {
      this.calls += 1;
      this.lastArgs = args;
    },
  };

  const response = await invokeVerification(
    buildValidBody({userId: 'buyer-123'}),
    publisher,
    {referralStore},
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, true);
  assert.equal(response.body.active, true);
  assert.equal(response.body.orderId, 'order-1');
  assert.equal(referralStore.calls, 1);
  assert.equal(referralStore.lastArgs.userId, 'buyer-123');
  assert.equal(
    referralStore.lastArgs.payload.purchaseId,
    'purchase-id',
  );
});

test('missing userId returns 400 before Google Play verification', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody({userId: ''}),
    publisher,
  );

  assert.equal(response.statusCode, 400);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.error.code, 'missing_user_id');
  assert.equal(publisher.calls.get, 0);
});

test('rejected receipt does not record referral bookkeeping', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 404}},
  });
  const referralStore = {
    calls: 0,
    async recordVerifiedPurchase() {
      this.calls += 1;
    },
  };

  const response = await invokeVerification(
    buildValidBody({userId: 'buyer-123'}),
    publisher,
    {referralStore},
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(referralStore.calls, 0);
});

test('active already acknowledged subscription does not call acknowledge', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, true);
  assert.equal(response.body.active, true);
  assert.equal(response.body.isPremium, true);
  assert.equal(response.body.message, 'Premium active');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('invalid token does not acknowledge', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 404}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.reason, 'purchase_not_found');
  assert.equal(response.body.message, 'Purchase could not be confirmed.');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('fake token Invalid Value returns rejected receipt', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {message: 'Subscription verification failed: Invalid Value'},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.reason, 'invalid_purchase_token');
  assert.equal(response.body.productId, 'sweldotrack_premium_monthly');
  assert.equal(response.body.expiryDate, null);
  assert.equal(response.body.message, 'Purchase could not be confirmed.');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('400 Google error returns rejected receipt', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 400}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.reason, 'invalid_purchase_token');
  assert.equal(response.body.productId, 'sweldotrack_premium_monthly');
  assert.equal(response.body.expiryDate, null);
  assert.equal(response.body.message, 'Purchase could not be confirmed.');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('404 Google error returns rejected receipt', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 404}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.reason, 'purchase_not_found');
  assert.equal(response.body.productId, 'sweldotrack_premium_monthly');
  assert.equal(response.body.expiryDate, null);
  assert.equal(response.body.message, 'Purchase could not be confirmed.');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('401 Google error returns backend access/config error', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 401}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 503);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(
    response.body.error.code,
    'play_api_permission_denied',
  );
  assert.equal(
    response.body.message,
    'Premium verification could not be completed right now.',
  );
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('403 Google error returns backend access/config error', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 403}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 503);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(
    response.body.error.code,
    'play_api_permission_denied',
  );
  assert.equal(
    response.body.message,
    'Premium verification could not be completed right now.',
  );
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('expired subscription does not acknowledge', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      expiryTime: '2020-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.reason, 'subscription_not_active');
  assert.equal(response.body.message, 'Subscription is not active.');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('wrong product does not acknowledge', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody({
      productId: 'wrong_product_id',
    }),
    publisher,
  );

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.reason, 'product_mismatch');
  assert.equal(response.body.message, 'Purchase could not be confirmed.');
  assert.equal(publisher.calls.get, 0);
  assert.equal(publisher.calls.acknowledge, 0);
});

test('acknowledgement failure returns safe failure and keeps premium locked', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
    acknowledgeError: {response: {status: 403}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 503);
  assert.equal(response.body.ok, false);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.isPremium, false);
  assert.equal(
    response.body.error.code,
    'purchase_acknowledgement_failed',
  );
  assert.equal(
    response.body.message,
    'Purchase acknowledgement failed. Please try again.',
  );
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 1);
});

test('already acknowledged error is treated as success', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
    acknowledgeError: {
      response: {
        status: 409,
        data: {
          error: {
            message: 'Subscription purchase is already acknowledged.',
          },
        },
      },
    },
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.verified, true);
  assert.equal(response.body.active, true);
  assert.equal(response.body.isPremium, true);
  assert.equal(
    response.body.entitlement.acknowledgementState,
    'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
  );
  assert.equal(response.body.message, 'Premium active');
  assert.equal(publisher.calls.get, 1);
  assert.equal(publisher.calls.acknowledge, 1);
});

test('verify endpoint accepts x-api-key auth', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
    {},
    {
      'x-api-key': 'test-secret',
    },
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.isPremium, true);
});

test('verify endpoint accepts x-verify-auth auth', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
    {},
    {
      'x-verify-auth': 'test-secret',
    },
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.isPremium, true);
});

test('verify endpoint with wrong auth is rejected before Google Play verification', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
    {},
    {
      authorization: 'Bearer old-secret',
    },
  );

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.isPremium, false);
  assert.equal(response.body.error.code, 'invalid_auth');
  assert.equal(response.body.message, 'Invalid verifier authorization.');
  assert.equal(publisher.calls.get, 0);
});

test('verify endpoint with wrong auth and invalid token is rejected before Google Play verification', async () => {
  const publisher = createFakeAndroidPublisher({
    getError: {response: {status: 404}},
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
    {},
    {
      authorization: 'Bearer old-secret',
    },
  );

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.isPremium, false);
  assert.equal(response.body.error.code, 'invalid_auth');
  assert.equal(response.body.message, 'Invalid verifier authorization.');
  assert.equal(publisher.calls.get, 0);
});

test('verify endpoint with wrong auth and missing purchase token is rejected before payload validation reaches Google Play verification', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody({purchaseToken: ''}),
    publisher,
    {},
    {
      authorization: 'Bearer old-secret',
    },
  );

  assert.equal(response.statusCode, 400);
  assert.equal(response.body.error.code, 'missing_purchase_token');
  assert.equal(publisher.calls.get, 0);
});

test('verify endpoint with missing auth returns 401', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody(),
    publisher,
    {},
    {
      authorization: '',
      'x-api-key': '',
      'x-verify-auth': '',
    },
  );

  assert.equal(response.statusCode, 401);
  assert.equal(response.body.verified, false);
  assert.equal(response.body.active, false);
  assert.equal(response.body.isPremium, false);
  assert.equal(response.body.error.code, 'missing_auth');
  assert.equal(response.body.message, 'Missing verifier authorization.');
  assert.equal(publisher.calls.get, 0);
});

test('config-check reports missing explicit verifier env safely', async () => {
  const response = await buildConfigCheckResponse({
    SWELDOTRACK_PREMIUM_VERIFY_AUTH: 'test-secret',
    PREMIUM_VERIFY_RATE_LIMIT_MAX: '0',
    PREMIUM_VERIFY_RATE_LIMIT_WINDOW_MS: '0',
  }, {
    googleAuthAvailable: true,
  });

  assert.equal(response.ok, false);
  assert.equal(response.packageNameConfigured, false);
  assert.equal(response.productIdConfigured, false);
  assert.equal(response.authConfigured, true);
  assert.equal(response.googleAuthAvailable, true);
});

test('missing package name returns 400', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody({packageName: ''}),
    publisher,
  );

  assert.equal(response.statusCode, 400);
  assert.equal(response.body.error.code, 'missing_package_name');
});

test('package mismatch returns 403', async () => {
  const publisher = createFakeAndroidPublisher({
    getResult: buildSubscriptionResult({
      acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
      expiryTime: '2030-06-05T00:00:00.000Z',
    }),
  });

  const response = await invokeVerification(
    buildValidBody({packageName: 'com.example.other'}),
    publisher,
  );

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.error.code, 'package_mismatch');
});

function buildValidBody(overrides = {}) {
  return {
    productId: 'sweldotrack_premium_monthly',
    packageName: 'com.intelliumdigital.sweldotrack',
    purchaseToken: 'purchase-token',
    localReceipt: 'local-receipt',
    verificationSource: 'google_play',
    purchaseStatus: 'purchased',
    purchaseId: 'purchase-id',
    transactionDateMillis: 1718409600000,
    platform: 'android',
    ...overrides,
  };
}

function buildSubscriptionResult({
  acknowledgementState,
  expiryTime,
}) {
  return {
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    acknowledgementState,
    lineItems: [
      {
        productId: 'sweldotrack_premium_monthly',
        expiryTime,
        latestSuccessfulOrderId: 'order-1',
      },
    ],
  };
}

function createFakeAndroidPublisher({
  getResult,
  getError,
  acknowledgeError,
}) {
  const calls = {
    get: 0,
    acknowledge: 0,
  };

  return {
    calls,
    purchases: {
      subscriptionsv2: {
        get: async () => {
          calls.get += 1;
          if (getError) {
            throw getError;
          }
          return {data: getResult};
        },
      },
      subscriptions: {
        acknowledge: async () => {
          calls.acknowledge += 1;
          if (acknowledgeError) {
            throw acknowledgeError;
          }
          return {};
        },
      },
    },
  };
}

async function invokeVerification(
  body,
  androidpublisher,
  extraDeps = {},
  headers = {},
) {
  const req = {
    method: 'POST',
    headers: {
      authorization: 'Bearer test-secret',
      ...headers,
    },
    body,
    socket: {
      remoteAddress: '127.0.0.1',
    },
  };
  const res = createFakeResponse();
  const deps = {androidpublisher, ...extraDeps};

  await handlePremiumVerification(req, res, baseEnv, deps);

  return res;
}

function createFakeResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    set(headers) {
      this.headers = {
        ...this.headers,
        ...headers,
      };
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
  };
}
