import Link from "next/link";
import { ArrowRight, ShieldCheck, Sparkles } from "lucide-react";

import { BrandLockup, Pill, Surface } from "@/app/_components/ui";

export default function AuthPage() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[1320px] items-center px-4 py-8 sm:px-6 lg:px-8">
      <div className="grid w-full gap-6 lg:grid-cols-[0.95fr_1.05fr]">
        <Surface className="overflow-hidden">
          <div className="premium-grid absolute inset-0 opacity-40" />
          <div className="relative">
            <BrandLockup />
            <Pill active>Local-first demo access</Pill>
            <h1 className="mt-6 font-heading text-4xl font-semibold text-white">
              Enter intellinked
            </h1>
            <p className="mt-4 text-sm leading-8 text-muted-strong">
              This MVP keeps authentication local and presentation-first. The goal is to demonstrate the product experience before wiring real auth and backend services.
            </p>

            <div className="mt-8 space-y-4">
              <div className="premium-card-soft rounded-3xl p-5">
                <div className="flex items-center gap-3">
                  <Sparkles className="h-5 w-5 text-cyan" />
                  <p className="font-medium text-white">Premium dark social UI</p>
                </div>
                <p className="mt-3 text-sm leading-7 text-muted">
                  Feed, discovery, services, profiles, admin review, and responsive navigation are already staged.
                </p>
              </div>
              <div className="premium-card-soft rounded-3xl p-5">
                <div className="flex items-center gap-3">
                  <ShieldCheck className="h-5 w-5 text-purple" />
                  <p className="font-medium text-white">Mock data only</p>
                </div>
                <p className="mt-3 text-sm leading-7 text-muted">
                  No Supabase, no real messaging, and no live moderation persistence yet.
                </p>
              </div>
            </div>
          </div>
        </Surface>

        <Surface>
          <div className="grid gap-4 sm:grid-cols-2">
            <section className="premium-card-soft rounded-[28px] p-5">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
                Login
              </p>
              <div className="mt-5 space-y-4">
                <label className="block text-sm text-muted-strong">
                  Email
                  <input
                    className="mt-2 w-full rounded-2xl border border-border bg-white/4 px-4 py-3 text-white outline-none"
                    placeholder="name@business.ph"
                  />
                </label>
                <label className="block text-sm text-muted-strong">
                  Password
                  <input
                    type="password"
                    className="mt-2 w-full rounded-2xl border border-border bg-white/4 px-4 py-3 text-white outline-none"
                    placeholder="••••••••"
                  />
                </label>
                <Link
                  href="/home"
                  className="inline-flex w-full items-center justify-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-3 text-sm font-semibold text-cyan hover:bg-cyan/18"
                >
                  Continue to home
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            </section>

            <section className="premium-card-soft rounded-[28px] p-5">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-purple">
                Register
              </p>
              <div className="mt-5 space-y-4">
                <label className="block text-sm text-muted-strong">
                  Full name or business
                  <input
                    className="mt-2 w-full rounded-2xl border border-border bg-white/4 px-4 py-3 text-white outline-none"
                    placeholder="Your name or brand"
                  />
                </label>
                <label className="block text-sm text-muted-strong">
                  Role type
                  <select className="mt-2 w-full rounded-2xl border border-border bg-white/4 px-4 py-3 text-white outline-none">
                    <option className="bg-slate-950">Professional</option>
                    <option className="bg-slate-950">Business</option>
                    <option className="bg-slate-950">Freelancer</option>
                    <option className="bg-slate-950">Customer</option>
                  </select>
                </label>
                <Link
                  href="/explore"
                  className="inline-flex w-full items-center justify-center gap-2 rounded-full border border-border bg-white/4 px-4 py-3 text-sm font-medium text-muted-strong hover:text-white"
                >
                  Preview explore page
                </Link>
              </div>
            </section>
          </div>

          <p className="mt-5 text-sm leading-7 text-muted">
            For this MVP, both flows route into the local demo workspace. Real auth and account persistence can be connected later without changing the overall product structure.
          </p>
        </Surface>
      </div>
    </main>
  );
}
