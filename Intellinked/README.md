# intellinked

`intellinked` is a premium local-first social networking MVP by Intellium Digital.

Current status:

- Next.js App Router
- TypeScript
- Tailwind CSS
- Supabase Auth foundation connected
- Workspace UI still uses mock data by design

## Run the app

1. Install dependencies:

```bash
npm install
```

2. Start the local app:

```bash
npm run dev
```

3. Open:

```txt
http://localhost:3000
```

## Set up Supabase

1. Copy `.env.example` to `.env.local`.
2. Add your Supabase values to `.env.local`:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

3. Apply the SQL schema from [supabase/schema.sql](/C:/Users/mendo/Desktop/My%20Projects/Intellinked/supabase/schema.sql).
4. Follow the full beginner guide in [supabase/README.md](/C:/Users/mendo/Desktop/My%20Projects/Intellinked/supabase/README.md).

Do not add a service role key to this app.

## Verify Supabase locally

Run:

```bash
npm run supabase:verify
```

This checks:

- env values are present
- Supabase is reachable
- `profiles` exists
- `business_profiles` exists
- `posts` exists
- `services` exists

## Test auth and protected routes

1. Open `/auth`.
2. Register a new user or sign in with an existing user.
3. After login, open `/home`.
4. Use the logout action in the workspace shell.
5. After logout, try opening `/home` again.
6. Confirm logged-out access to protected routes redirects back to `/auth`.

## Troubleshooting

- If registration says to check your email, Supabase email confirmation is on.
- If you want instant testing, turn off email confirmation in Supabase Auth settings.
- If `/home` redirects back to `/auth`, check `.env.local` and restart `npm run dev`.

## Current behavior

- Feed, explore, services, messages, notifications, and moderation UI still use mock/local data.
- Supabase is currently used for auth and database foundation only.
- RLS stays enabled.
