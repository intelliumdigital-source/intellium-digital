import type { Route } from "next";
import Link from "next/link";

export function Logo({ href = "/" }: { href?: Route }) {
  return (
    <Link className="inline-flex items-center gap-3" href={href}>
      <div className="flex h-11 w-11 items-center justify-center rounded-2xl border border-cyan/40 bg-white/5 shadow-neon">
        <div className="h-5 w-5 rounded-md bg-gradient-to-br from-cyan via-blue to-violet" />
      </div>
      <div>
        <p className="font-semibold tracking-[0.22em] text-slate-300 uppercase">Intellium Digital</p>
        <p className="font-semibold text-white">IntelliLead</p>
      </div>
    </Link>
  );
}
