import type { ReactNode } from "react";

export function MetricCard({
  label,
  value,
  change,
  icon
}: {
  label: string;
  value: string;
  change: string;
  icon: ReactNode;
}) {
  return (
    <div className="rounded-3xl border border-white/10 bg-white/5 p-5 shadow-glow backdrop-blur">
      <div className="flex items-center justify-between">
        <div className="rounded-2xl border border-cyan/20 bg-cyan/10 p-3 text-cyan">{icon}</div>
        <span className="text-xs text-slate-400">{change}</span>
      </div>
      <p className="mt-5 text-sm text-slate-400">{label}</p>
      <p className="mt-2 text-3xl font-semibold text-white">{value}</p>
    </div>
  );
}
