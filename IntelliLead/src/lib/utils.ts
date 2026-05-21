export function formatCurrency(value: number) {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
    maximumFractionDigits: 0
  }).format(value);
}

export function formatCompactCurrency(value: number) {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
    notation: "compact",
    maximumFractionDigits: 1
  }).format(value);
}

export function cn(...classes: Array<string | false | null | undefined>) {
  return classes.filter(Boolean).join(" ");
}

export function statusColor(status: string) {
  const map: Record<string, string> = {
    New: "bg-cyan/12 text-cyan ring-cyan/30",
    Contacted: "bg-blue/12 text-blue-100 ring-blue/30",
    "Follow-up": "bg-violet/12 text-violet-100 ring-violet/30",
    Quoted: "bg-warning/12 text-warning ring-warning/30",
    Won: "bg-success/12 text-success ring-success/30",
    Lost: "bg-danger/12 text-danger ring-danger/30",
    Draft: "bg-slate-500/12 text-slate-200 ring-slate-500/30",
    Sent: "bg-cyan/12 text-cyan ring-cyan/30",
    Negotiation: "bg-warning/12 text-warning ring-warning/30",
    Approved: "bg-success/12 text-success ring-success/30",
    Healthy: "bg-success/12 text-success ring-success/30",
    Watchlist: "bg-warning/12 text-warning ring-warning/30",
    Expansion: "bg-cyan/12 text-cyan ring-cyan/30",
    High: "bg-danger/12 text-danger ring-danger/30",
    Medium: "bg-warning/12 text-warning ring-warning/30",
    Low: "bg-cyan/12 text-cyan ring-cyan/30",
    Open: "bg-cyan/12 text-cyan ring-cyan/30",
    "In Progress": "bg-warning/12 text-warning ring-warning/30",
    Done: "bg-success/12 text-success ring-success/30"
  };

  return map[status] ?? "bg-slate-500/15 text-slate-200 ring-slate-500/30";
}
