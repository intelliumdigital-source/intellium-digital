export default async function handler(req, res) {
  res.setHeader("Content-Type", "application/json");

  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Method not allowed. Use POST from the website payment buttons."
    });
  }

  try {
    const secretKey = process.env.XENDIT_SECRET_KEY;

    if (!secretKey) {
      return res.status(500).json({
        error: "XENDIT_SECRET_KEY is missing in Vercel Environment Variables."
      });
    }

    let body = req.body || {};

    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch (parseError) {
        return res.status(400).json({
          error: "Invalid JSON body."
        });
      }
    }

    const packageName = body.packageName;
    const amount = Number(body.amount);

    const allowedPackages = {
      "Project Reservation Fee": 1000,
      "Starter Website Package": 5000,
      "Website + Maya Integration Promo": 18000,
      "Full Digital Business Setup": 25000
    };

    if (
      !packageName ||
      !allowedPackages[packageName] ||
      allowedPackages[packageName] !== amount
    ) {
      return res.status(400).json({
        error: "Invalid package or amount.",
        received: {
          packageName: packageName,
          amount: amount
        }
      });
    }

    const host = req.headers["x-forwarded-host"] || req.headers.host;
    const protocol = req.headers["x-forwarded-proto"] || "https";
    const baseUrl = process.env.SITE_URL || protocol + "://" + host;

    const externalId =
      "intellium-" +
      Date.now() +
      "-" +
      Math.random().toString(36).slice(2, 8);

    const payload = {
      external_id: externalId,
      amount: amount,
      currency: "PHP",
      description: "Intellium Digital - " + packageName,
      invoice_duration: 86400,
      success_redirect_url: baseUrl + "/success.html",
      failure_redirect_url: baseUrl + "/failed.html",
      items: [
        {
          name: packageName,
          quantity: 1,
          price: amount,
          category: "Digital Services"
        }
      ],
      metadata: {
        brand: "Intellium Digital",
        service: packageName
      }
    };

    const auth = Buffer.from(secretKey + ":").toString("base64");

    const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: "Basic " + auth
      },
      body: JSON.stringify(payload)
    });

    const data = await xenditResponse.json();

    if (!xenditResponse.ok) {
      console.error("Xendit API error:", JSON.stringify(data));

      return res.status(xenditResponse.status || 500).json({
        error: data.message || "Xendit rejected the invoice request.",
        xendit_error: data
      });
    }

    return res.status(200).json({
      id: data.id,
      external_id: data.external_id,
      status: data.status,
      invoice_url: data.invoice_url
    });
  } catch (error) {
    console.error("Create Xendit invoice function crashed:", error);

    return res.status(500).json({
      error: "Server error creating checkout link.",
      details: error && error.message ? error.message : String(error)
    });
  }
}
