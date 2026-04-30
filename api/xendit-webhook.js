export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed." });
  }

  console.log("Xendit webhook event:", JSON.stringify(req.body || {}));
  return res.status(200).json({ received: true });
}
