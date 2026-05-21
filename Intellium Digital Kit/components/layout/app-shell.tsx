"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import { signOutAction } from "@/app/actions";
import { cn } from "@/lib/utils";

interface AppShellProps {
  children: React.ReactNode;
  role: "admin" | "researcher";
  name: string;
  email: string;
}

const researcherLinks = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/outreach-kit", label: "Outreach Kit" },
  { href: "/submit-lead", label: "Submit Lead" },
  { href: "/my-leads", label: "My Leads" },
  { href: "/commissions", label: "Commissions" },
  { href: "/announcements", label: "Announcements" }
];

const adminLinks = [
  { href: "/admin", label: "Admin Dashboard" },
  { href: "/admin/resources", label: "Resources" },
  { href: "/outreach-kit", label: "View Kit" },
  { href: "/announcements", label: "Announcements" }
];

export function AppShell({ children, role, name, email }: AppShellProps) {
  const pathname = usePathname();
  const links = role === "admin" ? adminLinks : researcherLinks;

  return (
    <div className="portal-shell">
      <aside className="sidebar hero-card">
        <div className="sidebar-brand">
          <span className="eyebrow">Intellium Digital</span>
          <h1>IntelliLead Outreach Portal</h1>
          <p>Legitimize. Digitize. Grow.</p>
        </div>

        <div className="card" style={{ marginBottom: "1rem" }}>
          <p className="metric-label">{role}</p>
          <p style={{ margin: "0 0 0.35rem", fontWeight: 700 }}>{name}</p>
          <p style={{ margin: 0, color: "var(--text-soft)" }}>{email}</p>
        </div>

        <p className="sidebar-section-label">Navigation</p>
        <nav className="sidebar-links">
          {links.map((link) => {
            const isActive =
              pathname === link.href || pathname.startsWith(`${link.href}/`);

            return (
              <Link
                key={link.href}
                href={link.href}
                className={cn("sidebar-link", isActive && "active")}
              >
                <span>{link.label}</span>
                <span>{isActive ? "•" : "→"}</span>
              </Link>
            );
          })}
        </nav>

        <form action={signOutAction} style={{ marginTop: "auto", paddingTop: "1rem" }}>
          <button className="button-ghost" style={{ width: "100%" }}>
            Sign out
          </button>
        </form>
      </aside>

      <main className="content-shell">
        <div className="top-mobile-bar hero-card">
          <div>
            <p className="eyebrow" style={{ margin: 0 }}>
              Intellium Digital
            </p>
            <p style={{ margin: "0.35rem 0 0", fontWeight: 700 }}>
              IntelliLead Outreach Portal
            </p>
          </div>
          <form action={signOutAction}>
            <button className="button-ghost">Sign out</button>
          </form>
        </div>

        <div className="card" style={{ marginBottom: "1rem" }}>
          <nav className="pill-nav">
            {links.map((link) => {
              const isActive =
                pathname === link.href || pathname.startsWith(`${link.href}/`);

              return (
                <Link
                  key={link.href}
                  href={link.href}
                  className={cn("pill-link", isActive && "active")}
                >
                  {link.label}
                </Link>
              );
            })}
          </nav>
        </div>

        {children}
      </main>
    </div>
  );
}
