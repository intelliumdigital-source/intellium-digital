"use client";

import { useState } from "react";
import { Sidebar } from "@/components/sidebar";
import { Topbar } from "@/components/topbar";

export function CrmShell({
  title,
  subtitle,
  children
}: {
  title: string;
  subtitle: string;
  children: React.ReactNode;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="min-h-screen bg-ink text-slate-100">
      <div className="pointer-events-none fixed inset-0 bg-[radial-gradient(circle_at_top_left,rgba(61,242,255,0.14),transparent_30%),radial-gradient(circle_at_top_right,rgba(134,93,255,0.16),transparent_25%),linear-gradient(180deg,#02050f_0%,#050915_55%,#030611_100%)]" />
      <div className="relative md:flex">
        <Sidebar onClose={() => setOpen(false)} open={open} />
        <div className="flex min-h-screen flex-1 flex-col md:ml-0">
          <Topbar onMenuClick={() => setOpen(true)} subtitle={subtitle} title={title} />
          <main className="flex-1 px-4 py-6 md:px-8 xl:px-10">
            <div className="mx-auto w-full max-w-[1480px]">{children}</div>
          </main>
        </div>
      </div>
    </div>
  );
}
