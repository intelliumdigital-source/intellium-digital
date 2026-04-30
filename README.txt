Intellium Digital Website - Premium V4

Included:
- index.html
- style.css
- script.js
- assets folder

Premium V4 updates:
- More premium SaaS-style UI
- Stronger hero section and visual dashboard
- SweldoTrack featured app section
- Updated chatbot with SweldoTrack option
- Improved glassmorphism cards, hover effects, spacing, typography, and scroll reveal animation
- Uses your uploaded Intellium Digital assets and SweldoTrack logo

How to deploy:
1. Extract this ZIP.
2. Upload index.html, style.css, script.js, and the assets folder to your GitHub repository root.
3. Deploy or redeploy on Vercel.
4. Hard refresh the browser with CTRL + SHIFT + R.


Xendit integration added:
- Pay Online section on the website
- Vercel serverless endpoint: /api/create-xendit-invoice
- Xendit hosted checkout redirect
- Success page: success.html
- Failed page: failed.html
- Webhook starter endpoint: /api/xendit-webhook
- package.json and .env.example

Vercel setup:
1. Upload/extract this project to GitHub.
2. Deploy to Vercel.
3. In Vercel Project Settings > Environment Variables, add:
   XENDIT_SECRET_KEY = your Xendit secret key
   SITE_URL = https://your-live-domain.com
4. Redeploy.
5. Test using your Xendit test key first.
6. Only switch to live key after testing.

Important:
Never place your Xendit secret key inside index.html or script.js.
