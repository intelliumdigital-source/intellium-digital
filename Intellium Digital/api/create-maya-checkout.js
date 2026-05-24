const PROD_MAYA_CHECKOUT_URL = "https://pg.maya.ph/checkout/v1/checkouts";
const SANDBOX_MAYA_CHECKOUT_URL = "https://pg-sandbox.paymaya.com/checkout/v1/checkouts";

const ALLOWED_PRODUCTS = {
  "basic-logo-design": { name: "Basic Logo Design", price: 1500, type: "fixed" },
  "premium-logo-design": { name: "Premium Logo Design", price: 2500, type: "fixed" },
  "facebook-profile-cover": { name: "Facebook Profile + Cover Photo", price: 1500, type: "fixed" },
  "brand-color-font-guide": { name: "Brand Color + Font Guide", price: 1000, type: "fixed" },
  "branding-kit-bundle": { name: "Branding Kit Bundle", price: 3500, type: "fixed" },

  "starter-website-5-pages": { name: "Starter Website, up to 5 pages", price: 5000, type: "fixed" },
  "business-website-10-pages": { name: "Business Website, up to 10 pages", price: 10000, type: "fixed" },
  "premium-website-redesign": { name: "Premium Website Redesign", price: 12000, type: "fixed" },
  "booking-inquiry-form-setup": { name: "Booking / Inquiry Form Setup", price: 2000, type: "fixed" },
  "website-copywriting-setup": { name: "Website Copywriting Setup", price: 2500, type: "fixed" },
  "extra-page": { name: "Extra Page", price: 1000, type: "fixed" },

  "maya-checkout-button-setup": { name: "Maya Checkout Button Setup", price: 4000, type: "fixed" },
  "product-service-checkout-flow": { name: "Product / Service Checkout Flow", price: 6000, type: "fixed" },
  "maya-webhook-payment-status-setup": { name: "Maya Webhook / Payment Status Setup", price: 5000, type: "fixed" },
  "success-failed-payment-pages": { name: "Success / Failed Payment Pages", price: 2000, type: "fixed" },
  "website-maya-integration-promo": { name: "Website + Maya Integration Promo", price: 18000, type: "featured" },

  "basic-seo-setup": { name: "Basic SEO Setup", price: 2500, type: "fixed" },
  "google-search-console-setup": { name: "Google Search Console Setup", price: 1500, type: "fixed" },
  "seo-page-titles-meta-descriptions": { name: "SEO Page Titles + Meta Descriptions", price: 2000, type: "fixed" },
  "local-business-seo-setup": { name: "Local Business SEO Setup", price: 3500, type: "fixed" },
  "basic-sem-ads-launch-setup": { name: "Basic SEM / Ads Launch Setup", price: 4000, type: "fixed" },

  "auto-reply-faq-setup": { name: "Auto-reply / FAQ Setup", price: 2500, type: "fixed" },
  "lead-capture-form-google-sheet": { name: "Lead Capture Form + Google Sheet", price: 3000, type: "fixed" },
  "booking-request-flow": { name: "Booking Request Flow", price: 3500, type: "fixed" },
  "email-notification-automation": { name: "Email Notification Automation", price: 2500, type: "fixed" },
  "basic-business-automation-bundle": { name: "Basic Business Automation Bundle", price: 8000, type: "fixed" },

  "app-ui-mockup-prototype": { name: "App UI Mockup / Prototype", price: 8000, type: "fixed" },
  "simple-web-app": { name: "Simple Web App", price: 20000, type: "quote" },
  "business-mobile-app": { name: "Business Mobile App", price: 35000, type: "quote" },
  "admin-dashboard": { name: "Admin Dashboard", price: 15000, type: "quote" },
  "custom-app-quotation": { name: "Custom App Quotation", price: 35000, type: "quote" },

  "starter-digital-presence-bundle": { name: "Starter Digital Presence", price: 5000, type: "fixed" },
  "business-website-package-bundle": { name: "Business Website Package", price: 10000, type: "fixed" },
  "full-digital-business-setup-bundle": { name: "Full Digital Business Setup", price: 25000, type: "fixed" },
  "business-app-starter-bundle": { name: "Business App Starter", price: 35000, type: "quote" }
};

const LEGACY_PACKAGES = {
  "Project Reservation Fee": { price: 1000 },
  "Starter Website Package": { price: 5000 },
  "Website + Maya Integration Promo": { price: 18000 },
  "Full Digital Business Setup": { price: 25000 }
};

const MAX_CUSTOMER_NOTE_LENGTH = 300;
const GENERIC_CHECKOUT_ERROR = "We could not start Maya Checkout right now. Please try again or message Intellium Digital.";

function buildSiteUrl(req) {
  const host = req.headers["x-forwarded-host"] || req.headers.host;
  const protocol = req.headers["x-forwarded-proto"] || "https";
  return `${protocol}://${host}`;
}

function parseBody(body) {
  if (!body) {
    return {};
  }

  if (typeof body === "string") {
    return JSON.parse(body);
  }

  return body;
}

function sanitizeCustomerNote(note) {
  if (typeof note !== "string") {
    return "";
  }

  return note.replace(/\s+/g, " ").trim().slice(0, MAX_CUSTOMER_NOTE_LENGTH);
}

function getMayaConfig(req) {
  const secretKey = process.env.MAYA_SECRET_KEY;
  if (!secretKey) {
    throw new Error("MAYA_SECRET_KEY is missing in Vercel Environment Variables.");
  }

  const mode = String(process.env.MAYA_ENV || "sandbox").toLowerCase() === "production"
    ? "production"
    : "sandbox";

  const checkoutUrl = mode === "production"
    ? PROD_MAYA_CHECKOUT_URL
    : SANDBOX_MAYA_CHECKOUT_URL;

  const siteUrl = buildSiteUrl(req);

  return {
    secretKey,
    mode,
    checkoutUrl,
    successUrl: process.env.MAYA_SUCCESS_URL || `${siteUrl}/success.html`,
    failedUrl: process.env.MAYA_FAILED_URL || `${siteUrl}/failed.html`,
    cancelUrl: process.env.MAYA_CANCEL_URL || process.env.MAYA_FAILED_URL || `${siteUrl}/failed.html`,
    webhookUrl: process.env.MAYA_WEBHOOK_URL || ""
  };
}

function buildMayaItem(name, unitPrice, quantity) {
  const total = unitPrice * quantity;

  return {
    name,
    quantity,
    amount: {
      value: unitPrice,
      currency: "PHP"
    },
    totalAmount: {
      value: total,
      currency: "PHP"
    }
  };
}

function isValidQuantity(value) {
  return Number.isInteger(value) && value > 0 && value <= 99;
}

function normalizeCartCheckout(body) {
  if (!Array.isArray(body.items) || body.items.length === 0) {
    throw new Error("Your cart is empty.");
  }

  const normalizedItems = body.items.map((item) => {
    const product = ALLOWED_PRODUCTS[item.id];
    if (!product) {
      throw new Error("One of the selected cart items is invalid.");
    }

    if (product.type === "quote") {
      throw new Error(`${product.name} requires a custom quote and cannot be paid online yet.`);
    }

    const quantity = Number(item.quantity);
    if (!isValidQuantity(quantity)) {
      throw new Error(`Invalid quantity for ${product.name}.`);
    }

    return {
      id: item.id,
      name: product.name,
      quantity,
      unitPrice: product.price
    };
  });

  const computedTotal = normalizedItems.reduce((sum, item) => sum + (item.unitPrice * item.quantity), 0);
  const requestedTotal = Number(body.totalAmount);

  if (!Number.isFinite(requestedTotal) || requestedTotal !== computedTotal) {
    throw new Error("Cart total mismatch. Please refresh the page and try again.");
  }

  return {
    source: "catalog-cart",
    descriptor: `${normalizedItems.length} cart item${normalizedItems.length === 1 ? "" : "s"}`,
    items: normalizedItems,
    totalAmount: computedTotal,
    customerNote: sanitizeCustomerNote(body.customerNote)
  };
}

function normalizeLegacyCheckout(body) {
  const packageName = typeof body.packageName === "string" ? body.packageName.trim() : "";
  const amount = Number(body.amount);
  const selectedPackage = LEGACY_PACKAGES[packageName];

  if (!packageName || !selectedPackage || !Number.isFinite(amount) || amount !== selectedPackage.price) {
    throw new Error("Invalid package or amount. Please refresh the page and try again.");
  }

  return {
    source: "maya-package-button",
    descriptor: packageName,
    items: [{ id: packageName, name: packageName, quantity: 1, unitPrice: selectedPackage.price }],
    totalAmount: selectedPackage.price,
    customerNote: ""
  };
}

function normalizeCheckoutRequest(body) {
  return Array.isArray(body.items)
    ? normalizeCartCheckout(body)
    : normalizeLegacyCheckout(body);
}

function buildCheckoutPayload(checkoutRequest, config) {
  const reference = `intellium-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

  return {
    requestReferenceNumber: reference,
    totalAmount: {
      value: checkoutRequest.totalAmount,
      currency: "PHP"
    },
    redirectUrl: {
      success: config.successUrl,
      failure: config.failedUrl,
      cancel: config.cancelUrl
    },
    items: checkoutRequest.items.map((item) => buildMayaItem(item.name, item.unitPrice, item.quantity)),
    metadata: {
      brand: "Intellium Digital",
      source: checkoutRequest.source,
      descriptor: checkoutRequest.descriptor,
      itemCount: checkoutRequest.items.reduce((sum, item) => sum + item.quantity, 0),
      customerNote: checkoutRequest.customerNote || null,
      mayaEnv: config.mode,
      webhookConfigured: Boolean(config.webhookUrl)
    }
  };
}

async function createMayaSession(payload, config) {
  const auth = Buffer.from(`${config.secretKey}:`).toString("base64");
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
  let data = {};

  if (rawText) {
    try {
      data = JSON.parse(rawText);
    } catch {
      data = { rawText };
    }
  }

  if (!response.ok) {
    console.error("Maya create checkout failed", JSON.stringify({
      status: response.status,
      payloadReference: payload.requestReferenceNumber,
      error: data?.message || data?.error || data?.code || rawText || "Unknown Maya error"
    }));

    throw new Error(GENERIC_CHECKOUT_ERROR);
  }

  const checkoutUrl = data.redirectUrl || data.checkoutUrl || data.url;
  if (typeof checkoutUrl !== "string" || !checkoutUrl) {
    console.error("Maya create checkout missing redirect URL", JSON.stringify({
      payloadReference: payload.requestReferenceNumber,
      responseKeys: Object.keys(data || {})
    }));

    throw new Error(GENERIC_CHECKOUT_ERROR);
  }

  return {
    checkoutId: data.id || data.checkoutId || null,
    checkoutUrl,
    requestReferenceNumber: payload.requestReferenceNumber
  };
}

export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed. Use POST." });
  }

  try {
    const body = parseBody(req.body);
    const config = getMayaConfig(req);
    const checkoutRequest = normalizeCheckoutRequest(body);
    const payload = buildCheckoutPayload(checkoutRequest, config);
    const session = await createMayaSession(payload, config);

    return res.status(200).json({
      checkoutUrl: session.checkoutUrl,
      checkoutId: session.checkoutId,
      requestReferenceNumber: session.requestReferenceNumber
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : GENERIC_CHECKOUT_ERROR;
    const statusCode = message.includes("missing in Vercel") ? 500 : 400;

    if (statusCode === 500) {
      console.error("Create Maya Checkout configuration error:", message);
    } else {
      console.error("Create Maya Checkout request failed:", message);
    }

    return res.status(statusCode).json({
      error: message || GENERIC_CHECKOUT_ERROR
    });
  }
}
