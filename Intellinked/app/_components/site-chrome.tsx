"use client";

import clsx from "clsx";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Bell,
  Compass,
  Home,
  MessageSquare,
  PlusSquare,
  Search,
  Settings,
  ShieldCheck,
  UserCircle2,
} from "lucide-react";

import { BrandLockup, Pill, Surface } from "@/app/_components/ui";
import { categories, communityPulse } from "@/app/_data/mock-data";

const navItems = [
  { href: "/home", label: "Home", icon: Home },
  { href: "/explore", label: "Explore", icon: Compass },
  { href: "/create", label: "Create", icon: PlusSquare },
  { href: "/services", label: "Services", icon: Search },
  { href: "/messages", label: "Messages", icon: MessageSquare },
  { href: "/notifications", label: "Notifications", icon: Bell },
  { href: "/profile", label: "Profile", icon: UserCircle2 },
  { href: "/settings", label: "Settings", icon: Settings },
  { href: "/admin", label: "Admin", icon: ShieldCheck },
];

function getPageLabel(pathname: string) {
  const match = navItems.find((item) => item.href === pathname);
  if (match) {
    return match.label;
  }

  if (pathname.startsWith("/people/")) {
    return "Professional Profile";
  }

  if (pathname.startsWith("/businesses/")) {
    return "Business Profile";
  }

  return "intellinked";
}

export function SiteChrome({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const pathname = usePathname();
  const pageLabel = getPageLabel(pathname);

  return (
    <div className="min-h-screen">
      <div className="mx-auto flex w-full max-w-[1600px] gap-6 px-4 pb-24 pt-5 sm:px-6 lg:px-8">
        <aside className="hidden w-72 shrink-0 flex-col gap-4 lg:flex">
          <Surface className="sticky top-5">
            <BrandLockup />
            <p className="mt-4 text-sm leading-7 text-muted">
              Connect. Promote. Grow. A local-first network built for Filipino business communities.
            </p>
            <div className="mt-6 space-y-2">
              {navItems.map((item) => {
                const isActive =
                  pathname === item.href ||
                  (item.href !== "/home" && pathname.startsWith(`${item.href}/`));

                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={clsx(
                      "flex items-center justify-between rounded-2xl border px-4 py-3 text-sm",
                      isActive
                        ? "border-cyan/30 bg-cyan/12 text-white"
                        : "border-border bg-white/4 text-muted-strong hover:text-white",
                    )}
                  >
                    <span className="flex items-center gap-3">
                      <item.icon className="h-4 w-4" />
                      {item.label}
                    </span>
                    {isActive ? <span className="h-2 w-2 rounded-full bg-cyan" /> : null}
                  </Link>
                );
              })}
            </div>
          </Surface>
        </aside>

        <div className="min-w-0 flex-1">
          <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-cyan">
                {pageLabel}
              </p>
              <h2 className="mt-2 font-heading text-2xl font-semibold text-white">
                Premium local-first social networking MVP
              </h2>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <div className="flex min-w-[210px] items-center gap-3 rounded-full border border-border bg-white/4 px-4 py-3 text-sm text-muted">
                <Search className="h-4 w-4 text-cyan" />
                Search users, businesses, or services
              </div>
              <Pill active>Mock data mode</Pill>
            </div>
          </div>

          {children}
        </div>

        <aside className="hidden w-80 shrink-0 flex-col gap-4 xl:flex">
          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">Community pulse</h3>
            <div className="mt-4 space-y-3">
              {communityPulse.map((item) => (
                <div
                  key={item}
                  className="premium-card-soft rounded-2xl p-4 text-sm leading-6 text-muted-strong"
                >
                  {item}
                </div>
              ))}
            </div>
          </Surface>

          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">Top categories</h3>
            <div className="mt-4 flex flex-wrap gap-2">
              {categories.slice(0, 6).map((category) => (
                <Pill key={category}>{category}</Pill>
              ))}
            </div>
          </Surface>
        </aside>
      </div>

      <nav className="fixed inset-x-3 bottom-3 z-50 lg:hidden">
        <div className="premium-card hide-scrollbar flex items-center gap-2 overflow-x-auto rounded-[28px] px-3 py-3">
          {navItems.slice(0, 6).map((item) => {
            const isActive = pathname === item.href;

            return (
              <Link
                key={item.href}
                href={item.href}
                className={clsx(
                  "flex shrink-0 items-center gap-2 rounded-full px-4 py-2 text-sm",
                  isActive ? "bg-cyan/12 text-white" : "text-muted-strong",
                )}
              >
                <item.icon className="h-4 w-4" />
                {item.label}
              </Link>
            );
          })}
        </div>
      </nav>
    </div>
  );
}
