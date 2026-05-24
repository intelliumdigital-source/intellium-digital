const PROD_MAYA_CHECKOUT_URL = "https://pg.paymaya.com/checkout/v1/checkouts";
const SANDBOX_MAYA_CHECKOUT_URL = "https://pg-sandbox.paymaya.com/checkout/v1/checkouts";

function parseBody(body) {
  if (!body) {
    return {};
  }

  if (typeof body === "string") {
    return JSON.parse(body);
  }

  return body;
}

function buildSiteUrl(req) {
  if (process.env.SITE_URL) {
    return process.env.SITE_URL.replace(/\/$/, "");
  }

  const host = req.headers["x-forwarded-host"] || req.headers.host;
  const protocol = req.headers["x-forwarded-proto"] || "https";
  return `${protocol}://${host}`;
}

function sanitizeText(value, maxLength = 200) {
  if (typeof value !== "string") {
    return "";
  }

  return value.replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function parseAmount(value) {
  const amount = Number(value);
  return Number.isFinite(amount) ? Math.round(amount * 100) / 100 : NaN;
}

function normalizeItems(items, fallbackName, fallbackAmount) {
  if (typeof items === "undefined") {
    return [
      {
        name: fallbackName,
        quantity: 1,
        lineAmount: fallbackAmount
      }
    ];
  }

  if (!Array.isArray(items)) {
    throw new Error("items must be an array when provided.");
  }

  if (items.length === 0) {
    return [
      {
        name: fallbackName,
        quantity: 1,
        lineAmount: fallbackAmount
      }
    ];
  }

  return items.map((item, index) => {
    const name = sanitizeText(item?.name, 120);
    const quantity = Number(item?.quantity ?? 1);
    const baseAmount = parseAmount(item?.amount ?? item?.price);

    if (!name) {
      throw new Error(`Item ${index + 1} is missing a valid name.`);
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error(`Item ${index + 1} has an invalid quantity.`);
    }

    if (!Number.isFinite(baseAmount) || baseAmount <= 0) {
      throw new Error(`Item ${index + 1} has an invalid amount.`);
    }

    const lineAmount = Math.round(baseAmount * quantity * 100) / 100;

    return {
      name,
      quantity,
      lineAmount
    };
  });
}

function buildDebug(mayaCheckoutKey, mayaCheckoutEndpoint) {
  return {
    env: process.env.MAYA_ENV || "missing",
    endpoint: mayaCheckoutEndpoint,
    publicKeyPrefix: mayaCheckoutKey.slice(0, 8),
    publicKeyLength: mayaCheckoutKey.length,
    hasSecretKey: Boolean(process.env.MAYA_SECRET_KEY),
    siteUrl: process.env.SITE_URL || "missing"
  };
}

function buildPayload(body, redirectUrl) {
  const name = sanitizeText(body?.name, 120);
  const amount = parseAmount(body?.amount);
  const note = sanitizeText(body?.note, 300);

  if (!name) {
    throw new Error("name is required.");
  }

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new Error("amount must be a positive number.");
  }

  const normalizedItems = normalizeItems(body?.items, name, amount);
  const itemsTotal = normalizedItems.reduce((sum, item) => sum + item.lineAmount, 0);

  if (Math.abs(itemsTotal - amount) > 0.01) {
    throw new Error("amount does not match the provided items total.");
  }

  const requestReferenceNumber = `intellium-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

  return {
    totalAmount: {
      value: amount,
      currency: "PHP"
    },
    buyer: {
      firstName: "Intellium",
      lastName: "Digital",
      contact: {
        email: "intelliumdigital@gmail.com",
        phone: "09929988439"
      }
    },
    items: normalizedItems.map((item) => ({
      name: item.name,
      quantity: item.quantity,
      totalAmount: {
        value: item.lineAmount,
        currency: "PHP"
      }
    })),
    redirectUrl: {
      success: redirectUrl.success,
      failure: redirectUrl.failure,
      cancel: redirectUrl.cancel
    },
    requestReferenceNumber,
    metadata: {
      note: note || null,
      source: normalizedItems.length > 1 ? "catalog-cart" : "maya-button"
    }
  };
}

export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed.", details: "Use POST only." });
  }

  const mayaCheckoutKey = process.env.MAYA_PUBLIC_KEY?.trim();
  if (!mayaCheckoutKey) {
    return res.status(500).json({
      error: "Missing MAYA_PUBLIC_KEY"
    });
  }

  const isProduction = process.env.MAYA_ENV === "production";
  const mayaCheckoutEndpoint = isProduction
    ? PROD_MAYA_CHECKOUT_URL
    : SANDBOX_MAYA_CHECKOUT_URL;
  const siteUrl = buildSiteUrl(req);
  const redirectUrl = {
    success: process.env.MAYA_SUCCESS_URL || `${siteUrl}/success.html`,
    failure: process.env.MAYA_FAILED_URL || `${siteUrl}/failed.html`,
    cancel: process.env.MAYA_CANCEL_URL || `${siteUrl}/failed.html`
  };
  const debug = buildDebug(mayaCheckoutKey, mayaCheckoutEndpoint);

  console.info("Maya checkout config", {
    env: process.env.MAYA_ENV || "missing",
    endpoint: mayaCheckoutEndpoint,
    publicKeyPrefix: `${mayaCheckoutKey.slice(0, 5)}...`,
    publicKeyLength: mayaCheckoutKey.length,
    hasSecretKey: Boolean(process.env.MAYA_SECRET_KEY)
  });

  try {
    const body = parseBody(req.body);
    const payload = buildPayload(body, redirectUrl);
    const authHeader = "Basic " + Buffer.from(`${mayaCheckoutKey}:`).toString("base64");

    const response = await fetch(mayaCheckoutEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        Authorization: authHeader
      },
      body: JSON.stringify(payload)
    });

    const rawText = await response.text();
    let mayaData = {};

    if (rawText) {
      try {
        mayaData = JSON.parse(rawText);
      } catch {
        mayaData = { rawText };
      }
    }

    if (!response.ok) {
      const mayaErrorMessage = mayaData?.message || mayaData?.error || mayaData?.code || "The checkout provider rejected the request.";
      console.error("Maya checkout failed", {
        status: response.status,
        details: mayaErrorMessage,
        debug
      });

      return res.status(response.status).json({
        error: "Maya checkout failed",
        details: mayaErrorMessage,
        debug
      });
    }

    const checkoutUrl = mayaData.redirectUrl || mayaData.checkoutUrl || mayaData.paymentUrl;
    if (!checkoutUrl) {
      console.error("Maya checkout missing redirect URL", {
        requestReferenceNumber: payload.requestReferenceNumber,
        debug,
        responseKeys: Object.keys(mayaData || {})
      });

      return res.status(502).json({
        error: "Maya checkout failed",
        details: "Maya did not return a checkout URL.",
        debug
      });
    }

    return res.status(200).json({
      checkoutUrl,
      checkoutId: mayaData.id || mayaData.checkoutId || null,
      requestReferenceNumber: mayaData.requestReferenceNumber || payload.requestReferenceNumber
    });
  } catch (error) {
    const safeMessage = error instanceof Error ? error.message : "Unable to build the checkout request.";
    console.error("Create Maya Checkout error", {
      details: safeMessage,
      debug
    });

    return res.status(400).json({
      error: "Maya checkout failed",
      details: safeMessage,
      debug
    });
  }
}
