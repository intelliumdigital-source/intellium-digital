Intellium Digital Xendit Final CommonJS Fix

This fixes the Vercel error:
ReferenceError: module is not defined in ES module scope

What changed:
- package.json no longer has "type": "module"
- api/create-xendit-invoice.js uses module.exports
- api/xendit-webhook.js uses module.exports

Upload all files to GitHub/Vercel, especially:
package.json
vercel.json
api/create-xendit-invoice.js
api/xendit-webhook.js

Vercel Environment Variables:
XENDIT_SECRET_KEY = xnd_development_your_secret_key_here
SITE_URL = https://www.intelliumdigital.online

After uploading:
1. Redeploy on Vercel.
2. Open https://www.intelliumdigital.online/api/create-xendit-invoice
3. Expected result:
   {"error":"Method not allowed. Use POST from the website payment buttons."}
4. Test the Pay ₱1,000 button.
