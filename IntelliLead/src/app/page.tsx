import { ArrowRight, BarChart3, CheckCircle2, ChevronRight, Layers3, ShieldCheck, Sparkles, Zap } from "lucide-react";
import { ButtonLink, buttonStyles } from "@/components/button";
import { Logo } from "@/components/logo";
import { dashboardStats, monthlyPerformance } from "@/lib/mock-data";
import { routes } from "@/lib/routes";
import { formatCurrency } from "@/lib/utils";

const features = [
  {
    title: "Track every lead clearly",
    description: "Move inquiries from Facebook, website forms, and referrals into one sales pipeline with clean statuses.",
    icon: Layers3
  },
  {
    title: "Never miss a follow-up",
    description: "Schedule next actions, assign owners, and keep every opportunity moving before it goes cold.",
    icon: Zap
  },
  {
    title: "Sell with confidence",
    description: "Create better quotations, forecast revenue, and manage client relationships from a premium dashboard.",
    icon: ShieldCheck
  }
];

const pricing = [
  { name: "Starter", price: "PHP 1,490", desc: "For solo founders and lean sales teams." },
  { name: "Growth", price: "PHP 3,990", desc: "For growing businesses managing more leads and quotations." },
  { name: "Scale", price: "Custom", desc: "For teams needing deeper CRM workflows and reporting." }
];

export default function LandingPage() {
  return (
    <div className="relative overflow-hidden bg-ink">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(61,242,255,0.18),transparent_25%),radial-gradient(circle_at_80%_10%,rgba(134,93,255,0.2),transparent_20%),linear-gradient(180deg,#020611_0%,#060b19_50%,#020611_100%)]" />
      <div className="absolute inset-0 bg-hero-grid bg-[size:70px_70px] opacity-[0.06]" />

      <header className="relative mx-auto flex max-w-7xl items-center justify-between px-6 py-6 lg:px-10">
        <Logo />
        <nav className="hidden items-center gap-8 text-sm text-slate-300 md:flex">
          <a href="#features">Features</a>
          <a href="#pricing">Pricing</a>
          <a href="#contact">Contact</a>
        </nav>
        <div className="flex items-center gap-3">
          <ButtonLink href={routes.login} variant="secondary">
            Login
          </ButtonLink>
          <ButtonLink href={routes.dashboard}>Open Demo</ButtonLink>
        </div>
      </header>

      <main className="relative">
        <section className="mx-auto grid max-w-7xl gap-12 px-6 pb-24 pt-10 lg:grid-cols-[1.1fr_0.9fr] lg:px-10 lg:pb-28 lg:pt-16">
          <div>
            <div className="inline-flex items-center gap-2 rounded-2xl border border-cyan/20 bg-cyan/10 px-4 py-2 text-sm text-cyan">
              <span className="h-2 w-2 rounded-full bg-cyan shadow-neon" />
              Smart lead tracking for growing businesses.
            </div>
            <h1 className="mt-8 max-w-3xl font-[var(--font-display)] text-5xl font-semibold leading-tight text-white md:text-7xl">
              A premium CRM built for Filipino small businesses ready to grow faster.
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-300">
              IntelliLead by Intellium Digital keeps your leads, clients, follow-ups, quotations, and sales pipeline in one sharp,
              sellable CRM experience.
            </p>
            <div className="mt-10 flex flex-col gap-4 sm:flex-row">
              <ButtonLink className="px-6" href={routes.dashboard}>
                View CRM Demo
                <ArrowRight className="h-4 w-4" />
              </ButtonLink>
              <ButtonLink className="px-6" href={routes.login} variant="secondary">
                Start Selling IntelliLead
                <ChevronRight className="h-4 w-4" />
              </ButtonLink>
            </div>
            <div className="mt-10 grid max-w-2xl gap-4 sm:grid-cols-3">
              <div className="rounded-[28px] border border-white/10 bg-white/5 p-4 backdrop-blur">
                <p className="text-sm text-slate-400">Total Leads</p>
                <p className="mt-2 text-3xl font-semibold text-white">{dashboardStats.totalLeads}</p>
              </div>
              <div className="rounded-[28px] border border-white/10 bg-white/5 p-4 backdrop-blur">
                <p className="text-sm text-slate-400">Won Deals</p>
                <p className="mt-2 text-3xl font-semibold text-white">{dashboardStats.wonDeals}</p>
              </div>
              <div className="rounded-[28px] border border-white/10 bg-white/5 p-4 backdrop-blur">
                <p className="text-sm text-slate-400">Estimated Revenue</p>
                <p className="mt-2 text-3xl font-semibold text-white">{formatCurrency(dashboardStats.estimatedRevenue)}</p>
              </div>
            </div>
          </div>

          <div className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-5 shadow-glow backdrop-blur">
            <div className="rounded-[1.75rem] border border-cyan/20 bg-[#081126] p-5">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm uppercase tracking-[0.24em] text-cyan">Revenue Flow</p>
                  <h2 className="mt-2 font-[var(--font-display)] text-3xl text-white">Pipeline Snapshot</h2>
                </div>
                <div className="rounded-2xl border border-cyan/20 bg-cyan/10 p-3 text-cyan">
                  <BarChart3 className="h-5 w-5" />
                </div>
              </div>
              <div className="mt-6 inline-flex items-center gap-2 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-2 text-sm text-slate-300">
                <Sparkles className="h-4 w-4 text-cyan" />
                Local-first CRM MVP with no live auth or database connection yet
              </div>
              <div className="mt-8 space-y-5">
                {monthlyPerformance.map((item) => (
                  <div key={item.month}>
                    <div className="mb-2 flex items-center justify-between text-sm">
                      <span className="text-slate-300">{item.month}</span>
                      <span className="text-slate-400">{formatCurrency(item.revenue)}</span>
                    </div>
                    <div className="h-3 overflow-hidden rounded-full bg-white/5">
                      <div
                        className="h-full rounded-full bg-gradient-to-r from-cyan via-blue to-violet"
                        style={{ width: `${(item.revenue / 246000) * 100}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-8 grid gap-4 sm:grid-cols-2">
                <div className="rounded-[28px] border border-white/10 bg-white/[0.03] p-4">
                  <p className="text-sm text-slate-400">This Month</p>
                  <p className="mt-2 text-2xl font-semibold text-white">{formatCurrency(232000)}</p>
                </div>
                <div className="rounded-[28px] border border-white/10 bg-white/[0.03] p-4">
                  <p className="text-sm text-slate-400">Average Win Rate</p>
                  <p className="mt-2 text-2xl font-semibold text-white">26%</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-6 py-20 lg:px-10" id="features">
          <div className="max-w-2xl">
            <p className="text-sm uppercase tracking-[0.24em] text-cyan">Why IntelliLead</p>
            <h2 className="mt-4 font-[var(--font-display)] text-4xl text-white">Designed to look premium and work hard for sales teams.</h2>
          </div>
          <div className="mt-10 grid gap-6 lg:grid-cols-3">
            {features.map((feature) => {
              const Icon = feature.icon;
              return (
                <article key={feature.title} className="rounded-[2rem] border border-white/10 bg-white/[0.04] p-6 shadow-glow">
                  <div className="inline-flex rounded-2xl border border-cyan/20 bg-cyan/10 p-3 text-cyan">
                    <Icon className="h-5 w-5" />
                  </div>
                  <h3 className="mt-6 text-2xl font-semibold text-white">{feature.title}</h3>
                  <p className="mt-4 leading-7 text-slate-300">{feature.description}</p>
                </article>
              );
            })}
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-6 py-20 lg:px-10" id="pricing">
          <div className="rounded-[2rem] border border-white/10 bg-gradient-to-br from-white/[0.05] via-cyan/[0.03] to-violet/[0.04] p-8 shadow-glow">
            <div className="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between">
              <div className="max-w-2xl">
                <p className="text-sm uppercase tracking-[0.24em] text-cyan">Pricing Preview</p>
                <h2 className="mt-4 font-[var(--font-display)] text-4xl text-white">Flexible plans for lean teams and scaling businesses.</h2>
              </div>
              <p className="max-w-xl text-slate-300">Use this section as a sellable preview while the product is still running on local mock data.</p>
            </div>
            <div className="mt-10 grid gap-6 lg:grid-cols-3">
              {pricing.map((tier) => (
                <article key={tier.name} className="rounded-[1.75rem] border border-white/10 bg-[#081126] p-6">
                  <p className="text-sm uppercase tracking-[0.2em] text-slate-400">{tier.name}</p>
                  <p className="mt-4 text-4xl font-semibold text-white">{tier.price}</p>
                  <p className="mt-4 leading-7 text-slate-300">{tier.desc}</p>
                  <ul className="mt-6 space-y-3 text-sm text-slate-300">
                    <li className="flex items-center gap-2">
                      <CheckCircle2 className="h-4 w-4 text-cyan" />
                      Lead and client management
                    </li>
                    <li className="flex items-center gap-2">
                      <CheckCircle2 className="h-4 w-4 text-cyan" />
                      Quotations and sales pipeline
                    </li>
                    <li className="flex items-center gap-2">
                      <CheckCircle2 className="h-4 w-4 text-cyan" />
                      Follow-up and reporting views
                    </li>
                  </ul>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-6 pb-24 lg:px-10" id="contact">
          <div className="rounded-[2rem] border border-cyan/20 bg-gradient-to-r from-cyan/10 via-blue/10 to-violet/10 p-8 shadow-neon">
            <p className="text-sm uppercase tracking-[0.24em] text-cyan">Contact CTA</p>
            <h2 className="mt-4 max-w-3xl font-[var(--font-display)] text-4xl text-white">Position IntelliLead as a premium CRM offer for service businesses, agencies, clinics, and local brands.</h2>
            <p className="mt-4 max-w-2xl leading-7 text-slate-300">
              Website: intelliumdigital.online. Facebook: facebook.com/IntelliumDigitalPH.
            </p>
            <div className="mt-8 flex flex-col gap-4 sm:flex-row">
              <a className={buttonStyles("primary")} href="https://intelliumdigital.online" rel="noreferrer" target="_blank">
                Visit Website
              </a>
              <a className={buttonStyles("secondary")} href="https://facebook.com/IntelliumDigitalPH" rel="noreferrer" target="_blank">
                Message on Facebook
              </a>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
