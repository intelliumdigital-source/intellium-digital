import Link from "next/link";
import {
  ArrowRight,
  BellRing,
  BriefcaseBusiness,
  Compass,
  MessageSquareText,
  ShieldCheck,
  Sparkles,
} from "lucide-react";

import {
  BrandLockup,
  BusinessCard,
  EmptyState,
  GhostLink,
  Pill,
  PostCard,
  PrimaryLink,
  ServiceCard,
  StatCard,
  Surface,
} from "@/app/_components/ui";
import {
  businesses,
  categories,
  feedPosts,
  platformStats,
  services,
} from "@/app/_data/mock-data";

export default function LandingPage() {
  return (
    <main className="mx-auto flex w-full max-w-[1440px] flex-col gap-6 px-4 py-5 sm:px-6 lg:px-8">
      <Surface className="overflow-hidden">
        <div className="premium-grid absolute inset-0 opacity-50" />
        <div className="relative">
          <div className="flex flex-col gap-6 border-b border-border/70 pb-8 lg:flex-row lg:items-center lg:justify-between">
            <Link href="/">
              <BrandLockup />
            </Link>
            <div className="flex flex-wrap gap-3">
              <GhostLink href="/auth">Login / Register</GhostLink>
              <PrimaryLink href="/home">Enter MVP</PrimaryLink>
            </div>
          </div>

          <div className="grid gap-10 py-10 lg:grid-cols-[1.05fr_0.95fr] lg:py-14">
            <div>
              <Pill active>Connect. Promote. Grow.</Pill>
              <h1 className="mt-6 max-w-3xl font-heading text-5xl font-semibold tracking-tight text-white sm:text-6xl">
                <span className="text-glow">intellinked</span> brings Filipino founders,
                freelancers, and customers into one premium local-first network.
              </h1>
              <p className="mt-6 max-w-2xl text-base leading-8 text-muted-strong sm:text-lg">
                intellinked by Intellium Digital helps business owners, freelancers,
                professionals, service providers, and customers connect, collaborate, and
                surface real local opportunities without waiting on live backend infrastructure.
              </p>

              <div className="mt-8 flex flex-wrap gap-3">
                <PrimaryLink href="/home">
                  Explore the social MVP
                  <ArrowRight className="h-4 w-4" />
                </PrimaryLink>
                <GhostLink href="/services">
                  <Compass className="h-4 w-4" />
                  Browse services
                </GhostLink>
              </div>

              <div className="mt-8 grid gap-4 sm:grid-cols-3">
                <div className="premium-card-soft rounded-[24px] p-4">
                  <p className="text-xs uppercase tracking-[0.18em] text-cyan">For founders</p>
                  <p className="mt-3 text-sm leading-6 text-muted-strong">
                    Promote offers, source reliable talent, and grow trust faster.
                  </p>
                </div>
                <div className="premium-card-soft rounded-[24px] p-4">
                  <p className="text-xs uppercase tracking-[0.18em] text-blue">
                    For freelancers
                  </p>
                  <p className="mt-3 text-sm leading-6 text-muted-strong">
                    Show proof, package services, and find local business buyers.
                  </p>
                </div>
                <div className="premium-card-soft rounded-[24px] p-4">
                  <p className="text-xs uppercase tracking-[0.18em] text-purple">
                    For customers
                  </p>
                  <p className="mt-3 text-sm leading-6 text-muted-strong">
                    Discover practical providers and compare credible local options.
                  </p>
                </div>
              </div>

              <div className="mt-8 flex flex-wrap gap-3 text-sm text-muted">
                <a
                  href="https://intelliumdigital.online"
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-full border border-border px-4 py-2 hover:text-white"
                >
                  intelliumdigital.online
                </a>
                <a
                  href="https://facebook.com/IntelliumDigitalPH"
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-full border border-border px-4 py-2 hover:text-white"
                >
                  facebook.com/IntelliumDigitalPH
                </a>
              </div>
            </div>

            <div className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                {platformStats.map((stat) => (
                  <StatCard
                    key={stat.label}
                    label={stat.label}
                    value={stat.value}
                    note={stat.note}
                  />
                ))}
              </div>
              <PostCard post={feedPosts[0]} />
              <ServiceCard service={services[0]} />
            </div>
          </div>
        </div>
      </Surface>

      <div className="grid gap-6 lg:grid-cols-3">
        <Surface>
          <div className="flex items-center gap-3 text-cyan">
            <BriefcaseBusiness className="h-5 w-5" />
            <p className="font-heading text-lg font-semibold text-white">Promote offers</p>
          </div>
          <p className="mt-4 text-sm leading-7 text-muted">
            Showcase services, open opportunities, and business updates in a feed that feels premium and conversion-aware.
          </p>
        </Surface>
        <Surface>
          <div className="flex items-center gap-3 text-blue">
            <MessageSquareText className="h-5 w-5" />
            <p className="font-heading text-lg font-semibold text-white">Build connections</p>
          </div>
          <p className="mt-4 text-sm leading-7 text-muted">
            Make it easier for people and businesses to discover one another, connect fast, and start practical conversations.
          </p>
        </Surface>
        <Surface>
          <div className="flex items-center gap-3 text-purple">
            <ShieldCheck className="h-5 w-5" />
            <p className="font-heading text-lg font-semibold text-white">Moderate trust</p>
          </div>
          <p className="mt-4 text-sm leading-7 text-muted">
            Put reporting, blocking, and admin review into the product early so the platform looks sellable and trustworthy from day one.
          </p>
        </Surface>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
        <div className="space-y-6">
          <Surface>
            <div className="flex items-center gap-3">
              <Sparkles className="h-5 w-5 text-cyan" />
              <h2 className="font-heading text-2xl font-semibold text-white">
                Built for real local use cases
              </h2>
            </div>
            <div className="mt-6 flex flex-wrap gap-2">
              {categories.map((category) => (
                <Pill key={category}>{category}</Pill>
              ))}
            </div>
          </Surface>

          <div className="grid gap-4 lg:grid-cols-2">
            <BusinessCard business={businesses[0]} />
            <ServiceCard service={services[1]} />
          </div>
        </div>

        <Surface>
          <h2 className="font-heading text-2xl font-semibold text-white">
            Why this MVP sells the idea
          </h2>
          <div className="mt-6 space-y-4">
            <div className="premium-card-soft rounded-3xl p-5">
              <div className="flex items-center gap-3 text-cyan">
                <BellRing className="h-5 w-5" />
                <p className="font-medium text-white">Social feed with business intent</p>
              </div>
              <p className="mt-3 text-sm leading-7 text-muted">
                Every post supports discoverability, trust signals, and a next action such as connect, message, or view service.
              </p>
            </div>
            <div className="premium-card-soft rounded-3xl p-5">
              <div className="flex items-center gap-3 text-blue">
                <Compass className="h-5 w-5" />
                <p className="font-medium text-white">Explore and services flow</p>
              </div>
              <p className="mt-3 text-sm leading-7 text-muted">
                Search and category filters make the local-first offer easy to understand, even before live data exists.
              </p>
            </div>
            <div className="premium-card-soft rounded-3xl p-5">
              <div className="flex items-center gap-3 text-purple">
                <ShieldCheck className="h-5 w-5" />
                <p className="font-medium text-white">Moderation included now</p>
              </div>
              <p className="mt-3 text-sm leading-7 text-muted">
                The admin review layer demonstrates governance early, which matters for community platforms pitched to serious operators.
              </p>
            </div>
          </div>
        </Surface>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <EmptyState
          eyebrow="Integration ready"
          title="Built to plug into auth and database next"
          description="The route structure, page surfaces, and entity shapes are already aligned for real login, profiles, posts, and directory data later."
          action={<PrimaryLink href="/auth">Preview auth flow</PrimaryLink>}
        />
        <Surface>
          <h2 className="font-heading text-2xl font-semibold text-white">
            What this MVP already proves
          </h2>
          <div className="mt-5 space-y-3">
            <div className="premium-card-soft rounded-[24px] p-4 text-sm leading-7 text-muted-strong">
              Realistic people, businesses, services, and moderation scenarios tailored to Filipino local commerce.
            </div>
            <div className="premium-card-soft rounded-[24px] p-4 text-sm leading-7 text-muted-strong">
              Consistent navigation across feed, discovery, profiles, services, and admin review.
            </div>
            <div className="premium-card-soft rounded-[24px] p-4 text-sm leading-7 text-muted-strong">
              Premium dark presentation that is easier to pitch before live backend work begins.
            </div>
          </div>
        </Surface>
      </div>

      <Surface className="text-center">
        <h2 className="font-heading text-3xl font-semibold text-white">
          Ready to step into the intellinked demo?
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-sm leading-7 text-muted">
          The workspace is built with mock data only, responsive first, and shaped to feel like a premium social SaaS you can already present.
        </p>
        <div className="mt-6 flex flex-wrap justify-center gap-3">
          <Link
            href="/auth"
            className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-5 py-3 text-sm font-medium text-muted-strong hover:text-white"
          >
            Login / Register
          </Link>
          <Link
            href="/home"
            className="inline-flex items-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:bg-cyan/18 hover:text-white"
          >
            Launch MVP
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </Surface>
    </main>
  );
}
