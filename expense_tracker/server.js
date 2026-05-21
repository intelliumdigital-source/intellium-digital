const express = require('express');
const crypto = require('crypto');
const {
  handlePremiumVerification,
  buildConfigCheckResponse,
  buildErrorResponse,
} = require('./verifier/premium-verifier');
const {
  ReferralStoreError,
  applyReferralCode,
  getReferralProfile,
  markReferralRewardPaid,
  registerUser,
} = require('./verifier/referral-store');

const app = express();
const port = Number.parseInt(process.env.PORT || '8080', 10) || 8080;

app.disable('x-powered-by');

app.use(
  express.json({
    limit: '16kb',
    strict: true,
    type: 'application/json',
  }),
);

app.get('/healthz', (_req, res) => {
  res.status(200).json({
    ok: true,
    service: 'sweldotrack-play-verifier',
  });
});

app.get('/config-check', async (_req, res) => {
  try {
    const body = await buildConfigCheckResponse();
    return res.status(body.ok ? 200 : 503).json(body);
  } catch (_) {
    return res.status(500).json(
      buildErrorResponse({
        code: 'config_check_failed',
        message: 'Premium verification could not be completed right now.',
        recoverable: true,
      }),
    );
  }
});

function trimString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function buildApiErrorResponse(code, message) {
  return {
    ok: false,
    error: {
      code,
      message,
    },
  };
}

function sendApiError(res, statusCode, code, message, extraHeaders = {}) {
  return res.status(statusCode).set(extraHeaders).json(
    buildApiErrorResponse(code, message),
  );
}

function getAuthorizationToken(req) {
  const authorizationHeader = trimString(req.headers.authorization);
  if (!authorizationHeader) return '';

  const bearerMatch = authorizationHeader.match(/^Bearer\s+(.+)$/i);
  if (bearerMatch) {
    return trimString(bearerMatch[1]);
  }

  return authorizationHeader;
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

function requireAdminReferralKey(req, res) {
  const adminReferralKey = trimString(process.env.ADMIN_REFERRAL_KEY);
  if (!adminReferralKey) {
    sendApiError(
      res,
      500,
      'admin_referral_key_not_configured',
      'Admin referral key is not configured on the backend.',
    );
    return false;
  }

  const providedToken = getAuthorizationToken(req);
  if (!timingSafeEqualString(providedToken, adminReferralKey)) {
    sendApiError(
      res,
      401,
      'unauthorized',
      'Unauthorized admin referral request.',
    );
    return false;
  }

  return true;
}

function resolveErrorStatusCode(error) {
  return Number(error?.statusCode) > 0 ? Number(error.statusCode) : 500;
}

function handleRouteError(res, error) {
  if (error instanceof ReferralStoreError) {
    return sendApiError(
      res,
      resolveErrorStatusCode(error),
      trimString(error.code) || 'referral_error',
      trimString(error.message) || 'Referral request failed.',
    );
  }

  return sendApiError(
    res,
    500,
    'internal_error',
    'Internal server error.',
  );
}

app.post('/referral/register-user', async (req, res) => {
  try {
    const profile = await registerUser({
      userId: req.body?.userId,
      displayName: req.body?.displayName,
    });
    return res.status(200).json(profile);
  } catch (error) {
    return handleRouteError(res, error);
  }
});

app.post('/referral/apply-code', async (req, res) => {
  try {
    const profile = await applyReferralCode({
      userId: req.body?.userId,
      referralCode: req.body?.referralCode || req.body?.code,
    });
    return res.status(200).json(profile);
  } catch (error) {
    return handleRouteError(res, error);
  }
});

app.get('/referral/me', async (req, res) => {
  try {
    const profile = await getReferralProfile({
      userId: req.query?.userId,
    });
    return res.status(200).json(profile);
  } catch (error) {
    return handleRouteError(res, error);
  }
});

app.post('/admin/referral/mark-paid', async (req, res) => {
  if (!requireAdminReferralKey(req, res)) {
    return;
  }

  try {
    const reward = await markReferralRewardPaid({
      rewardId: req.body?.rewardId,
      paidBy: req.body?.paidBy || 'admin',
    });
    return res.status(200).json({
      ok: true,
      reward,
    });
  } catch (error) {
    return handleRouteError(res, error);
  }
});

app
  .route('/verify-premium')
  .post(async (req, res) => {
    try {
      return await handlePremiumVerification(req, res);
    } catch (error) {
      console.error('Premium verification route failed.', {
        name: trimString(error?.name) || 'Error',
        message:
          trimString(error?.message) ||
          'Premium verification route failure.',
      });
      if (res.headersSent) {
        return;
      }
      return res.status(500).json(
        buildErrorResponse({
          code: 'backend_error',
          message: 'Premium verification could not be completed right now.',
          recoverable: true,
        }),
      );
    }
  })
  .all((req, res) => {
    return res
      .status(405)
      .json(
        buildErrorResponse({
          code: 'method_not_allowed',
          message: 'Method not allowed. Use POST.',
        }),
      );
  });

app.use((req, res) => {
  res
    .status(404)
    .json(
      buildErrorResponse({
        code: 'not_found',
        message: 'Not found.',
      }),
    );
});

app.use((error, _req, res, _next) => {
  const isJsonParseError =
    error instanceof SyntaxError && error.status === 400 && 'body' in error;

  if (isJsonParseError) {
    return res
      .status(400)
      .json(
        buildErrorResponse({
          code: 'invalid_json',
          message: 'Invalid JSON request body.',
        }),
      );
  }

  return res
    .status(500)
    .json(
      buildErrorResponse({
        code: 'internal_error',
        message: 'Internal server error.',
      }),
    );
});

app.listen(port, () => {
  console.log(
    `SweldoTrack premium verifier listening on http://0.0.0.0:${port}`,
  );
});

module.exports = app;
