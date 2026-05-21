"use client";

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
import { buttonStyles } from "@/components/button";
import { dashboardNav, routes } from "@/lib/routes";
import { cn } from "@/lib/utils";

const iconMap = {
  Dashboard: LayoutDashboard,
  Leads: Target,
  Clients: Users,
  "Follow-ups": ClipboardList,
  "Sales Pipeline": BriefcaseBusiness,
  Quotations: WalletCards,
  Reports: BarChart3,
  Settings: Settings
} as const;

export function Sidebar({ open, onClose }: { open: boolean; onClose: () => void }) {
  const pathname = usePathname();

  return (
    <>
      <div
        className={`fixed inset-0 z-30 bg-slate-950/60 backdrop-blur-sm transition md:hidden ${open ? "opacity-100" : "pointer-events-none opacity-0"}`}
        onClick={onClose}
      />
      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-[292px] flex-col border-r border-white/10 bg-[#050915]/95 px-5 py-6 backdrop-blur transition duration-300 md:sticky md:top-0 md:h-screen md:translate-x-0 ${
          open ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        <div className="flex items-center justify-between">
          <Logo href={routes.home} />
          <button className="rounded-2xl border border-white/10 p-2 text-slate-400 md:hidden" onClick={onClose} type="button">
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="mt-8 rounded-[24px] border border-cyan/15 bg-cyan/10 px-4 py-3 text-sm text-cyan">
          Local demo mode only. Supabase and auth stay disconnected for this MVP.
        </div>

        <div className="mt-8 flex-1 space-y-2">
          {dashboardNav.map((item) => {
            const Icon = iconMap[item.label];
            const active = item.href === routes.dashboard ? pathname === item.href : pathname.startsWith(item.href);

            return (
              <Link
                key={item.href}
                className={cn(
                  "flex items-center gap-3 rounded-2xl px-4 py-3 text-sm transition",
                  active
                    ? "border border-cyan/30 bg-cyan/10 text-white shadow-neon"
                    : "border border-transparent text-slate-400 hover:border-white/10 hover:bg-white/5 hover:text-white"
                )}
                href={item.href}
                onClick={onClose}
              >
                <Icon className="h-4 w-4" />
                {item.label}
              </Link>
            );
          })}
        </div>

        <div className="rounded-[28px] border border-cyan/20 bg-gradient-to-br from-cyan/10 via-blue/10 to-violet/10 p-4">
          <div className="mb-3 inline-flex rounded-2xl border border-cyan/20 bg-cyan/10 p-3 text-cyan">
            <Sheet className="h-5 w-5" />
          </div>
          <p className="font-medium text-white">IntelliLead by Intellium Digital</p>
          <p className="mt-2 text-sm text-slate-400">Smart lead tracking for growing businesses.</p>
          <div className="mt-4 flex flex-wrap gap-2">
            <a className={buttonStyles("secondary")} href="https://intelliumdigital.online" rel="noreferrer" target="_blank">
              Website
            </a>
            <a className={buttonStyles("ghost")} href="https://facebook.com/IntelliumDigitalPH" rel="noreferrer" target="_blank">
              Facebook
            </a>
          </div>
        </div>
      </aside>
    </>
  );
}
