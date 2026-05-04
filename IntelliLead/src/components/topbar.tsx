"use client";

import Link from "next/link";
import { Menu, Plus, Search } from "lucide-react";

export function Topbar({
  title,
  subtitle,
  onMenuClick
}: {
  title: string;
  subtitle: string;
  onMenuClick: () => void;
}) {
  return (
    <header className="sticky top-0 z-20 border-b border-white/10 bg-[#050915]/80 px-4 py-4 backdrop-blur md:px-8">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div className="flex items-center gap-3">
          <button className="rounded-2xl border border-white/10 p-2 text-slate-300 md:hidden" onClick={onMenuClick} type="button">
            <Menu className="h-5 w-5" />
          </button>
          <div>
            <h1 className="text-2xl font-semibold text-white">{title}</h1>
            <p className="text-sm text-slate-400">{subtitle}</p>
          </div>
        </div>

        <div className="flex flex-col gap-3 sm:flex-row">
          <label className="flex min-w-[260px] items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-slate-400">
            <Search className="h-4 w-4" />
            <input
              className="w-full bg-transparent text-white outline-none placeholder:text-slate-500"
              placeholder="Search leads, clients, quotations..."
              type="search"
            />
          </label>
          <Link
            className="inline-flex items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-cyan via-blue to-violet px-4 py-3 font-medium text-slate-950"
            href="/leads"
          >
            <Plus className="h-4 w-4" />
            Add Lead
          </Link>
        </div>
      </div>
    </header>
  );
}
