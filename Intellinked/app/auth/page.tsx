import Link from "next/link";
import { redirect } from "next/navigation";
import { ShieldCheck, Sparkles, Users } from "lucide-react";

import { AuthShell } from "@/app/auth/auth-shell";
import { BrandLockup, Pill, Surface } from "@/app/_components/ui";
import { getSessionUser } from "@/lib/auth/session";
import { hasSupabaseEnv } from "@/lib/supabase/env";

export const dynamic = "force-dynamic";

export default async function AuthPage() {
  const isConfigured = hasSupabaseEnv();
  const user = isConfigured ? await getSessionUser() : null;

  if (user) {
    redirect("/home");
  }

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[1320px] items-center px-4 py-8 sm:px-6 lg:px-8">
      <div className="grid w-full gap-6 lg:grid-cols-[0.95fr_1.05fr]">
        <Surface className="overflow-hidden">
          <div className="premium-grid absolute inset-0 opacity-40" />
          <div className="relative">
            <Link href="/">
              <BrandLockup />
            </Link>
            <div className="mt-5">
              <Pill active>
                {isConfigured ? "Supabase auth enabled" : "Supabase setup required"}
              </Pill>
            </div>
            <h1 className="mt-6 font-heading text-4xl font-semibold text-white">
              Enter intellinked
            </h1>
            <p className="mt-4 text-sm leading-8 text-muted-strong">
              Auth is now wired for Supabase while the product remains mock-data first for feed, discovery, and services. This foundation is ready for real profiles, posts, and protected workspace data next.
            </p>

            {!isConfigured ? (
              <p className="mt-5 rounded-2xl border border-warning/30 bg-warning/10 px-4 py-3 text-sm text-warning">
                Add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` to your local environment before testing login and registration.
              </p>
            ) : null}

            <div className="mt-8 space-y-4">
              <div className="premium-card-soft rounded-3xl p-5">
                <div className="flex items-center gap-3">
                  <Sparkles className="h-5 w-5 text-cyan" />
                  <p className="font-medium text-white">Protected premium workspace</p>
                </div>
                <p className="mt-3 text-sm leading-7 text-muted">
                  The workspace routes now require a valid Supabase session while preserving the existing premium dark UI.
                </p>
              </div>
              <div className="premium-card-soft rounded-3xl p-5">
                <div className="flex items-center gap-3">
                  <ShieldCheck className="h-5 w-5 text-purple" />
                  <p className="font-medium text-white">Database-ready auth metadata</p>
                </div>
                <p className="mt-3 text-sm leading-7 text-muted">
                  Registration stores account metadata for future profile and business record creation.
                </p>
              </div>
              <div className="premium-card-soft rounded-3xl p-5">
                <div className="flex items-center gap-3">
                  <Users className="h-5 w-5 text-blue" />
                  <p className="font-medium text-white">Mock content stays intact</p>
                </div>
                <p className="mt-3 text-sm leading-7 text-muted">
                  Feed, explore, services, profiles, and moderation remain mock-first until real data integration starts.
                </p>
              </div>
            </div>
          </div>
        </Surface>

        <Surface>
          <AuthShell isConfigured={isConfigured} />
          <p className="mt-5 text-sm leading-7 text-muted">
            Login, registration, logout, and protected routes are live. The next backend step is swapping mock workspace content onto the Supabase schema without redesigning the interface.
          </p>
        </Surface>
      </div>
    </main>
  );
}
