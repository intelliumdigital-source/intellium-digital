export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  try {
    const event = req.body || {};
    const payload = typeof event === "string" ? JSON.parse(event) : event;
    const details = {
      id: payload.id || payload.checkoutId || null,
      paymentStatus: payload.paymentStatus || payload.payment_status || null,
      status: payload.status || null,
      requestReferenceNumber: payload.requestReferenceNumber || payload.request_reference_number || null,
      amount: payload.amount || payload.totalAmount?.value || payload.total_amount?.value || null
    };

    console.log("Maya webhook received", JSON.stringify(details));

    // Real project or order status changes should only happen after proper
    // webhook verification and any required signature or source validation.
    // Do not mark projects as paid from frontend redirects or button clicks.
    return res.status(200).json({ received: true, ...details });
  } catch (error) {
    console.error("Maya webhook error:", error);
    return res.status(500).json({
      error: "Webhook handler failed.",
      details: error && error.message ? error.message : String(error)
    });
  }
}
