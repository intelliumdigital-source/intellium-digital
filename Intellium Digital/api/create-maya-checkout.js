const DEFAULT_MAYA_CHECKOUT_URL = "https://pg.maya.ph/checkout/v1/checkouts";

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
    const packageName = body.packageName;
    const amount = Number(body.amount);

    const allowedPackages = {
      "Project Reservation Fee": 1000,
      "Starter Website Package": 5000,
      "Website + Maya Integration Promo": 18000,
      "Full Digital Business Setup": 25000
    };

    if (!packageName || !allowedPackages[packageName] || allowedPackages[packageName] !== amount) {
      return res.status(400).json({
        error: "Invalid package or amount.",
        received: { packageName, amount }
      });
    }

    const requestReferenceNumber = `intellium-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const payload = {
      totalAmount: {
        value: amount,
        currency: "PHP"
      },
      requestReferenceNumber,
      redirectUrl: {
        success: `${baseUrl}/success.html`,
        failure: `${baseUrl}/failed.html`,
        cancel: `${baseUrl}/failed.html`
      },
      items: [
        {
          name: packageName,
          quantity: 1,
          totalAmount: {
            value: amount,
            currency: "PHP"
          },
          amount: {
            value: amount,
            currency: "PHP"
          }
        }
      ],
      metadata: {
        brand: "Intellium Digital",
        service: packageName
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
      checkoutUrl
    });
  } catch (error) {
    console.error("Create Maya Checkout function crashed:", error);
    return res.status(500).json({
      error: "Server error creating Maya Checkout link.",
      details: error && error.message ? error.message : String(error)
    });
  }
}
