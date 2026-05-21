# IntelliLead Outreach Portal

Private lead operations portal for Intellium Digital.

Tagline: `Legitimize. Digitize. Grow.`

## Stack

- Next.js App Router
- React + TypeScript
- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Vercel deployment target

## Features

- Email/password login with Supabase Auth
- Role-based access for `admin` and `researcher`
- Researcher-only lead and commission visibility
- Admin control for lead review, duplicate handling, status updates, commission updates, resources, and announcements
- Outreach kit with copyable scripts
- Duplicate lead warning using business name and business link
- Screenshot/proof upload to private Supabase Storage
- Mobile-responsive dark UI with Intellium Digital styling
- Loading states, empty states, and server-side validation

## Project Structure

```text
.
|-- app
|   |-- (auth)/login
|   |-- (portal)
|   |   |-- admin
|   |   |-- announcements
|   |   |-- commissions
|   |   |-- dashboard
|   |   |-- my-leads
|   |   |-- outreach-kit
|   |   `-- submit-lead
|   |-- api/leads/check-duplicate
|   |-- actions.ts
|   |-- globals.css
|   `-- layout.tsx
|-- components
|   |-- forms
|   |-- layout
|   `-- shared
|-- lib
|   |-- data
|   |-- supabase
|   `-- *.ts helpers
|-- supabase
|   `-- schema.sql
|-- .env.example
`-- package.json
```

## Environment Variables

Set these in `.env.local` for local development and in Vercel project settings for deployment:

```bash
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

No secret keys are hardcoded in the app.
Do not expose a Supabase `service_role` key to the browser or commit it to this repo.
`.gitignore` already excludes `.env.local`.

## Supabase Setup

1. Create a new Supabase project.
2. In Supabase, open the SQL Editor.
3. Run [`supabase/schema.sql`](./supabase/schema.sql).
4. Confirm the following were created:
   - `profiles`
   - `leads`
   - `commissions`
   - `resource_items`
   - `announcements`
   - storage bucket `lead-proofs`
5. In `Project Settings -> API`, copy:
   - `Project URL`
   - `anon public key`
6. Add those values to `.env.local`.
7. Do not add the Supabase service role key to any `NEXT_PUBLIC_` variable.

## Local Development

1. Install dependencies:

```bash
npm install
```

2. Start the app:

```bash
npm run dev
```

3. Open `http://localhost:3000`.

## Admin Login Setup

Supabase Auth handles the login credentials. The app uses the `profiles` table for role checks.

1. In Supabase, create a user in `Authentication -> Users`.
2. Use the same user ID in `profiles`, or let the user log in once so the app auto-creates a `researcher` profile.
3. Promote that profile to admin with SQL:

```sql
update public.profiles
set role = 'admin',
    full_name = 'Portal Admin'
where email = 'admin@yourdomain.com';
```

If the profile does not exist yet, insert it manually:

```sql
insert into public.profiles (id, email, full_name, role)
values ('SUPABASE_AUTH_USER_ID', 'admin@yourdomain.com', 'Portal Admin', 'admin');
```

Important:
- Admin role assignment should be done only through SQL by a trusted operator.
- Researchers cannot safely self-assign roles unless the SQL schema in this repo has been applied.

## Researcher Onboarding

1. Create a Supabase Auth user for the researcher.
2. Let them log in once, or insert a profile row manually.
3. Keep their `role` as `researcher`.
4. If inserting manually, use the exact user ID from `Authentication -> Users`.

## Deployment to Vercel

1. Push this project to GitHub, GitLab, or Bitbucket.
2. Create a new Vercel project and import the repo.
3. Add environment variables in Vercel:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
4. Deploy.
5. After deployment, verify:
   - login works
   - admin routes are restricted
   - researchers only see their own leads and commissions
   - proof uploads work
   - announcements and outreach resources load
6. Confirm the deployment is using HTTPS and that no `service_role` key exists in Vercel environment variables.

## RLS Testing

Use two test users: one `researcher` and one `admin`.

1. Log in as the researcher and submit a lead with a proof file.
2. Confirm the researcher can access only:
   - `/dashboard`
   - `/submit-lead`
   - `/my-leads`
   - `/commissions`
   - `/outreach-kit`
   - `/announcements`
3. Confirm the researcher cannot access:
   - `/admin`
   - `/admin/resources`
4. Confirm the researcher can only see their own:
   - leads
   - commissions
   - proof uploads
5. Log in as admin and confirm the admin can:
   - see all researchers
   - see all leads
   - update lead review and status
   - create and update commissions
   - create and update resources
   - create and update announcements
6. In the browser console as a researcher, verify direct writes fail for:
   - changing `profiles.role` to `admin`
   - updating another researcher's lead
   - creating or updating another researcher's commission

## Commission Structure Included

- Branding client: `PHP 300-PHP 500`
- Starter Website `PHP 5,000`: `PHP 500`
- Business Website `PHP 10,000+`: `PHP 1,000`
- Website + Payment Setup `PHP 18,000`: `PHP 2,000`
- Full Digital Setup `PHP 25,000+`: `PHP 3,000`
- App Development `PHP 35,000+`: `PHP 4,000-PHP 5,000`

## Rules Included

- Do not spam
- Do not argue with business owners
- Do not promise guaranteed sales
- Do not promise guaranteed Maya/PayMongo/payment provider approval
- Do not collect payments
- Do not change pricing without approval
- Do not submit fake leads
- Do not submit duplicate leads
- Screenshot/proof is required
- Commission applies only after the client successfully pays Intellium Digital

## Notes

- The login page intentionally supports email/password sign-in only.
- The daily checklist is stored in browser local storage per user and day.
- Duplicate lead detection uses normalized business name and business link checks before save.
