import Link from "next/link";
import { Lock, Mail } from "lucide-react";
import { Logo } from "@/components/logo";

export default function LoginPage() {
  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-ink px-6 py-10">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top,rgba(61,242,255,0.18),transparent_28%),radial-gradient(circle_at_bottom_right,rgba(134,93,255,0.18),transparent_24%),linear-gradient(180deg,#020611_0%,#060b19_100%)]" />
      <div className="relative grid w-full max-w-6xl gap-8 lg:grid-cols-[1fr_440px]">
        <div className="hidden rounded-[2rem] border border-white/10 bg-white/[0.04] p-10 shadow-glow lg:block">
          <Logo />
          <p className="mt-10 text-sm uppercase tracking-[0.24em] text-cyan">Premium CRM Access</p>
          <h1 className="mt-4 font-[var(--font-display)] text-5xl font-semibold text-white">Manage leads, clients, follow-ups, and revenue in one polished workspace.</h1>
          <p className="mt-6 max-w-xl text-lg leading-8 text-slate-300">
            This login screen is wired for a local-first product demo. Authentication can be connected later without changing the product structure.
          </p>
          <div className="mt-10 grid gap-4 sm:grid-cols-2">
            <div className="rounded-3xl border border-white/10 bg-[#081126] p-5">
              <p className="text-sm text-slate-400">CRM Layout</p>
              <p className="mt-2 text-xl font-semibold text-white">Responsive dashboard shell</p>
            </div>
            <div className="rounded-3xl border border-white/10 bg-[#081126] p-5">
              <p className="text-sm text-slate-400">Data Mode</p>
              <p className="mt-2 text-xl font-semibold text-white">Mock data first</p>
            </div>
          </div>
        </div>

        <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-8 shadow-glow backdrop-blur">
          <Logo />
          <h2 className="mt-8 text-3xl font-semibold text-white">Welcome back</h2>
          <p className="mt-3 text-slate-400">Use this polished entry page as the CRM sign-in screen.</p>

          <form className="mt-8 space-y-4">
            <label className="flex items-center gap-3 rounded-2xl border border-white/10 bg-[#081126] px-4 py-4 text-slate-400">
              <Mail className="h-4 w-4" />
              <input className="w-full bg-transparent text-white outline-none" placeholder="Email address" type="email" />
            </label>
            <label className="flex items-center gap-3 rounded-2xl border border-white/10 bg-[#081126] px-4 py-4 text-slate-400">
              <Lock className="h-4 w-4" />
              <input className="w-full bg-transparent text-white outline-none" placeholder="Password" type="password" />
            </label>
            <button
              className="w-full rounded-2xl bg-gradient-to-r from-cyan via-blue to-violet px-4 py-4 font-semibold text-slate-950"
              type="button"
            >
              Sign in
            </button>
          </form>

          <div className="mt-6 flex items-center justify-between text-sm text-slate-400">
            <span>Demo mode only</span>
            <Link className="text-cyan" href="/dashboard">
              Continue to dashboard
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
