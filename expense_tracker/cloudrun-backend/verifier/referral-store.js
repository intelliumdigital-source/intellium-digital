const crypto = require('crypto');
const fs = require('fs/promises');
const admin = require('firebase-admin');
const os = require('os');
const path = require('path');

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
const DEFAULT_REFERRAL_REWARD_AMOUNT_PHP = 20;
const PURCHASE_TOKEN_HASH_ALGORITHM = 'sha256';
const DEFAULT_REFERRAL_STORE_FILENAME = 'sweldotrack-referral-store.json';
let fileStoreQueue = Promise.resolve();

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

function logReferralEvent(event, meta = {}, level = 'info') {
  const payload = {
    severity: level.toUpperCase(),
    component: 'referral_store',
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

function hashUserIdFingerprint(userId) {
  const normalized = trimString(userId);
  if (!normalized) return null;
  return crypto
    .createHash('sha256')
    .update(normalized, 'utf8')
    .digest('hex')
    .slice(0, 12);
}

function safeReferralReason(error) {
  return (
    trimString(error?.code) ||
    trimString(error?.message) ||
    trimString(error?.name) ||
    'unknown'
  );
}

function emptyReferralStoreData() {
  return {
    users: {},
    referralCodes: {},
    referrals: {},
    purchases: {},
    rewards: {},
  };
}

function ensureReferralStoreShape(store) {
  const normalized = store && typeof store === 'object'
    ? store
    : emptyReferralStoreData();
  normalized.users = normalized.users && typeof normalized.users === 'object'
    ? normalized.users
    : {};
  normalized.referralCodes =
    normalized.referralCodes && typeof normalized.referralCodes === 'object'
      ? normalized.referralCodes
      : {};
  normalized.referrals =
    normalized.referrals && typeof normalized.referrals === 'object'
      ? normalized.referrals
      : {};
  normalized.purchases =
    normalized.purchases && typeof normalized.purchases === 'object'
      ? normalized.purchases
      : {};
  normalized.rewards =
    normalized.rewards && typeof normalized.rewards === 'object'
      ? normalized.rewards
      : {};
  return normalized;
}

function resolveReferralStoreFilePath(env = process.env) {
  const configuredPath = trimString(env.REFERRAL_STORE_FILE);
  if (configuredPath) {
    return configuredPath;
  }
  return path.join(os.tmpdir(), DEFAULT_REFERRAL_STORE_FILENAME);
}

function shouldForceFileReferralStore(env = process.env) {
  return trimString(env.REFERRAL_STORE_MODE).toLowerCase() === 'file';
}

async function readReferralStoreFile(env = process.env) {
  const storeFile = resolveReferralStoreFilePath(env);
  try {
    const text = await fs.readFile(storeFile, 'utf8');
    if (!trimString(text)) {
      return emptyReferralStoreData();
    }
    return ensureReferralStoreShape(JSON.parse(text));
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return emptyReferralStoreData();
    }
    throw new ReferralStoreError(
      503,
      'referral_store_unavailable',
      'Referral store is temporarily unavailable.',
    );
  }
}

async function writeReferralStoreFile(store, env = process.env) {
  const storeFile = resolveReferralStoreFilePath(env);
  await fs.mkdir(path.dirname(storeFile), {recursive: true});
  const nextStore = JSON.stringify(ensureReferralStoreShape(store), null, 2);
  const tempFile = `${storeFile}.tmp`;
  await fs.writeFile(tempFile, nextStore, 'utf8');
  await fs.rename(tempFile, storeFile);
}

async function withReferralStoreFileLock(task) {
  const nextTask = fileStoreQueue.then(task, task);
  fileStoreQueue = nextTask.catch(() => {});
  return nextTask;
}

async function withReferralStoreFile(
  task,
  {persist = true, env = process.env} = {},
) {
  return withReferralStoreFileLock(async () => {
    const store = await readReferralStoreFile(env);
    const value = await task(store);
    if (persist) {
      await writeReferralStoreFile(store, env);
    }
    return value;
  });
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
  const rewardAmountPhp = roundCurrency(
    parsePositiveNumber(
      env.REFERRAL_REWARD_AMOUNT_PHP,
      DEFAULT_REFERRAL_REWARD_AMOUNT_PHP,
    ),
  );
  const configuredPercent = Number.parseFloat(
    `${env.REFERRAL_REWARD_PERCENT ?? ''}`.trim(),
  );
  const rewardPercent = Number.isFinite(configuredPercent) &&
      configuredPercent > 0
    ? configuredPercent > 1
      ? configuredPercent
      : configuredPercent * 100
    : roundCurrency((rewardAmountPhp / premiumPricePhp) * 100);

  return {
    premiumPricePhp,
    rewardPercent,
    rewardAmountPhp,
  };
}

function nowTimestamp() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function getFirestore() {
  try {
    if (!admin.apps.length) {
      admin.initializeApp();
    }

    return admin.firestore();
  } catch (_) {
    throw new ReferralStoreError(
      503,
      'referral_store_unavailable',
      'Referral store is temporarily unavailable.',
    );
  }
}

function isStoreUnavailableError(error) {
  if (error instanceof ReferralStoreError) {
    return error.code === 'referral_store_unavailable';
  }
  const reason = `${trimString(error?.code)} ${trimString(error?.message)}`
    .toLowerCase();
  return (
    reason.includes('firestore') ||
    reason.includes('database') ||
    reason.includes('permission-denied') ||
    reason.includes('permission denied') ||
    reason.includes('unavailable') ||
    reason.includes('failed-precondition') ||
    reason.includes('default credentials')
  );
}

function isoNow() {
  return new Date().toISOString();
}

function buildEmptyReferralProfile(userId) {
  return {
    ok: true,
    user: {
      userId,
      displayName: null,
      referralCode: null,
      referredByUserId: null,
      referredByCode: null,
      referrerUserId: null,
      referrerCode: null,
      createdAt: null,
      updatedAt: null,
      appliedReferralAt: null,
    },
    stats: {
      totalReferrals: 0,
      pendingRewards: 0,
      paidRewards: 0,
      pendingEarningsPhp: 0,
      paidEarningsPhp: 0,
      totalEarningsPhp: 0,
    },
    referrals: [],
    rewards: [],
  };
}

async function withReferralStoreFallback({
  operation,
  userId = null,
  firestoreOperation,
  fileOperation,
}) {
  const userFingerprint = hashUserIdFingerprint(userId);
  if (shouldForceFileReferralStore()) {
    return fileOperation();
  }

  try {
    return await firestoreOperation();
  } catch (error) {
    if (!isStoreUnavailableError(error)) {
      logReferralEvent(
        'referral_store_error',
        {operation, reason: safeReferralReason(error), userFingerprint},
        'warn',
      );
      throw error;
    }

    logReferralEvent(
      'referral_store_error',
      {
        operation,
        reason: safeReferralReason(error),
        userFingerprint,
      },
      'warn',
    );
    // Only use /tmp-backed file storage when REFERRAL_STORE_MODE=file is explicit.
    throw new ReferralStoreError(
      503,
      'referral_store_unavailable',
      'Referral store is temporarily unavailable.',
    );
  }
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

function ensureFileUserHasReferralCode({
  store,
  userId,
  displayName = null,
}) {
  const existingUser = store.users[userId] || {};
  let referralCode = trimString(existingUser.referralCode).toUpperCase();
  if (!referralCode) {
    for (let attempt = 0; attempt < 20; attempt += 1) {
      const nextCode = randomReferralCode();
      if (!store.referralCodes[nextCode]) {
        referralCode = nextCode;
        store.referralCodes[referralCode] = userId;
        break;
      }
    }
  }

  if (!referralCode) {
    throw new ReferralStoreError(
      500,
      'referral_code_generation_failed',
      'Could not generate a unique referral code.',
    );
  }

  const timestamp = isoNow();
  const referredByUserId = readReferredByUserId(existingUser) || null;
  const referredByCode = readReferredByCode(existingUser) || null;
  const nextUser = {
    userId,
    displayName:
      displayName ?? (trimString(existingUser.displayName) || null),
    referralCode,
    referredByUserId,
    referredByCode,
    referrerUserId: referredByUserId,
    referrerCode: referredByCode,
    createdAt: existingUser.createdAt || timestamp,
    updatedAt: timestamp,
    appliedReferralAt: existingUser.appliedReferralAt || null,
  };
  store.users[userId] = nextUser;
  store.referralCodes[referralCode] = userId;
  return nextUser;
}

function serializeFileReward(rewardData, rewardConfig) {
  return {
    rewardId: trimString(rewardData.rewardId),
    purchaseTokenHash:
      trimString(rewardData.purchaseTokenHash) ||
      trimString(rewardData.rewardId),
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
    createdAt: trimString(rewardData.createdAt) || null,
    updatedAt: trimString(rewardData.updatedAt) || null,
    paidAt: trimString(rewardData.paidAt) || null,
    paidBy: trimString(rewardData.paidBy) || null,
  };
}

function buildFileReferralProfile(store, userId) {
  const rewardConfig = resolveRewardConfig();
  const user = store.users[userId];
  if (!user) {
    return buildEmptyReferralProfile(userId);
  }

  const referralItems = Object.values(store.referrals)
    .filter((item) => trimString(item.referrerUserId) === userId)
    .map((item) => ({
      referredUserId: trimString(item.referredUserId) || null,
      referrerUserId: trimString(item.referrerUserId) || null,
      referralCode: trimString(item.referralCode).toUpperCase() || null,
      status: trimString(item.status) || 'applied',
      appliedAt: trimString(item.appliedAt) || null,
      convertedAt: trimString(item.convertedAt) || null,
      updatedAt: trimString(item.updatedAt) || null,
    }))
    .sort((left, right) =>
      (right.convertedAt || right.appliedAt || '').localeCompare(
        left.convertedAt || left.appliedAt || '',
      ),
    );

  const rewardItems = Object.values(store.rewards)
    .filter((item) => trimString(item.referrerUserId) === userId)
    .map((item) => serializeFileReward(item, rewardConfig))
    .sort((left, right) => (right.createdAt || '').localeCompare(left.createdAt || ''));

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
      userId: trimString(user.userId) || userId,
      displayName: trimString(user.displayName) || null,
      referralCode: trimString(user.referralCode).toUpperCase() || null,
      referredByUserId: readReferredByUserId(user) || null,
      referredByCode: readReferredByCode(user) || null,
      referrerUserId: readReferredByUserId(user) || null,
      referrerCode: readReferredByCode(user) || null,
      createdAt: trimString(user.createdAt) || null,
      updatedAt: trimString(user.updatedAt) || null,
      appliedReferralAt: trimString(user.appliedReferralAt) || null,
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

async function registerUser({userId, displayName = null}) {
  const normalizedUserId = normalizeUserId(userId);
  const normalizedDisplayName = normalizeDisplayName(displayName);
  const userFingerprint = hashUserIdFingerprint(normalizedUserId);
  logReferralEvent('referral_register_started', {
    userFingerprint,
    hasDisplayName: normalizedDisplayName != null,
  });

  const profile = await withReferralStoreFallback({
    operation: 'register_user',
    userId: normalizedUserId,
    firestoreOperation: async () => {
      const db = getFirestore();
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
    },
    fileOperation: async () =>
      withReferralStoreFile(async (store) => {
        ensureFileUserHasReferralCode({
          store,
          userId: normalizedUserId,
          displayName: normalizedDisplayName,
        });
        return buildFileReferralProfile(store, normalizedUserId);
      }),
  });

  logReferralEvent('referral_register_succeeded', {
    userFingerprint,
    referralCount: profile.stats.totalReferrals,
  });
  return profile;
}

async function applyReferralCode({userId, referralCode}) {
  const normalizedUserId = normalizeUserId(userId);
  const normalizedReferralCode = normalizeReferralCode(referralCode);
  const userFingerprint = hashUserIdFingerprint(normalizedUserId);
  const profile = await withReferralStoreFallback({
    operation: 'apply_referral_code',
    userId: normalizedUserId,
    firestoreOperation: async () => {
      const db = getFirestore();
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
        if (currentReferredByUserId) {
          throw new ReferralStoreError(
            409,
            currentReferredByUserId === referrerUserId
              ? 'referral_code_already_applied'
              : 'referrer_already_assigned',
            currentReferredByUserId === referrerUserId
              ? 'This referral code has already been applied.'
              : 'This user already has a referrer.',
          );
        }
        if (referralSnap.exists) {
          throw new ReferralStoreError(
            409,
            'referral_code_already_applied',
            'This referral code has already been applied.',
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

        transaction.create(referralRef, {
          referredUserId: normalizedUserId,
          referrerUserId,
          referralCode: normalizedReferralCode,
          status: 'applied',
          createdAt: timestamp,
          appliedAt: timestamp,
          updatedAt: timestamp,
        });
      });

      return getReferralProfile({userId: normalizedUserId});
    },
    fileOperation: async () =>
      withReferralStoreFile(async (store) => {
        const referrerUserId = trimString(store.referralCodes[normalizedReferralCode]);
        if (!referrerUserId) {
          throw new ReferralStoreError(
            404,
            'referral_code_not_found',
            'Referral code was not found.',
          );
        }
        if (referrerUserId === normalizedUserId) {
          throw new ReferralStoreError(
            409,
            'self_referral_blocked',
            'You cannot apply your own referral code.',
          );
        }

        const user = ensureFileUserHasReferralCode({
          store,
          userId: normalizedUserId,
        });
        if (readReferredByUserId(user)) {
          throw new ReferralStoreError(
            409,
            readReferredByUserId(user) === referrerUserId
              ? 'referral_code_already_applied'
              : 'referrer_already_assigned',
            readReferredByUserId(user) === referrerUserId
              ? 'This referral code has already been applied.'
              : 'This user already has a referrer.',
          );
        }
        if (store.referrals[normalizedUserId]) {
          throw new ReferralStoreError(
            409,
            'referral_code_already_applied',
            'This referral code has already been applied.',
          );
        }

        const timestamp = isoNow();
        user.referredByUserId = referrerUserId;
        user.referredByCode = normalizedReferralCode;
        user.referrerUserId = referrerUserId;
        user.referrerCode = normalizedReferralCode;
        user.appliedReferralAt = user.appliedReferralAt || timestamp;
        user.updatedAt = timestamp;

        store.referrals[normalizedUserId] = {
          referredUserId: normalizedUserId,
          referrerUserId,
          referralCode: normalizedReferralCode,
          status: 'applied',
          createdAt: timestamp,
          appliedAt: timestamp,
          updatedAt: timestamp,
        };

        return buildFileReferralProfile(store, normalizedUserId);
      }),
  });

  logReferralEvent('referral_apply_code_succeeded', {
    userFingerprint,
    referralCode: normalizedReferralCode,
  });
  return profile;
}

async function recordVerifiedPurchase({userId, payload, entitlement}) {
  const rewardConfig = resolveRewardConfig();
  const normalizedUserId = normalizeUserId(userId);
  const purchaseTokenHash = hashPurchaseToken(payload.purchaseToken);
  const latestOrderId = trimString(entitlement?.latestOrderId) || null;
  const purchaseId = trimString(payload.purchaseId) || null;
  const dedupeKey = latestOrderId || purchaseId || purchaseTokenHash;

  const outcome = {
    rewardId: dedupeKey,
    purchaseTokenHash,
    rewardCreated: false,
    rewardStatus: null,
  };

  await withReferralStoreFallback({
    operation: 'record_verified_purchase',
    userId: normalizedUserId,
    firestoreOperation: async () => {
      const db = getFirestore();
      const userRef = db.collection(USERS_COLLECTION).doc(normalizedUserId);
      const purchaseRef = db.collection(PURCHASES_COLLECTION).doc(purchaseTokenHash);
      const rewardRef = db
        .collection(REFERRAL_REWARDS_COLLECTION)
        .doc(dedupeKey);
      const referralRef = db.collection(REFERRALS_COLLECTION).doc(normalizedUserId);

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
          rewardId: dedupeKey,
          userId: normalizedUserId,
          referralCode,
          productId: trimString(payload.productId) || null,
          packageName: trimString(payload.packageName) || null,
          purchaseId,
          purchaseStatus: trimString(payload.purchaseStatus) || null,
          latestOrderId,
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
        if (
          !referrerUserId ||
          !referrerCode ||
          referrerUserId === normalizedUserId
        ) {
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
                Number(rewardSnap.data().amountPhp) ||
                rewardConfig.rewardAmountPhp,
              rewardUpdatedAt: timestamp,
            },
            {merge: true},
          );
          outcome.rewardStatus = existingRewardStatus;
          return;
        }

        transaction.create(rewardRef, {
          rewardId: dedupeKey,
          purchaseTokenHash,
          purchaseId,
          latestOrderId,
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
    },
    fileOperation: async () =>
      withReferralStoreFile(async (store) => {
        const user = ensureFileUserHasReferralCode({
          store,
          userId: normalizedUserId,
        });
        const timestamp = isoNow();
        const existingPurchase = store.purchases[purchaseTokenHash] || {};
        store.purchases[purchaseTokenHash] = {
          ...existingPurchase,
          purchaseTokenHash,
          rewardId: dedupeKey,
          userId: normalizedUserId,
          referralCode: trimString(user.referralCode).toUpperCase() || null,
          productId: trimString(payload.productId) || null,
          packageName: trimString(payload.packageName) || null,
          purchaseId,
          purchaseStatus: trimString(payload.purchaseStatus) || null,
          latestOrderId,
          expiryDate: trimString(entitlement?.expiryDate) || null,
          subscriptionState: trimString(entitlement?.subscriptionState) || null,
          acknowledgementState:
            trimString(entitlement?.acknowledgementState) || null,
          verified: Boolean(entitlement?.verified),
          active: Boolean(entitlement?.active),
          isTestPurchase: Boolean(entitlement?.isTestPurchase),
          premiumPricePhp: rewardConfig.premiumPricePhp,
          rewardPercent: rewardConfig.rewardPercent,
          createdAt: existingPurchase.createdAt || timestamp,
          updatedAt: timestamp,
        };

        const referrerUserId = readReferredByUserId(user);
        const referrerCode = readReferredByCode(user);
        if (
          !referrerUserId ||
          !referrerCode ||
          referrerUserId === normalizedUserId ||
          trimString(store.referralCodes[referrerCode]) !== referrerUserId
        ) {
          outcome.rewardStatus = trimString(store.rewards[dedupeKey]?.status) || null;
          return;
        }

        if (store.rewards[dedupeKey]) {
          outcome.rewardStatus = trimString(store.rewards[dedupeKey].status) || null;
          store.purchases[purchaseTokenHash].rewardStatus = outcome.rewardStatus;
          store.purchases[purchaseTokenHash].rewardAmountPhp =
            Number(store.rewards[dedupeKey].amountPhp) ||
            rewardConfig.rewardAmountPhp;
          store.purchases[purchaseTokenHash].rewardUpdatedAt = timestamp;
          return;
        }

        store.rewards[dedupeKey] = {
          rewardId: dedupeKey,
          purchaseTokenHash,
          purchaseId,
          latestOrderId,
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
        };
        store.referrals[normalizedUserId] = {
          ...(store.referrals[normalizedUserId] || {
            referredUserId: normalizedUserId,
            referrerUserId,
            referralCode: referrerCode,
            createdAt: timestamp,
            appliedAt: user.appliedReferralAt || timestamp,
          }),
          status: 'reward_pending',
          convertedAt: timestamp,
          updatedAt: timestamp,
        };
        store.purchases[purchaseTokenHash].rewardStatus = 'pending';
        store.purchases[purchaseTokenHash].rewardAmountPhp =
          rewardConfig.rewardAmountPhp;
        store.purchases[purchaseTokenHash].rewardUpdatedAt = timestamp;
        outcome.rewardCreated = true;
        outcome.rewardStatus = 'pending';
      }),
  });

  logReferralEvent('referral_purchase_bookkeeping_succeeded', {
    userFingerprint: hashUserIdFingerprint(normalizedUserId),
    purchaseTokenHash,
    rewardCreated: outcome.rewardCreated,
    rewardStatus: outcome.rewardStatus,
  });
  return outcome;
}

async function markReferralRewardPaid({rewardId, paidBy = 'admin'}) {
  const normalizedRewardId = trimString(rewardId);
  if (!normalizedRewardId) {
    throw new ReferralStoreError(
      400,
      'missing_reward_id',
      'Missing required field: rewardId.',
    );
  }

  if (shouldForceFileReferralStore()) {
    return withReferralStoreFile((store) => {
      const reward = store.rewards[normalizedRewardId];
      if (!reward) {
        throw new ReferralStoreError(
          404,
          'reward_not_found',
          'Referral reward was not found.',
        );
      }

      const timestamp = isoNow();
      if (trimString(reward.status) === 'paid') {
        reward.updatedAt = timestamp;
      } else {
        reward.status = 'paid';
        reward.paidAt = timestamp;
        reward.paidBy = trimString(paidBy) || 'admin';
        reward.updatedAt = timestamp;
      }

      return serializeFileReward(reward, resolveRewardConfig());
    });
  }

  const db = getFirestore();
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
  const normalizedRewardId = trimString(rewardId);
  if (shouldForceFileReferralStore()) {
    return withReferralStoreFile(
      (store) => {
        const reward = store.rewards[normalizedRewardId];
        if (!reward) {
          throw new ReferralStoreError(
            404,
            'reward_not_found',
            'Referral reward was not found.',
          );
        }

        return serializeFileReward(reward, resolveRewardConfig());
      },
      {persist: false},
    );
  }

  const db = getFirestore();
  const rewardRef = db
    .collection(REFERRAL_REWARDS_COLLECTION)
    .doc(normalizedRewardId);
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
  const normalizedUserId = normalizeUserId(userId);
  const userFingerprint = hashUserIdFingerprint(normalizedUserId);
  const profile = await withReferralStoreFallback({
    operation: 'get_referral_profile',
    userId: normalizedUserId,
    firestoreOperation: async () => {
      const db = getFirestore();
      const userRef = db.collection(USERS_COLLECTION).doc(normalizedUserId);
      const userSnap = await userRef.get();

      if (!userSnap.exists) {
        return registerUser({userId: normalizedUserId});
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
    },
    fileOperation: async () =>
      withReferralStoreFile(async (store) => {
        if (!store.users[normalizedUserId]) {
          ensureFileUserHasReferralCode({
            store,
            userId: normalizedUserId,
          });
        }
        return buildFileReferralProfile(store, normalizedUserId);
      }),
  });

  logReferralEvent('referral_dashboard_loaded', {
    userFingerprint,
    referralCount: profile.stats.totalReferrals,
    pendingRewards: profile.stats.pendingRewards,
  });
  return profile;
}

module.exports = {
  DEFAULT_PREMIUM_PRICE_PHP,
  DEFAULT_REFERRAL_REWARD_AMOUNT_PHP,
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
