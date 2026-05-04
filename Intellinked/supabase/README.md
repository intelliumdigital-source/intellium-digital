# Supabase Setup for intellinked

Follow these steps in order. You only need your Supabase project URL and the public anon key.

## 1. Create or open your Supabase project

1. Go to the Supabase dashboard.
2. Create a new project, or open your existing project for `intellinked`.
3. Wait until the project is fully ready.

## 2. Copy your project URL and anon key

1. In Supabase, open `Project Settings`.
2. Open the `API` section.
3. Copy:
   - `Project URL`
   - `anon public` key

Only use the public anon key here. Do not use the service role key in this app.

## 3. Paste them into `.env.local`

1. Open `.env.local` in this project.
2. Paste your values:

```bash
NEXT_PUBLIC_SUPABASE_URL=your-project-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

3. Save the file.

## 4. Run the database schema

1. In Supabase, open `SQL Editor`.
2. Open [schema.sql](/C:/Users/mendo/Desktop/My%20Projects/Intellinked/supabase/schema.sql).
3. Copy the full contents of `supabase/schema.sql`.
4. Paste it into the Supabase SQL Editor.
5. Click `Run`.

This creates the tables, indexes, triggers, and Row Level Security policies used by the project.

## 5. Enable Email Auth

1. In Supabase, open `Authentication`.
2. Open `Providers`.
3. Make sure `Email` is enabled.

If you want faster local testing, you can turn off email confirmation in the Auth settings.

## 6. Start the app

Run:

```bash
npm run dev
```

Then open `http://localhost:3000`.

## 7. Test register and login

1. Open `http://localhost:3000/auth`.
2. Create a new account.
3. If Supabase says to check your email, confirmation is turned on.
4. If email confirmation is off, you can sign in right away.
5. After login, you should be able to access `/home`.

## 8. Confirm the profile row was created

The schema includes a `handle_new_user` trigger. It should create a `profiles` row automatically for every new auth user.

To check it:

1. In Supabase, open `Table Editor`.
2. Open the `profiles` table.
3. Find the row for the account you just created.
4. The `id` in `profiles` should match the user ID from `auth.users`.

## 9. Run the local verification script

After your env values are set and the schema has been applied, run:

```bash
npm run supabase:verify
```

This checks:

- env values are present
- Supabase is reachable
- `profiles`
- `business_profiles`
- `posts`
- `services`

## Troubleshooting

- If registration says to check your email, email confirmation is on in Supabase Auth.
- If you want instant testing, turn off email confirmation in Supabase Auth settings.
- If `/home` keeps redirecting back to `/auth`, check `.env.local`, then stop and restart `npm run dev`.
