Intellium Digital Xendit Fixed API V3

This version fixes:
- ReferenceError: module is not defined in ES module scope
- SyntaxError: Missing } in template expression

It uses ES module export default and avoids JavaScript template literals.

Required root structure:
index.html
style.css
script.js
success.html
failed.html
package.json
vercel.json
api/
  create-xendit-invoice.js
  xendit-webhook.js
assets/

Vercel Environment Variables:
XENDIT_SECRET_KEY = your xnd_development secret key
SITE_URL = https://www.intelliumdigital.online

After uploading:
1. Commit/push all files, especially api/create-xendit-invoice.js, package.json, and vercel.json.
2. Redeploy on Vercel.
3. Open /api/create-xendit-invoice.
4. Expected result: {"error":"Method not allowed. Use POST from the website payment buttons."}
5. Test Pay ₱1,000.
