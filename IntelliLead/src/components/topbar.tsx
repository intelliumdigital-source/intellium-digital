"use client";

import { Menu, Plus, Search } from "lucide-react";
import { ButtonLink } from "@/components/button";
import { routes } from "@/lib/routes";

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
    <header className="sticky top-0 z-20 border-b border-white/10 bg-[#050915]/80 px-4 py-4 backdrop-blur md:px-8 xl:px-10">
      <div className="mx-auto flex w-full max-w-[1480px] flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
        <div className="flex items-center gap-3">
          <button className="rounded-2xl border border-white/10 p-2 text-slate-300 md:hidden" onClick={onMenuClick} type="button">
            <Menu className="h-5 w-5" />
          </button>
          <div>
            <div className="mb-2 inline-flex rounded-full border border-white/10 bg-white/5 px-3 py-1 text-xs font-medium uppercase tracking-[0.18em] text-slate-400">
              IntelliLead demo workspace
            </div>
            <h1 className="font-[var(--font-display)] text-2xl font-semibold text-white">{title}</h1>
            <p className="text-sm text-slate-400">{subtitle}</p>
          </div>
        </div>

        <div className="flex flex-col gap-3 lg:flex-row lg:items-center">
          <label className="flex w-full items-center gap-3 rounded-2xl border border-white/10 bg-white/5 px-4 py-3 text-sm text-slate-400 lg:min-w-[320px]">
            <Search className="h-4 w-4" />
            <input
              className="w-full bg-transparent text-white outline-none placeholder:text-slate-500"
              placeholder="Search leads, clients, quotations..."
              type="search"
            />
          </label>
          <ButtonLink className="w-full sm:w-auto" href={routes.leads} variant="primary">
            <Plus className="h-4 w-4" />
            Add Lead
          </ButtonLink>
        </div>
      </div>
    </header>
  );
}
