export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body) : (req.body || {});
    const eventType = body?.event || body?.eventType || body?.type || "unknown";

    console.info("Maya webhook received", JSON.stringify({
      eventType,
      requestReferenceNumber: body?.requestReferenceNumber || body?.request_reference_number || null,
      checkoutId: body?.id || body?.checkoutId || body?.resourceId || null,
      status: body?.status || body?.paymentStatus || body?.payment_status || null
    }));

    console.info("Maya webhook body", JSON.stringify(body));

    // TODO: Verify webhook authenticity before processing orders.
    // TODO: Persist verified payment events and reconcile them against project records.

    return res.status(200).json({ received: true });
  } catch (error) {
    console.error("Maya webhook error", error instanceof Error ? error.message : String(error));
    return res.status(200).json({ received: true });
  }
}
