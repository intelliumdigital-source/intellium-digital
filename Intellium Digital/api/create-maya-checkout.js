export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  try {
    const publicKey = (process.env.MAYA_PUBLIC_KEY || "").trim();
    const secretKey = (process.env.MAYA_SECRET_KEY || "").trim();
    const mayaEnv = (process.env.MAYA_ENV || "production").trim().toLowerCase();
    const siteUrl = (process.env.SITE_URL || "https://www.intelliumdigital.online").trim();

    if (!publicKey) {
      return res.status(500).json({
        error: "Missing MAYA_PUBLIC_KEY",
        debug: {
          hasPublicKey: false,
          hasSecretKey: Boolean(secretKey),
          env: mayaEnv
        }
      });
    }

    const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body;
    const name = String(body?.name || "Intellium Digital Payment").trim();
    const amount = Number(body?.amount);
    const note = String(body?.note || "").trim();

    if (!name || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        error: "Invalid checkout payload",
        details: "Name and positive amount are required."
      });
    }

    const rawItems = Array.isArray(body?.items) && body.items.length
      ? body.items
      : [{ name, amount, quantity: 1 }];

    const items = rawItems.map((item, index) => {
      const itemName = String(item?.name || name || `Item ${index + 1}`).trim();
      const quantity = Math.max(1, Number(item?.quantity || 1));
      const itemAmount = Number(item?.amount ?? item?.price ?? amount);

      return {
        name: itemName,
        quantity,
        totalAmount: {
          value: Number((itemAmount * quantity).toFixed(2)),
          currency: "PHP"
        }
      };
    });

    const requestReferenceNumber =
      "INTELLIUM-" + Date.now() + "-" + Math.random().toString(36).slice(2, 8).toUpperCase();

    const successUrl =
      (process.env.MAYA_SUCCESS_URL || `${siteUrl}/success.html`).trim();
    const failureUrl =
      (process.env.MAYA_FAILED_URL || `${siteUrl}/failed.html`).trim();
    const cancelUrl =
      (process.env.MAYA_CANCEL_URL || `${siteUrl}/failed.html`).trim();

    const checkoutPayload = {
      totalAmount: {
        value: Number(amount.toFixed(2)),
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
      items,
      redirectUrl: {
        success: successUrl,
        failure: failureUrl,
        cancel: cancelUrl
      },
      requestReferenceNumber,
      metadata: {
        source: "intelliumdigital.online",
        note
      }
    };

    const isProduction = mayaEnv === "production";
    const mayaEndpoint = isProduction
      ? "https://pg.paymaya.com/checkout/v1/checkouts"
      : "https://pg-sandbox.paymaya.com/checkout/v1/checkouts";

    const authHeader =
      "Basic " + Buffer.from(`${publicKey}:`).toString("base64");

    const mayaResponse = await fetch(mayaEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: authHeader
      },
      body: JSON.stringify(checkoutPayload)
    });

    const responseText = await mayaResponse.text();

    let mayaData;
    try {
      mayaData = responseText ? JSON.parse(responseText) : {};
    } catch {
      mayaData = { raw: responseText };
    }

    if (!mayaResponse.ok) {
      const mayaErrorMessage =
        mayaData?.message ||
        mayaData?.error ||
        mayaData?.raw ||
        "Maya checkout request failed.";

      return res.status(mayaResponse.status).json({
        error: "Maya checkout failed",
        details: mayaErrorMessage,
        debug: {
          env: mayaEnv,
          endpoint: mayaEndpoint,
          publicKeyPrefix: publicKey.slice(0, 8),
          publicKeyLength: publicKey.length,
          publicKeyLooksValid: publicKey.startsWith("pk-"),
          hasSecretKey: Boolean(secretKey),
          secretKeyLooksValid: secretKey.startsWith("sk-"),
          siteUrl,
          successUrl,
          failureUrl,
          cancelUrl
        }
      });
    }

    const checkoutUrl =
      mayaData?.redirectUrl ||
      mayaData?.checkoutUrl ||
      mayaData?.paymentUrl ||
      mayaData?.url;

    if (!checkoutUrl) {
      return res.status(502).json({
        error: "Maya checkout created but no redirect URL was returned.",
        debug: {
          responseKeys: Object.keys(mayaData || {}),
          env: mayaEnv,
          endpoint: mayaEndpoint
        }
      });
    }

    return res.status(200).json({
      checkoutUrl,
      checkoutId: mayaData?.checkoutId || mayaData?.id || null,
      requestReferenceNumber
    });
  } catch (error) {
    console.error("Create Maya Checkout error:", error);
    return res.status(500).json({
      error: "Maya checkout failed",
      details: error?.message || "Unexpected server error."
    });
  }
}
