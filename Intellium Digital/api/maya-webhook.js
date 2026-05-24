const PROD_MAYA_CHECKOUT_URL = "https://pg.maya.ph/checkout/v1/checkouts";
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

function getMayaConfig() {
  const secretKey = process.env.MAYA_SECRET_KEY;
  if (!secretKey) {
    throw new Error("MAYA_SECRET_KEY is missing in Vercel Environment Variables.");
  }

  const mode = String(process.env.MAYA_ENV || "sandbox").toLowerCase() === "production"
    ? "production"
    : "sandbox";

  return {
    secretKey,
    checkoutUrl: mode === "production"
      ? PROD_MAYA_CHECKOUT_URL
      : SANDBOX_MAYA_CHECKOUT_URL
  };
}

function extractCheckoutId(payload) {
  return payload?.id
    || payload?.checkoutId
    || payload?.resourceId
    || payload?.data?.id
    || payload?.data?.checkoutId
    || null;
}

function extractStatus(payload) {
  return payload?.paymentStatus
    || payload?.payment_status
    || payload?.status
    || payload?.data?.paymentStatus
    || payload?.data?.payment_status
    || payload?.data?.status
    || null;
}

function extractReference(payload) {
  return payload?.requestReferenceNumber
    || payload?.request_reference_number
    || payload?.data?.requestReferenceNumber
    || payload?.data?.request_reference_number
    || null;
}

function isPaidStatus(status) {
  const normalized = String(status || "").trim().toUpperCase();
  return ["PAID", "PAYMENT_SUCCESS", "PAYMENT_SUCCESSFUL", "COMPLETED", "SUCCESS"].includes(normalized);
}

async function verifyCheckoutStatus(checkoutId, config) {
  const auth = Buffer.from(`${config.secretKey}:`).toString("base64");
  const verificationUrl = `${config.checkoutUrl}/${encodeURIComponent(checkoutId)}`;
  const fetchOptions = {
    method: "GET",
    headers: {
      Accept: "application/json",
      Authorization: `Basic ${auth}`
    }
  };

  if (typeof AbortSignal !== "undefined" && typeof AbortSignal.timeout === "function") {
    fetchOptions.signal = AbortSignal.timeout(5000);
  }

  const response = await fetch(verificationUrl, fetchOptions);
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
    throw new Error(data?.message || data?.error || `Status lookup failed with ${response.status}`);
  }

  return {
    checkoutId: data.id || data.checkoutId || checkoutId,
    status: data.paymentStatus || data.payment_status || data.status || null,
    requestReferenceNumber: data.requestReferenceNumber || data.request_reference_number || null,
    amount: data.totalAmount?.value || data.amount || null,
    paid: isPaidStatus(data.paymentStatus || data.payment_status || data.status)
  };
}

export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  try {
    const payload = parseBody(req.body);
    const summary = {
      checkoutId: extractCheckoutId(payload),
      requestReferenceNumber: extractReference(payload),
      status: extractStatus(payload),
      eventType: payload?.event || payload?.eventType || payload?.type || null,
      amount: payload?.amount || payload?.totalAmount?.value || payload?.data?.amount || payload?.data?.totalAmount?.value || null
    };

    console.info("Maya webhook received", JSON.stringify(summary));

    if (summary.checkoutId) {
      try {
        const config = getMayaConfig();
        const verified = await verifyCheckoutStatus(summary.checkoutId, config);

        console.info("Maya webhook verification", JSON.stringify({
          checkoutId: verified.checkoutId,
          requestReferenceNumber: verified.requestReferenceNumber || summary.requestReferenceNumber,
          verifiedStatus: verified.status,
          verifiedPaid: verified.paid,
          amount: verified.amount
        }));
      } catch (verificationError) {
        console.error("Maya webhook verification failed", JSON.stringify({
          checkoutId: summary.checkoutId,
          error: verificationError instanceof Error ? verificationError.message : String(verificationError)
        }));
      }
    }

    return res.status(200).json({ received: true });
  } catch (error) {
    console.error("Maya webhook handler error", error instanceof Error ? error.message : String(error));
    return res.status(200).json({ received: true });
  }
}
