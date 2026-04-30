Intellium Digital Xendit Fixed API Version

This version includes the missing Vercel API folder.

Required root structure:
index.html
style.css
script.js
success.html
failed.html
package.json
api/
  create-xendit-invoice.js
  xendit-webhook.js
assets/

Vercel Environment Variables:
XENDIT_SECRET_KEY = your xnd_development secret key
SITE_URL = https://www.intelliumdigital.online

After uploading:
1. Commit/push all files, including the api folder.
2. Redeploy on Vercel.
3. Visit /api/create-xendit-invoice.
4. If it says Method not allowed, the API route is working.
5. Test Pay ₱1,000.
