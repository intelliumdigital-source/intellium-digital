export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Method not allowed."
    });
  }

  try {
    const event = req.body || {};

    console.log("Xendit webhook received:", JSON.stringify(event));

    return res.status(200).json({
      received: true,
      status: event.status || null,
      external_id: event.external_id || null,
      amount: event.amount || null
    });
  } catch (error) {
    console.error("Xendit webhook error:", error);

    return res.status(500).json({
      error: "Webhook handler failed.",
      details: error && error.message ? error.message : String(error)
    });
  }
}