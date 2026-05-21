const crypto = require('crypto');
const admin = require('firebase-admin');

const USERS_COLLECTION = 'users';
const REFERRAL_CODES_COLLECTION = 'referral_codes';
const REFERRALS_COLLECTION = 'referrals';
const PURCHASES_COLLECTION = 'purchases';
const REFERRAL_REWARDS_COLLECTION = 'referral_rewards';

const REFERRAL_CODE_LENGTH = 8;
const REFERRAL_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const REFERRAL_CODE_PATTERN = /^[A-Z0-9]{6,12}$/;
const MAX_USER_ID_LENGTH = 128;
const MAX_DISPLAY_NAME_LENGTH = 120;
const DEFAULT_PREMIUM_PRICE_PHP = 120;
const DEFAULT_REFERRAL_REWARD_PERCENT = 20;
const PURCHASE_TOKEN_HASH_ALGORITHM = 'sha256';

class ReferralStoreError extends Error {
  constructor(statusCode, code, message) {
    super(message);
    this.name = 'ReferralStoreError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

function trimString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function parsePositiveNumber(value, fallback) {
  const parsed = Number.parseFloat(`${value ?? ''}`.trim());
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function roundCurrency(value) {
  return Math.round(value * 100) / 100;
}

function resolveRewardConfig(env = process.env) {
  const premiumPricePhp = parsePositiveNumber(
    env.PREMIUM_PRICE_PHP,
    DEFAULT_PREMIUM_PRICE_PHP,
  );
  const configuredPercent = parsePositiveNumber(
    env.REFERRAL_REWARD_PERCENT,
    DEFAULT_REFERRAL_REWARD_PERCENT,
  );
  const rewardPercent =
    configuredPercent > 1 ? configuredPercent : configuredPercent * 100;

  return {
    premiumPricePhp,
    rewardPercent,
    rewardAmountPhp: roundCurrency(premiumPricePhp * (rewardPercent / 100)),
  };
}

function nowTimestamp() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function getFirestore() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }

  return admin.firestore();
}

function normalizeUserId(value) {
  const userId = trimString(value);
  if (!userId) {
    throw new ReferralStoreError(
      400,
      'missing_user_id',
      'Missing required field: userId.',
    );
  }
  if (userId.length > MAX_USER_ID_LENGTH) {
    throw new ReferralStoreError(
      400,
      'invalid_user_id',
      'Invalid userId length.',
    );
  }
  return userId;
}

function normalizeDisplayName(value) {
  const displayName = trimString(value);
  if (!displayName) return null;
  if (displayName.length > MAX_DISPLAY_NAME_LENGTH) {
    throw new ReferralStoreError(
      400,
      'invalid_display_name',
      'Invalid displayName length.',
    );
  }
  return displayName;
}

function normalizeReferralCode(value) {
  const code = trimString(value).toUpperCase();
  if (!code) {
    throw new ReferralStoreError(
      400,
      'missing_referral_code',
      'Missing required field: referralCode.',
    );
  }
  if (!REFERRAL_CODE_PATTERN.test(code)) {
    throw new ReferralStoreError(
      400,
      'invalid_referral_code',
      'Invalid referralCode format.',
    );
  }
  return code;
}

function readReferredByUserId(userData) {
  return (
    trimString(userData?.referredByUserId) ||
    trimString(userData?.referrerUserId) ||
    ''
  );
}

function readReferredByCode(userData) {
  return (
    trimString(userData?.referredByCode).toUpperCase() ||
    trimString(userData?.referrerCode).toUpperCase() ||
    ''
  );
}

function hashPurchaseToken(purchaseToken) {
  return crypto
    .createHash(PURCHASE_TOKEN_HASH_ALGORITHM)
    .update(trimString(purchaseToken), 'utf8')
    .digest('hex');
}

function randomReferralCode() {
  const bytes = crypto.randomBytes(REFERRAL_CODE_LENGTH);
  let code = '';

  for (let index = 0; index < REFERRAL_CODE_LENGTH; index += 1) {
    code +=
      REFERRAL_CODE_ALPHABET[
        bytes[index] % REFERRAL_CODE_ALPHABET.length
      ];
  }

  return code;
}

function docTimestampToIso(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  return null;
}

async function reserveUniqueReferralCode(transaction, db) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const code = randomReferralCode();
    const codeRef = db.collection(REFERRAL_CODES_COLLECTION).doc(code);
    const codeSnap = await transaction.get(codeRef);
    if (!codeSnap.exists) {
      return {code, codeRef};
    }
  }

  throw new ReferralStoreError(
    500,
    'referral_code_generation_failed',
    'Could not generate a unique referral code.',
  );
}

async function ensureUserHasReferralCode({
  transaction,
  db,
  userRef,
  userData,
  userId,
  displayName = null,
}) {
  const existingCode = trimString(userData?.referralCode).toUpperCase();
  const referredByUserId = readReferredByUserId(userData) || null;
  const referredByCode = readReferredByCode(userData) || null;
  if (existingCode) {
    const patch = {
      userId,
      referredByUserId,
      referredByCode,
      referrerUserId: referredByUserId,
      referrerCode: referredByCode,
      updatedAt: nowTimestamp(),
    };
    if (displayName) {
      patch.displayName = displayName;
    } else if (!trimString(userData?.displayName)) {
      patch.displayName = null;
    }
    if (!userData?.createdAt) {
      patch.createdAt = nowTimestamp();
    }
    transaction.set(userRef, patch, {merge: true});
    return existingCode;
  }

  const {code, codeRef} = await reserveUniqueReferralCode(transaction, db);
  const timestamp = nowTimestamp();

  transaction.create(codeRef, {
    code,
    userId,
    createdAt: timestamp,
    updatedAt: timestamp,
  });

  transaction.set(
    userRef,
    {
      userId,
      displayName:
        displayName ?? (trimString(userData?.displayName) || null),
      referralCode: code,
      referredByUserId,
      referredByCode,
      referrerUserId: referredByUserId,
      referrerCode: referredByCode,
      createdAt: userData?.createdAt || timestamp,
      updatedAt: timestamp,
    },
    {merge: true},
  );

  return code;
}

async function registerUser({userId, displayName = null}) {
  const db = getFirestore();
  const normalizedUserId = normalizeUserId(userId);
  const normalizedDisplayName = normalizeDisplayName(displayName);
  const userRef = db.collection(USERS_COLLECTION).doc(normalizedUserId);

  await db.runTransaction(async (transaction) => {
    const userSnap = await transaction.get(userRef);
    const userData = userSnap.exists ? userSnap.data() : null;

    await ensureUserHasReferralCode({
      transaction,
      db,
      userRef,
      userData,
      userId: normalizedUserId,
      displayName: normalizedDisplayName,
    });
  });

  return getReferralProfile({userId: normalizedUserId});
}

async function applyReferralCode({userId, referralCode}) {
  const db = getFirestore();
  const normalizedUserId = normalizeUserId(userId);
  const normalizedReferralCode = normalizeReferralCode(referralCode);
  const userRef = db.collection(USERS_COLLECTION).doc(normalizedUserId);
  const codeRef = db
    .collection(REFERRAL_CODES_COLLECTION)
    .doc(normalizedReferralCode);
  const referralRef = db.collection(REFERRALS_COLLECTION).doc(normalizedUserId);

  await db.runTransaction(async (transaction) => {
    const [userSnap, codeSnap, referralSnap] = await transaction.getAll(
      userRef,
      codeRef,
      referralRef,
    );

    if (!codeSnap.exists) {
      throw new ReferralStoreError(
        404,
        'referral_code_not_found',
        'Referral code was not found.',
      );
    }

    const referrerUserId = normalizeUserId(codeSnap.data().userId);
    if (referrerUserId === normalizedUserId) {
      throw new ReferralStoreError(
        409,
        'self_referral_blocked',
        'You cannot apply your own referral code.',
      );
    }

    const userData = userSnap.exists ? userSnap.data() : null;
    const currentReferredByUserId = readReferredByUserId(userData);
    if (
      currentReferredByUserId &&
      currentReferredByUserId !== referrerUserId
    ) {
      throw new ReferralStoreError(
        409,
        'referrer_already_assigned',
        'This user already has a referrer.',
      );
    }

    await ensureUserHasReferralCode({
      transaction,
      db,
      userRef,
      userData,
      userId: normalizedUserId,
    });

    const timestamp = nowTimestamp();
    transaction.set(
      userRef,
      {
        userId: normalizedUserId,
        referredByUserId: referrerUserId,
        referredByCode: normalizedReferralCode,
        referrerUserId,
        referrerCode: normalizedReferralCode,
        appliedReferralAt: userData?.appliedReferralAt || timestamp,
        updatedAt: timestamp,
      },
      {merge: true},
    );

    const referralData = referralSnap.exists ? referralSnap.data() : null;
    transaction.set(
      referralRef,
      {
        referredUserId: normalizedUserId,
        referrerUserId,
        referralCode: normalizedReferralCode,
        status: 'applied',
        createdAt: referralData?.createdAt || timestamp,
        appliedAt: referralData?.appliedAt || timestamp,
        updatedAt: timestamp,
      },
      {merge: true},
    );
  });

  return getReferralProfile({userId: normalizedUserId});
}

async function recordVerifiedPurchase({userId, payload, entitlement}) {
  const db = getFirestore();
  const rewardConfig = resolveRewardConfig();
  const normalizedUserId = normalizeUserId(userId);
  const purchaseTokenHash = hashPurchaseToken(payload.purchaseToken);
  const userRef = db.collection(USERS_COLLECTION).doc(normalizedUserId);
  const purchaseRef = db.collection(PURCHASES_COLLECTION).doc(purchaseTokenHash);
  const rewardRef = db
    .collection(REFERRAL_REWARDS_COLLECTION)
    .doc(purchaseTokenHash);
  const referralRef = db.collection(REFERRALS_COLLECTION).doc(normalizedUserId);

  const outcome = {
    purchaseTokenHash,
    rewardCreated: false,
    rewardStatus: null,
  };

  await db.runTransaction(async (transaction) => {
    const [userSnap, purchaseSnap, rewardSnap, referralSnap] =
      await transaction.getAll(userRef, purchaseRef, rewardRef, referralRef);

    const userData = userSnap.exists ? userSnap.data() : null;
    const referralCode = await ensureUserHasReferralCode({
      transaction,
      db,
      userRef,
      userData,
      userId: normalizedUserId,
    });

    const timestamp = nowTimestamp();
    const purchasePatch = {
      purchaseTokenHash,
      userId: normalizedUserId,
      referralCode,
      productId: trimString(payload.productId) || null,
      packageName: trimString(payload.packageName) || null,
      purchaseId: trimString(payload.purchaseId) || null,
      purchaseStatus: trimString(payload.purchaseStatus) || null,
      latestOrderId: trimString(entitlement?.latestOrderId) || null,
      expiryDate: trimString(entitlement?.expiryDate) || null,
      subscriptionState: trimString(entitlement?.subscriptionState) || null,
      acknowledgementState:
        trimString(entitlement?.acknowledgementState) || null,
      verified: Boolean(entitlement?.verified),
      active: Boolean(entitlement?.active),
      isTestPurchase: Boolean(entitlement?.isTestPurchase),
      premiumPricePhp: rewardConfig.premiumPricePhp,
      rewardPercent: rewardConfig.rewardPercent,
      createdAt: purchaseSnap.exists
        ? purchaseSnap.data().createdAt || timestamp
        : timestamp,
      updatedAt: timestamp,
    };

    transaction.set(purchaseRef, purchasePatch, {merge: true});

    const referrerUserId = readReferredByUserId(userData);
    const referrerCode = readReferredByCode(userData);
    if (!referrerUserId || !referrerCode || referrerUserId === normalizedUserId) {
      outcome.rewardStatus = rewardSnap.exists
        ? trimString(rewardSnap.data().status) || null
        : null;
      return;
    }

    const referrerCodeRef = db
      .collection(REFERRAL_CODES_COLLECTION)
      .doc(referrerCode);
    const referrerCodeSnap = await transaction.get(referrerCodeRef);
    if (
      !referrerCodeSnap.exists ||
      trimString(referrerCodeSnap.data().userId) !== referrerUserId
    ) {
      outcome.rewardStatus = rewardSnap.exists
        ? trimString(rewardSnap.data().status) || null
        : null;
      return;
    }

    if (rewardSnap.exists) {
      const existingRewardStatus =
        trimString(rewardSnap.data().status) || null;
      transaction.set(
        purchaseRef,
        {
          rewardStatus: existingRewardStatus,
          rewardAmountPhp:
            Number(rewardSnap.data().amountPhp) || rewardConfig.rewardAmountPhp,
          rewardUpdatedAt: timestamp,
        },
        {merge: true},
      );
      outcome.rewardStatus = existingRewardStatus;
      return;
    }

    transaction.create(rewardRef, {
      rewardId: purchaseTokenHash,
      purchaseTokenHash,
      purchaseId: trimString(payload.purchaseId) || null,
      latestOrderId: trimString(entitlement?.latestOrderId) || null,
      referredUserId: normalizedUserId,
      referrerUserId,
      referralCode: referrerCode,
      amountPhp: rewardConfig.rewardAmountPhp,
      premiumPricePhp: rewardConfig.premiumPricePhp,
      rewardPercent: rewardConfig.rewardPercent,
      status: 'pending',
      createdAt: timestamp,
      updatedAt: timestamp,
      paidAt: null,
    });

    transaction.set(
      referralRef,
      {
        referredUserId: normalizedUserId,
        referrerUserId,
        referralCode: referrerCode,
        status: 'reward_pending',
        convertedAt: timestamp,
        updatedAt: timestamp,
      },
      {merge: true},
    );

    transaction.set(
      purchaseRef,
        {
          rewardStatus: 'pending',
          rewardAmountPhp: rewardConfig.rewardAmountPhp,
          rewardUpdatedAt: timestamp,
        },
        {merge: true},
    );

    outcome.rewardCreated = true;
    outcome.rewardStatus = 'pending';
  });

  return outcome;
}

async function markReferralRewardPaid({rewardId, paidBy = 'admin'}) {
  const db = getFirestore();
  const normalizedRewardId = trimString(rewardId);
  if (!normalizedRewardId) {
    throw new ReferralStoreError(
      400,
      'missing_reward_id',
      'Missing required field: rewardId.',
    );
  }

  const rewardRef = db
    .collection(REFERRAL_REWARDS_COLLECTION)
    .doc(normalizedRewardId);

  await db.runTransaction(async (transaction) => {
    const rewardSnap = await transaction.get(rewardRef);
    if (!rewardSnap.exists) {
      throw new ReferralStoreError(
        404,
        'reward_not_found',
        'Referral reward was not found.',
      );
    }

    const rewardData = rewardSnap.data();
    if (trimString(rewardData.status) === 'paid') {
      transaction.set(
        rewardRef,
        {
          updatedAt: nowTimestamp(),
        },
        {merge: true},
      );
      return;
    }

    transaction.set(
      rewardRef,
      {
        status: 'paid',
        paidAt: nowTimestamp(),
        paidBy: trimString(paidBy) || 'admin',
        updatedAt: nowTimestamp(),
      },
      {merge: true},
    );
  });

  return getRewardById({rewardId: normalizedRewardId});
}

async function getRewardById({rewardId}) {
  const db = getFirestore();
  const rewardRef = db
    .collection(REFERRAL_REWARDS_COLLECTION)
    .doc(trimString(rewardId));
  const rewardSnap = await rewardRef.get();
  if (!rewardSnap.exists) {
    throw new ReferralStoreError(
      404,
      'reward_not_found',
      'Referral reward was not found.',
    );
  }
  return serializeReward(rewardSnap);
}

function serializeReward(rewardSnap) {
  const rewardData = rewardSnap.data() || {};
  const rewardConfig = resolveRewardConfig();
  return {
    rewardId: rewardSnap.id,
    purchaseTokenHash: trimString(rewardData.purchaseTokenHash) || rewardSnap.id,
    purchaseId: trimString(rewardData.purchaseId) || null,
    latestOrderId: trimString(rewardData.latestOrderId) || null,
    referredUserId: trimString(rewardData.referredUserId) || null,
    referrerUserId: trimString(rewardData.referrerUserId) || null,
    referralCode: trimString(rewardData.referralCode).toUpperCase() || null,
    amountPhp: Number(rewardData.amountPhp) || rewardConfig.rewardAmountPhp,
    premiumPricePhp:
      Number(rewardData.premiumPricePhp) || rewardConfig.premiumPricePhp,
    rewardPercent:
      Number(rewardData.rewardPercent) || rewardConfig.rewardPercent,
    status: trimString(rewardData.status) || 'pending',
    createdAt: docTimestampToIso(rewardData.createdAt),
    updatedAt: docTimestampToIso(rewardData.updatedAt),
    paidAt: docTimestampToIso(rewardData.paidAt),
    paidBy: trimString(rewardData.paidBy) || null,
  };
}

async function getReferralProfile({userId}) {
  const db = getFirestore();
  const normalizedUserId = normalizeUserId(userId);
  const userRef = db.collection(USERS_COLLECTION).doc(normalizedUserId);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new ReferralStoreError(
      404,
      'user_not_found',
      'Referral user was not found.',
    );
  }

  const userData = userSnap.data() || {};
  const [referralsSnap, rewardsSnap] = await Promise.all([
    db
      .collection(REFERRALS_COLLECTION)
      .where('referrerUserId', '==', normalizedUserId)
      .get(),
    db
      .collection(REFERRAL_REWARDS_COLLECTION)
      .where('referrerUserId', '==', normalizedUserId)
      .get(),
  ]);

  const referralItems = referralsSnap.docs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        referredUserId: trimString(data.referredUserId) || doc.id,
        referrerUserId: trimString(data.referrerUserId) || null,
        referralCode: trimString(data.referralCode).toUpperCase() || null,
        status: trimString(data.status) || 'applied',
        appliedAt: docTimestampToIso(data.appliedAt),
        convertedAt: docTimestampToIso(data.convertedAt),
        updatedAt: docTimestampToIso(data.updatedAt),
      };
    })
    .sort((left, right) => {
      const leftTime = left.convertedAt || left.appliedAt || '';
      const rightTime = right.convertedAt || right.appliedAt || '';
      return rightTime.localeCompare(leftTime);
    });

  const rewardItems = rewardsSnap.docs
    .map((doc) => serializeReward(doc))
    .sort((left, right) => {
      return (right.createdAt || '').localeCompare(left.createdAt || '');
    });

  const pendingRewards = rewardItems.filter((item) => item.status === 'pending');
  const paidRewards = rewardItems.filter((item) => item.status === 'paid');
  const pendingEarningsPhp = pendingRewards.reduce(
    (sum, item) => sum + item.amountPhp,
    0,
  );
  const paidEarningsPhp = paidRewards.reduce(
    (sum, item) => sum + item.amountPhp,
    0,
  );

  return {
    ok: true,
    user: {
      userId: trimString(userData.userId) || normalizedUserId,
      displayName: trimString(userData.displayName) || null,
      referralCode: trimString(userData.referralCode).toUpperCase() || null,
      referredByUserId: readReferredByUserId(userData) || null,
      referredByCode: readReferredByCode(userData) || null,
      referrerUserId: readReferredByUserId(userData) || null,
      referrerCode: readReferredByCode(userData) || null,
      createdAt: docTimestampToIso(userData.createdAt),
      updatedAt: docTimestampToIso(userData.updatedAt),
      appliedReferralAt: docTimestampToIso(userData.appliedReferralAt),
    },
    stats: {
      totalReferrals: referralItems.length,
      pendingRewards: pendingRewards.length,
      paidRewards: paidRewards.length,
      pendingEarningsPhp,
      paidEarningsPhp,
      totalEarningsPhp: pendingEarningsPhp + paidEarningsPhp,
    },
    referrals: referralItems,
    rewards: rewardItems,
  };
}

module.exports = {
  DEFAULT_PREMIUM_PRICE_PHP,
  DEFAULT_REFERRAL_REWARD_PERCENT,
  ReferralStoreError,
  applyReferralCode,
  getReferralProfile,
  getRewardById,
  hashPurchaseToken,
  markReferralRewardPaid,
  recordVerifiedPurchase,
  registerUser,
  resolveRewardConfig,
};
