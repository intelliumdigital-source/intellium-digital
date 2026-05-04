import clsx from "clsx";
import Link from "next/link";
import {
  ArrowRight,
  ArrowUpRight,
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

import type {
  Business,
  FeedPost,
  Person,
  ServiceListing,
} from "@/app/_data/mock-data";

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
    <div
      className={clsx(
        "premium-card premium-card-glow relative rounded-[28px] p-5 sm:p-6",
        className,
      )}
    >
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
          <p className="mb-3 text-xs font-semibold uppercase tracking-[0.24em] text-cyan">
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
        "inline-flex items-center whitespace-nowrap rounded-full border px-3 py-1 text-xs font-medium",
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
      className="inline-flex min-h-11 items-center justify-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-semibold text-cyan hover:-translate-y-0.5 hover:bg-cyan/18 hover:text-white"
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
      className="inline-flex min-h-11 items-center justify-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm font-medium text-muted-strong hover:-translate-y-0.5 hover:border-cyan/25 hover:text-white"
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
      {note ? <p className="mt-2 text-sm leading-6 text-muted">{note}</p> : null}
    </div>
  );
}

export function PostCard({ post }: { post: FeedPost }) {
  const profileHref =
    post.authorType === "Business" && post.businessSlug
      ? `/businesses/${post.businessSlug}`
      : post.authorSlug
        ? `/people/${post.authorSlug}`
        : "/profile";
  const messageHref =
    post.authorType === "Business" && post.businessSlug
      ? `/messages?with=${post.businessSlug}`
      : post.authorSlug
        ? `/messages?with=${post.authorSlug}`
        : "/messages";
  const serviceHref =
    post.businessName || post.authorName
      ? `/services?q=${encodeURIComponent(post.businessName ?? post.authorName)}`
      : "/services";
  const ctaHref =
    post.cta === "Message"
      ? messageHref
      : post.cta === "View Service"
        ? serviceHref
        : profileHref;

  return (
    <Surface className="flex flex-col gap-5">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-cyan/20 via-blue/20 to-purple/25 font-semibold text-white">
            {initials(post.authorName)}
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <Link href={profileHref} className="font-semibold text-white hover:text-cyan">
                {post.authorName}
              </Link>
              <Pill>{post.authorType}</Pill>
              <Pill>{post.category}</Pill>
            </div>
            <p className="mt-2 text-sm text-muted">
              {post.businessName ? `${post.businessName} | ` : ""}
              {post.timestamp}
            </p>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
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
          href={ctaHref}
          className="ml-auto inline-flex min-h-11 items-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-semibold text-cyan hover:-translate-y-0.5 hover:bg-cyan/18 hover:text-white"
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
            <Pill>{person.focusCategory}</Pill>
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
        <GhostLink href={`/messages?with=${person.slug}`}>Contact</GhostLink>
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
        <GhostLink href={`/messages?with=${business.slug}`}>
          <Globe className="h-4 w-4" />
          Contact
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
  const profileHref = service.businessSlug
    ? `/businesses/${service.businessSlug}`
    : service.providerSlug
      ? `/people/${service.providerSlug}`
      : "/services";
  const messageHref = service.businessSlug
    ? `/messages?with=${service.businessSlug}`
    : service.providerSlug
      ? `/messages?with=${service.providerSlug}`
      : "/messages";

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
            {service.businessName ? ` | ${service.businessName}` : ""}
          </p>
        </div>
        <div className="shrink-0 rounded-2xl border border-cyan/20 bg-cyan/10 px-3 py-2 text-right text-sm font-semibold text-cyan">
          <p>{service.price}</p>
          <p className="mt-1 text-xs font-medium text-muted">{service.availability}</p>
        </div>
      </div>
      <p className="text-sm leading-7 text-muted-strong">{service.summary}</p>
      <div className="flex flex-wrap gap-2">
        {service.tags.map((tag) => (
          <Pill key={tag}>{tag}</Pill>
        ))}
      </div>
      <div className="mt-auto flex flex-wrap gap-2">
        <GhostLink href={messageHref}>Message</GhostLink>
        <PrimaryLink href={profileHref}>View Service</PrimaryLink>
      </div>
    </Surface>
  );
}

export function EmptyState({
  eyebrow,
  title,
  description,
  action,
}: {
  eyebrow?: string;
  title: string;
  description: string;
  action?: React.ReactNode;
}) {
  return (
    <Surface className="overflow-hidden text-center">
      <div className="premium-grid absolute inset-0 opacity-35" />
      <div className="relative">
        {eyebrow ? (
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-cyan">
            {eyebrow}
          </p>
        ) : null}
        <div className="mx-auto mt-1 flex h-14 w-14 items-center justify-center rounded-2xl bg-white/5 text-cyan">
          <CircleAlert className="h-6 w-6" />
        </div>
        <h3 className="mt-4 font-heading text-xl font-semibold text-white">{title}</h3>
        <p className="mt-3 text-sm leading-7 text-muted">{description}</p>
        {action ? <div className="mt-5 flex justify-center">{action}</div> : null}
      </div>
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

export function LoadingPanel({
  title = "Loading preview",
}: {
  title?: string;
}) {
  return (
    <Surface>
      <p className="font-heading text-lg font-semibold text-white">{title}</p>
      <div className="mt-5 space-y-3">
        <div className="skeleton-bar h-4 w-3/5 rounded-full" />
        <div className="skeleton-bar h-4 w-full rounded-full" />
        <div className="skeleton-bar h-4 w-5/6 rounded-full" />
        <div className="skeleton-bar h-24 w-full rounded-[24px]" />
      </div>
    </Surface>
  );
}

export function ExternalTextLink({
  href,
  children,
}: Readonly<{
  href: string;
  children: React.ReactNode;
}>) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="inline-flex items-center gap-2 text-cyan hover:text-white"
    >
      {children}
      <ArrowUpRight className="h-4 w-4" />
    </a>
  );
}
