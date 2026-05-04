import clsx from "clsx";
import Link from "next/link";
import {
  ArrowRight,
  Ban,
  BriefcaseBusiness,
  Building2,
  CircleAlert,
  Globe,
  MapPin,
  MessageSquareText,
  Share2,
  ThumbsUp,
  UserPlus,
  Users,
} from "lucide-react";

import type { Business, FeedPost, Person, ServiceListing } from "@/app/_data/mock-data";

function formatCompact(value: number) {
  return new Intl.NumberFormat("en", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value);
}

function initials(value: string) {
  return value
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
}

export function BrandLockup({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-3">
      <div className="halo-ring flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br from-cyan/30 via-blue/25 to-purple/35 text-sm font-semibold text-white shadow-[0_0_30px_rgba(91,231,255,0.18)]">
        il
      </div>
      {!compact ? (
        <div>
          <p className="font-heading text-lg font-semibold tracking-[0.18em] text-white uppercase">
            intellinked
          </p>
          <p className="text-xs text-muted">by Intellium Digital</p>
        </div>
      ) : null}
    </div>
  );
}

export function Surface({
  className,
  children,
}: Readonly<{
  className?: string;
  children: React.ReactNode;
}>) {
  return (
    <div className={clsx("premium-card relative rounded-[28px] p-5 sm:p-6", className)}>
      {children}
    </div>
  );
}

export function PageIntro({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow: string;
  title: string;
  description: string;
  actions?: React.ReactNode;
}) {
  return (
    <Surface className="overflow-hidden">
      <div className="premium-grid absolute inset-0 opacity-40" />
      <div className="relative flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
        <div className="max-w-2xl">
          <p className="mb-3 text-xs font-semibold tracking-[0.24em] text-cyan uppercase">
            {eyebrow}
          </p>
          <h1 className="font-heading text-3xl font-semibold tracking-tight text-white sm:text-4xl">
            {title}
          </h1>
          <p className="mt-3 max-w-2xl text-sm leading-7 text-muted sm:text-base">
            {description}
          </p>
        </div>
        {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
      </div>
    </Surface>
  );
}

export function Pill({
  children,
  active = false,
}: Readonly<{
  children: React.ReactNode;
  active?: boolean;
}>) {
  return (
    <span
      className={clsx(
        "inline-flex items-center rounded-full border px-3 py-1 text-xs font-medium",
        active
          ? "border-cyan/40 bg-cyan/12 text-cyan"
          : "border-border bg-white/4 text-muted-strong",
      )}
    >
      {children}
    </span>
  );
}

export function PrimaryLink({
  href,
  children,
}: Readonly<{
  href: string;
  children: React.ReactNode;
}>) {
  return (
    <Link
      href={href}
      className="inline-flex items-center justify-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-semibold text-cyan hover:bg-cyan/18"
    >
      {children}
    </Link>
  );
}

export function GhostLink({
  href,
  children,
}: Readonly<{
  href: string;
  children: React.ReactNode;
}>) {
  return (
    <Link
      href={href}
      className="inline-flex items-center justify-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm font-medium text-muted-strong hover:border-cyan/25 hover:text-white"
    >
      {children}
    </Link>
  );
}

export function StatCard({
  label,
  value,
  note,
}: {
  label: string;
  value: string;
  note?: string;
}) {
  return (
    <div className="premium-card-soft rounded-3xl p-5">
      <p className="text-xs font-medium uppercase tracking-[0.18em] text-muted">
        {label}
      </p>
      <p className="mt-3 font-heading text-3xl font-semibold text-white">{value}</p>
      {note ? <p className="mt-2 text-sm text-muted">{note}</p> : null}
    </div>
  );
}

export function PostCard({ post }: { post: FeedPost }) {
  const href =
    post.authorType === "Business" && post.businessSlug
      ? `/businesses/${post.businessSlug}`
      : post.authorSlug
        ? `/people/${post.authorSlug}`
        : "/profile";

  return (
    <Surface className="flex flex-col gap-5">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-cyan/20 via-blue/20 to-purple/25 font-semibold text-white">
            {initials(post.authorName)}
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <Link href={href} className="font-semibold text-white hover:text-cyan">
                {post.authorName}
              </Link>
              <Pill>{post.authorType}</Pill>
              <Pill>{post.category}</Pill>
            </div>
            <p className="mt-2 text-sm text-muted">
              {post.businessName ? `${post.businessName} • ` : ""}
              {post.timestamp}
            </p>
          </div>
        </div>
        <div className="hidden gap-2 sm:flex">
          <button className="rounded-full border border-border bg-white/4 px-3 py-2 text-xs text-muted-strong hover:text-white">
            Report
          </button>
          <button className="rounded-full border border-border bg-white/4 px-3 py-2 text-xs text-muted-strong hover:text-white">
            Block
          </button>
        </div>
      </div>

      <p className="text-sm leading-7 text-muted-strong sm:text-[15px]">{post.content}</p>

      <div className="flex flex-wrap gap-3 text-sm text-muted">
        <span className="inline-flex items-center gap-2">
          <ThumbsUp className="h-4 w-4 text-cyan" />
          {formatCompact(post.likes)}
        </span>
        <span className="inline-flex items-center gap-2">
          <MessageSquareText className="h-4 w-4 text-blue" />
          {formatCompact(post.comments)}
        </span>
        <span className="inline-flex items-center gap-2">
          <Share2 className="h-4 w-4 text-purple" />
          {formatCompact(post.shares)}
        </span>
      </div>

      <div className="flex flex-wrap gap-2">
        <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
          <ThumbsUp className="h-4 w-4" />
          Like
        </button>
        <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
          <MessageSquareText className="h-4 w-4" />
          Comment
        </button>
        <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
          <Share2 className="h-4 w-4" />
          Share
        </button>
        <Link
          href={href}
          className="ml-auto inline-flex items-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-semibold text-cyan hover:bg-cyan/18"
        >
          {post.cta}
          <ArrowRight className="h-4 w-4" />
        </Link>
      </div>
    </Surface>
  );
}

export function ProfileCard({ person }: { person: Person }) {
  return (
    <Surface className="flex h-full flex-col gap-4">
      <div className="flex items-start gap-4">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-cyan/18 via-blue/18 to-purple/25 font-semibold text-white">
          {initials(person.fullName)}
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/people/${person.slug}`}
              className="font-heading text-lg font-semibold text-white hover:text-cyan"
            >
              {person.fullName}
            </Link>
            <Pill>{person.authorType}</Pill>
          </div>
          <p className="mt-1 text-sm text-muted-strong">{person.role}</p>
          <p className="mt-2 inline-flex items-center gap-2 text-sm text-muted">
            <MapPin className="h-4 w-4 text-cyan" />
            {person.location}
          </p>
        </div>
      </div>
      <p className="text-sm leading-7 text-muted-strong">{person.bio}</p>
      <div className="flex flex-wrap gap-2">
        {person.skills.map((skill) => (
          <Pill key={skill}>{skill}</Pill>
        ))}
      </div>
      <div className="grid grid-cols-3 gap-3 text-center">
        <div className="premium-card-soft rounded-2xl p-3">
          <p className="text-xs text-muted">Followers</p>
          <p className="mt-1 font-semibold text-white">
            {formatCompact(person.stats.followers)}
          </p>
        </div>
        <div className="premium-card-soft rounded-2xl p-3">
          <p className="text-xs text-muted">Connects</p>
          <p className="mt-1 font-semibold text-white">
            {formatCompact(person.stats.connections)}
          </p>
        </div>
        <div className="premium-card-soft rounded-2xl p-3">
          <p className="text-xs text-muted">Wins</p>
          <p className="mt-1 font-semibold text-white">
            {formatCompact(person.stats.opportunities)}
          </p>
        </div>
      </div>
      <div className="mt-auto flex flex-wrap gap-2">
        <GhostLink href={`/people/${person.slug}`}>Contact</GhostLink>
        <PrimaryLink href={`/people/${person.slug}`}>
          <UserPlus className="h-4 w-4" />
          Connect
        </PrimaryLink>
      </div>
    </Surface>
  );
}

export function BusinessCard({ business }: { business: Business }) {
  return (
    <Surface className="flex h-full flex-col gap-4">
      <div className="flex items-start gap-4">
        <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-purple/25 via-blue/20 to-cyan/20 text-white">
          <Building2 className="h-6 w-6" />
        </div>
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/businesses/${business.slug}`}
              className="font-heading text-lg font-semibold text-white hover:text-cyan"
            >
              {business.businessName}
            </Link>
            <Pill>{business.category}</Pill>
          </div>
          <p className="mt-2 inline-flex items-center gap-2 text-sm text-muted">
            <MapPin className="h-4 w-4 text-cyan" />
            {business.location}
          </p>
        </div>
      </div>
      <p className="text-sm leading-7 text-muted-strong">{business.description}</p>
      <div className="flex flex-wrap gap-2">
        {business.servicesOffered.map((service) => (
          <Pill key={service}>{service}</Pill>
        ))}
      </div>
      <div className="grid grid-cols-3 gap-3 text-center">
        <div className="premium-card-soft rounded-2xl p-3">
          <p className="text-xs text-muted">Followers</p>
          <p className="mt-1 font-semibold text-white">
            {formatCompact(business.stats.followers)}
          </p>
        </div>
        <div className="premium-card-soft rounded-2xl p-3">
          <p className="text-xs text-muted">Leads</p>
          <p className="mt-1 font-semibold text-white">
            {formatCompact(business.stats.leads)}
          </p>
        </div>
        <div className="premium-card-soft rounded-2xl p-3">
          <p className="text-xs text-muted">Response</p>
          <p className="mt-1 font-semibold text-white">{business.stats.responseRate}</p>
        </div>
      </div>
      <div className="mt-auto flex flex-wrap gap-2">
        <GhostLink href={`/businesses/${business.slug}`}>
          <Globe className="h-4 w-4" />
          Profile
        </GhostLink>
        <PrimaryLink href={`/businesses/${business.slug}`}>
          <BriefcaseBusiness className="h-4 w-4" />
          View Service
        </PrimaryLink>
      </div>
    </Surface>
  );
}

export function ServiceCard({ service }: { service: ServiceListing }) {
  const href = service.businessSlug
    ? `/businesses/${service.businessSlug}`
    : service.providerSlug
      ? `/people/${service.providerSlug}`
      : "/services";

  return (
    <Surface className="flex h-full flex-col gap-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="flex flex-wrap items-center gap-2">
            <Pill active>{service.category}</Pill>
            <Pill>{service.location}</Pill>
          </div>
          <h3 className="mt-3 font-heading text-xl font-semibold text-white">
            {service.title}
          </h3>
          <p className="mt-2 text-sm text-muted">
            {service.providerName}
            {service.businessName ? ` • ${service.businessName}` : ""}
          </p>
        </div>
        <div className="rounded-2xl border border-cyan/20 bg-cyan/10 px-3 py-2 text-sm font-semibold text-cyan">
          {service.price}
        </div>
      </div>
      <p className="text-sm leading-7 text-muted-strong">{service.summary}</p>
      <div className="flex flex-wrap gap-2">
        {service.tags.map((tag) => (
          <Pill key={tag}>{tag}</Pill>
        ))}
      </div>
      <div className="mt-auto flex flex-wrap gap-2">
        <GhostLink href={href}>Message</GhostLink>
        <PrimaryLink href={href}>View Service</PrimaryLink>
      </div>
    </Surface>
  );
}

export function EmptyState({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <Surface className="text-center">
      <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-cyan">
        <CircleAlert className="h-6 w-6" />
      </div>
      <h3 className="mt-4 font-heading text-xl font-semibold text-white">{title}</h3>
      <p className="mt-3 text-sm leading-7 text-muted">{description}</p>
    </Surface>
  );
}

export function ModerationActions() {
  return (
    <div className="flex flex-wrap gap-2">
      <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
        <CircleAlert className="h-4 w-4" />
        Report user
      </button>
      <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
        <Ban className="h-4 w-4" />
        Block user
      </button>
    </div>
  );
}

export function SmallList({
  title,
  items,
}: {
  title: string;
  items: string[];
}) {
  return (
    <Surface>
      <h3 className="font-heading text-lg font-semibold text-white">{title}</h3>
      <div className="mt-4 space-y-3">
        {items.map((item) => (
          <div
            key={item}
            className="premium-card-soft flex items-start gap-3 rounded-2xl p-4 text-sm text-muted-strong"
          >
            <Users className="mt-0.5 h-4 w-4 shrink-0 text-cyan" />
            <span>{item}</span>
          </div>
        ))}
      </div>
    </Surface>
  );
}
