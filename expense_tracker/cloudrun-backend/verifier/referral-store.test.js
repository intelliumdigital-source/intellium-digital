const fs = require('fs/promises');
const os = require('os');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ReferralStoreError,
  applyReferralCode,
  getReferralProfile,
  recordVerifiedPurchase,
  registerUser,
} = require('./referral-store');

function buildPayload(overrides = {}) {
  return {
    productId: 'sweldotrack_premium_monthly',
    packageName: 'com.intelliumdigital.sweldotrack',
    purchaseToken: 'purchase-token',
    purchaseStatus: 'purchased',
    purchaseId: 'purchase-id',
    ...overrides,
  };
}

function buildEntitlement(overrides = {}) {
  return {
    verified: true,
    active: true,
    latestOrderId: 'order-1',
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    expiryDate: '2030-06-05T00:00:00.000Z',
    ...overrides,
  };
}

async function withFileStoreTest(run) {
  const previousMode = process.env.REFERRAL_STORE_MODE;
  const previousFile = process.env.REFERRAL_STORE_FILE;
  const storeFile = path.join(
    os.tmpdir(),
    `sweldotrack-referral-test-${Date.now()}-${Math.random()
      .toString(16)
      .slice(2)}.json`,
  );

  process.env.REFERRAL_STORE_MODE = 'file';
  process.env.REFERRAL_STORE_FILE = storeFile;

  try {
    await fs.rm(storeFile, {force: true});
    await run();
  } finally {
    await fs.rm(storeFile, {force: true});
    if (previousMode == null) {
      delete process.env.REFERRAL_STORE_MODE;
    } else {
      process.env.REFERRAL_STORE_MODE = previousMode;
    }
    if (previousFile == null) {
      delete process.env.REFERRAL_STORE_FILE;
    } else {
      process.env.REFERRAL_STORE_FILE = previousFile;
    }
  }
}

test('register new user', async () => {
  await withFileStoreTest(async () => {
    const profile = await registerUser({
      userId: 'user-1',
      displayName: 'Alice',
    });

    assert.equal(profile.ok, true);
    assert.equal(profile.user.userId, 'user-1');
    assert.equal(profile.user.displayName, 'Alice');
    assert.equal(profile.user.referralCode.length, 8);
    assert.equal(profile.stats.totalReferrals, 0);
  });
});

test('register existing user is idempotent', async () => {
  await withFileStoreTest(async () => {
    const first = await registerUser({
      userId: 'user-1',
      displayName: 'Alice',
    });
    const second = await registerUser({
      userId: 'user-1',
      displayName: '',
    });

    assert.equal(second.user.userId, 'user-1');
    assert.equal(second.user.referralCode, first.user.referralCode);
    assert.equal(second.user.displayName, 'Alice');
  });
});

test('dashboard for existing user', async () => {
  await withFileStoreTest(async () => {
    await registerUser({userId: 'user-1'});
    const profile = await getReferralProfile({userId: 'user-1'});

    assert.equal(profile.ok, true);
    assert.equal(profile.user.userId, 'user-1');
    assert.equal(profile.user.referralCode.length, 8);
  });
});

test('dashboard for missing user is safe', async () => {
  await withFileStoreTest(async () => {
    const profile = await getReferralProfile({userId: 'new-user'});

    assert.equal(profile.ok, true);
    assert.equal(profile.user.userId, 'new-user');
    assert.equal(profile.user.referralCode.length, 8);
  });
});

test('apply valid referral code', async () => {
  await withFileStoreTest(async () => {
    const referrer = await registerUser({userId: 'referrer'});
    await registerUser({userId: 'buyer'});

    const profile = await applyReferralCode({
      userId: 'buyer',
      referralCode: referrer.user.referralCode,
    });

    assert.equal(profile.user.referredByUserId, 'referrer');
    assert.equal(profile.user.referredByCode, referrer.user.referralCode);
  });
});

test('block self-referral', async () => {
  await withFileStoreTest(async () => {
    const user = await registerUser({userId: 'self-user'});

    await assert.rejects(
      () =>
        applyReferralCode({
          userId: 'self-user',
          referralCode: user.user.referralCode,
        }),
      (error) =>
        error instanceof ReferralStoreError &&
        error.code === 'self_referral_blocked',
    );
  });
});

test('block duplicate referral code usage', async () => {
  await withFileStoreTest(async () => {
    const referrer = await registerUser({userId: 'referrer'});
    await registerUser({userId: 'buyer'});

    await applyReferralCode({
      userId: 'buyer',
      referralCode: referrer.user.referralCode,
    });

    await assert.rejects(
      () =>
        applyReferralCode({
          userId: 'buyer',
          referralCode: referrer.user.referralCode,
        }),
      (error) =>
        error instanceof ReferralStoreError &&
        error.code === 'referral_code_already_applied',
    );
  });
});

test('verified premium purchase creates pending referral reward', async () => {
  await withFileStoreTest(async () => {
    const referrer = await registerUser({userId: 'referrer'});
    await registerUser({userId: 'buyer'});
    await applyReferralCode({
      userId: 'buyer',
      referralCode: referrer.user.referralCode,
    });

    const outcome = await recordVerifiedPurchase({
      userId: 'buyer',
      payload: buildPayload(),
      entitlement: buildEntitlement(),
    });
    const dashboard = await getReferralProfile({userId: 'referrer'});

    assert.equal(outcome.rewardCreated, true);
    assert.equal(outcome.rewardStatus, 'pending');
    assert.equal(dashboard.stats.pendingRewards, 1);
    assert.equal(dashboard.stats.pendingEarningsPhp, 20);
    assert.equal(dashboard.stats.paidEarningsPhp, 0);
    assert.equal(dashboard.stats.totalEarningsPhp, 20);
    assert.equal(dashboard.rewards[0].amountPhp, 20);
    assert.equal(dashboard.rewards[0].status, 'pending');
    assert.equal(dashboard.rewards.length, 1);
  });
});

test('duplicate verified purchase does not duplicate reward', async () => {
  await withFileStoreTest(async () => {
    const referrer = await registerUser({userId: 'referrer'});
    await registerUser({userId: 'buyer'});
    await applyReferralCode({
      userId: 'buyer',
      referralCode: referrer.user.referralCode,
    });

    await recordVerifiedPurchase({
      userId: 'buyer',
      payload: buildPayload(),
      entitlement: buildEntitlement(),
    });
    const outcome = await recordVerifiedPurchase({
      userId: 'buyer',
      payload: buildPayload(),
      entitlement: buildEntitlement(),
    });
    const dashboard = await getReferralProfile({userId: 'referrer'});

    assert.equal(outcome.rewardCreated, false);
    assert.equal(outcome.rewardStatus, 'pending');
    assert.equal(dashboard.stats.pendingRewards, 1);
    assert.equal(dashboard.stats.pendingEarningsPhp, 20);
    assert.equal(dashboard.stats.paidEarningsPhp, 0);
    assert.equal(dashboard.stats.totalEarningsPhp, 20);
    assert.equal(dashboard.rewards.length, 1);
  });
});

test('premium user with no referrer does not fail bookkeeping', async () => {
  await withFileStoreTest(async () => {
    await registerUser({userId: 'solo-user'});

    const outcome = await recordVerifiedPurchase({
      userId: 'solo-user',
      payload: buildPayload(),
      entitlement: buildEntitlement(),
    });
    const dashboard = await getReferralProfile({userId: 'solo-user'});

    assert.equal(outcome.rewardCreated, false);
    assert.equal(outcome.rewardStatus, null);
    assert.equal(dashboard.stats.pendingRewards, 0);
  });
});
