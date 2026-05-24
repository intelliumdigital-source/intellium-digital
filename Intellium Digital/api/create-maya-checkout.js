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

function getConfig(req) {
  const mayaCheckoutKey = process.env.MAYA_PUBLIC_KEY;
  if (!mayaCheckoutKey) {
    throw new Error("Missing MAYA_PUBLIC_KEY");
  }

  const mode = String(process.env.MAYA_ENV || "sandbox").toLowerCase() === "production"
    ? "production"
    : "sandbox";

  const siteUrl = buildSiteUrl(req);

  return {
    mayaCheckoutKey,
    environment: mode,
    checkoutUrl: mode === "production" ? PROD_MAYA_CHECKOUT_URL : SANDBOX_MAYA_CHECKOUT_URL,
    successUrl: process.env.MAYA_SUCCESS_URL || `${siteUrl}/success.html`,
    failedUrl: process.env.MAYA_FAILED_URL || `${siteUrl}/failed.html`,
    cancelUrl: process.env.MAYA_CANCEL_URL || `${siteUrl}/failed.html`
  };
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
        unitPrice: fallbackAmount
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
        unitPrice: fallbackAmount
      }
    ];
  }

  return items.map((item, index) => {
    const name = sanitizeText(item?.name, 120);
    const unitPrice = parseAmount(item?.amount ?? item?.price);
    const quantity = Number(item?.quantity ?? 1);

    if (!name) {
      throw new Error(`Item ${index + 1} is missing a valid name.`);
    }

    if (!Number.isFinite(unitPrice) || unitPrice <= 0) {
      throw new Error(`Item ${index + 1} has an invalid amount.`);
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error(`Item ${index + 1} has an invalid quantity.`);
    }

    return { name, quantity, unitPrice };
  });
}

function buildPayload(body, config) {
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
  const itemsTotal = normalizedItems.reduce((sum, item) => sum + (item.unitPrice * item.quantity), 0);

  if (Math.abs(itemsTotal - amount) > 0.01) {
    throw new Error("amount does not match the provided items total.");
  }

  const requestReferenceNumber = `intellium-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

  return {
    requestReferenceNumber,
    totalAmount: {
      value: amount,
      currency: "PHP"
    },
    buyer: {
      firstName: "Intellium",
      lastName: "Digital"
    },
    items: normalizedItems.map((item) => ({
      name: item.name,
      quantity: item.quantity,
      amount: {
        value: item.unitPrice,
        currency: "PHP"
      },
      totalAmount: {
        value: Math.round(item.unitPrice * item.quantity * 100) / 100,
        currency: "PHP"
      }
    })),
    redirectUrl: {
      success: config.successUrl,
      failure: config.failedUrl,
      cancel: config.cancelUrl
    },
    metadata: {
      note: note || null,
      source: normalizedItems.length > 1 ? "catalog-cart" : "maya-button"
    }
  };
}

async function createCheckout(payload, config) {
  const auth = Buffer.from(`${config.mayaCheckoutKey}:`).toString("base64");

  console.info("Maya checkout config", {
    environment: config.environment,
    publicKeyPresent: Boolean(config.mayaCheckoutKey),
    publicKeyPreview: `${String(config.mayaCheckoutKey).slice(0, 5)}...`
  });

  const response = await fetch(config.checkoutUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: `Basic ${auth}`
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
    console.error("Maya checkout failed", {
      status: response.status,
      details: mayaData?.message || mayaData?.error || mayaData?.code || "Unknown Maya error"
    });

    return {
      ok: false,
      status: response.status,
      body: {
        error: "Maya checkout failed",
        details: mayaData?.message || mayaData?.error || "The checkout provider rejected the request."
      }
    };
  }

  const checkoutUrl = mayaData.redirectUrl || mayaData.checkoutUrl || mayaData.paymentUrl;
  if (!checkoutUrl) {
    console.error("Maya checkout missing redirect URL", {
      requestReferenceNumber: payload.requestReferenceNumber,
      responseKeys: Object.keys(mayaData || {})
    });

    return {
      ok: false,
      status: 502,
      body: {
        error: "Maya checkout failed",
        details: "Maya did not return a checkout URL."
      }
    };
  }

  return {
    ok: true,
    status: 200,
    body: {
      checkoutUrl,
      checkoutId: mayaData.id || mayaData.checkoutId || null,
      requestReferenceNumber: mayaData.requestReferenceNumber || payload.requestReferenceNumber
    }
  };
}

export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed.", details: "Use POST only." });
  }

  try {
    const body = parseBody(req.body);
    const config = getConfig(req);
    const payload = buildPayload(body, config);
    const result = await createCheckout(payload, config);
    return res.status(result.status).json(result.body);
  } catch (error) {
    console.error("Create Maya Checkout error", error instanceof Error ? error.message : String(error));
    return res.status(400).json({
      error: "Maya checkout failed",
      details: error instanceof Error ? error.message : "Unable to build the checkout request."
    });
  }
}
