const DEFAULT_MAYA_CHECKOUT_URL = "https://pg.maya.ph/checkout/v1/checkouts";

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

function buildSiteUrl(req) {
  const host = req.headers["x-forwarded-host"] || req.headers.host;
  const protocol = req.headers["x-forwarded-proto"] || "https";
  return process.env.SITE_URL || `${protocol}://${host}`;
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

function buildMayaItem(name, unitPrice, quantity) {
  const lineTotal = unitPrice * quantity;
  return {
    name,
    quantity,
    amount: {
      value: unitPrice,
      currency: "PHP"
    },
    totalAmount: {
      value: lineTotal,
      currency: "PHP"
    }
  };
}

function isValidQuantity(quantity) {
  return Number.isInteger(quantity) && quantity > 0 && quantity <= 99;
}

function buildCartCheckout(body) {
  if (!Array.isArray(body.items) || body.items.length === 0) {
    throw new Error("Cart is empty.");
  }

  const normalizedItems = body.items.map((item) => {
    const product = ALLOWED_PRODUCTS[item.id];
    if (!product) {
      throw new Error(`Invalid cart item id: ${item.id}`);
    }

    if (product.type === "quote") {
      throw new Error(`Quote-only item cannot be checked out directly: ${product.name}`);
    }

    const quantity = Number(item.quantity);
    if (!isValidQuantity(quantity)) {
      throw new Error(`Invalid quantity for item: ${product.name}`);
    }

    return {
      id: item.id,
      name: product.name,
      price: product.price,
      quantity
    };
  });

  const computedTotal = normalizedItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  const requestedTotal = Number(body.totalAmount);

  if (!computedTotal) {
    throw new Error("Cart is empty.");
  }

  if (!Number.isFinite(requestedTotal) || requestedTotal !== computedTotal) {
    throw new Error("Cart total mismatch.");
  }

  return {
    source: "service-catalog-cart",
    checkoutItems: normalizedItems.map((item) => buildMayaItem(item.name, item.price, item.quantity)),
    totalAmount: computedTotal,
    itemCount: normalizedItems.reduce((sum, item) => sum + item.quantity, 0),
    customerNote: typeof body.customerNote === "string" ? body.customerNote.trim() : ""
  };
}

function buildLegacyCheckout(body) {
  const packageName = body.packageName;
  const amount = Number(body.amount);
  const legacy = LEGACY_PACKAGES[packageName];

  if (!legacy || legacy.price !== amount) {
    throw new Error("Invalid package or amount.");
  }

  return {
    source: "direct-package",
    checkoutItems: [buildMayaItem(packageName, legacy.price, 1)],
    totalAmount: legacy.price,
    itemCount: 1,
    customerNote: ""
  };
}

export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed. Use POST from the website payment buttons." });
  }

  try {
    const publicKey = process.env.MAYA_CHECKOUT_PUBLIC_KEY;
    if (!publicKey) {
      return res.status(500).json({ error: "MAYA_CHECKOUT_PUBLIC_KEY is missing in Vercel Environment Variables." });
    }

    const mayaCheckoutUrl = process.env.MAYA_CHECKOUT_BASE_URL || DEFAULT_MAYA_CHECKOUT_URL;
    const baseUrl = buildSiteUrl(req);
    const body = parseBody(req.body);

    const checkoutRequest = Array.isArray(body.items)
      ? buildCartCheckout(body)
      : buildLegacyCheckout(body);

    const requestReferenceNumber = `intellium-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;

    const payload = {
      totalAmount: {
        value: checkoutRequest.totalAmount,
        currency: "PHP"
      },
      requestReferenceNumber,
      redirectUrl: {
        success: `${baseUrl}/success.html`,
        failure: `${baseUrl}/failed.html`,
        cancel: `${baseUrl}/failed.html`
      },
      items: checkoutRequest.checkoutItems,
      metadata: {
        brand: "Intellium Digital",
        source: checkoutRequest.source,
        itemCount: checkoutRequest.itemCount,
        customerNote: checkoutRequest.customerNote || null
      }
    };

    const auth = Buffer.from(`${publicKey}:`).toString("base64");
    const mayaResponse = await fetch(mayaCheckoutUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${auth}`
      },
      body: JSON.stringify(payload)
    });

    const rawResponse = await mayaResponse.text();
    let data;

    try {
      data = rawResponse ? JSON.parse(rawResponse) : {};
    } catch {
      data = { raw: rawResponse };
    }

    if (!mayaResponse.ok) {
      console.error("Maya Checkout API error:", JSON.stringify(data));
      return res.status(mayaResponse.status || 500).json({
        error: data.message || data.error || "Maya Checkout rejected the checkout request.",
        mayaResponse: data
      });
    }

    const checkoutUrl = data.redirectUrl || data.checkoutUrl || data.url;
    if (!checkoutUrl) {
      return res.status(500).json({
        error: "Maya Checkout did not return a checkout URL.",
        mayaResponse: data
      });
    }

    return res.status(200).json({
      checkoutId: data.id || data.checkoutId || null,
      requestReferenceNumber,
      checkoutUrl,
      totalAmount: checkoutRequest.totalAmount
    });
  } catch (error) {
    console.error("Create Maya Checkout function crashed:", error);
    return res.status(400).json({
      error: error && error.message ? error.message : "Server error creating Maya Checkout link."
    });
  }
}
