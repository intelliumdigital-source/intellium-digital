export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  try {
    console.log("Xendit webhook event:", JSON.stringify(req.body || {}));
    return res.status(200).json({ received: true });
  } catch (error) {
    console.error("Xendit webhook error:", error);
    return res.status(500).json({ error: "Webhook handler failed." });
  }
}
