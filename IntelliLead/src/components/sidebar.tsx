"use client";

import type { Route } from "next";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BarChart3,
  BriefcaseBusiness,
  ClipboardList,
  LayoutDashboard,
  Settings,
  Sheet,
  Target,
  Users,
  WalletCards,
  X
} from "lucide-react";
import { Logo } from "@/components/logo";

const navItems: Array<{ href: Route; label: string; icon: typeof LayoutDashboard }> = [
  { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
  { href: "/leads", label: "Leads", icon: Target },
  { href: "/clients", label: "Clients", icon: Users },
  { href: "/follow-ups", label: "Follow-ups", icon: ClipboardList },
  { href: "/pipeline", label: "Sales Pipeline", icon: BriefcaseBusiness },
  { href: "/quotations", label: "Quotations", icon: WalletCards },
  { href: "/reports", label: "Reports", icon: BarChart3 },
  { href: "/settings", label: "Settings", icon: Settings }
];

export function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const pathname = usePathname();

  return (
    <>
      <div
        className={`fixed inset-0 z-30 bg-slate-950/60 backdrop-blur-sm transition md:hidden ${open ? "opacity-100" : "pointer-events-none opacity-0"}`}
        onClick={onClose}
      />
      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-[290px] flex-col border-r border-white/10 bg-[#050915]/95 px-5 py-6 backdrop-blur transition duration-300 md:sticky md:translate-x-0 ${
          open ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex items-center justify-between">
          <Logo href="/" />
          <button className="rounded-2xl border border-white/10 p-2 text-slate-400 md:hidden" onClick={onClose} type="button">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="mt-10 flex-1 space-y-2">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = pathname === item.href;

            return (
              <Link
                key={item.href}
                className={`flex items-center gap-3 rounded-2xl px-4 py-3 text-sm transition ${
                  active
                    ? "border border-cyan/30 bg-cyan/10 text-white shadow-neon"
                    : "border border-transparent text-slate-400 hover:border-white/10 hover:bg-white/5 hover:text-white"
                }`}
                href={item.href}
                onClick={onClose}
              >
                <Icon className="h-4 w-4" />
                {item.label}
              </Link>
            );
          })}
        </div>

        <div className="rounded-3xl border border-cyan/20 bg-gradient-to-br from-cyan/10 via-blue/10 to-violet/10 p-4">
          <div className="mb-3 inline-flex rounded-2xl border border-cyan/20 bg-cyan/10 p-3 text-cyan">
            <Sheet className="h-5 w-5" />
          </div>
          <p className="font-medium text-white">Premium CRM for PH SMEs</p>
          <p className="mt-2 text-sm text-slate-400">Track leads, send quotations, and follow every deal from inquiry to close.</p>
        </div>
      </aside>
    </>
  );
}
