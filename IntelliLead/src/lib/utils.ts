export function formatCurrency(value: number) {
  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
    maximumFractionDigits: 0
  }).format(value);
}

export function statusColor(status: string) {
  const map: Record<string, string> = {
    New: "bg-cyan/15 text-cyan ring-cyan/30",
    Contacted: "bg-blue/15 text-blue-200 ring-blue/30",
    "Follow-up": "bg-violet/15 text-violet-200 ring-violet/30",
    Quoted: "bg-warning/15 text-warning ring-warning/30",
    Won: "bg-success/15 text-success ring-success/30",
    Lost: "bg-danger/15 text-danger ring-danger/30",
    Draft: "bg-slate-500/15 text-slate-200 ring-slate-500/30",
    Sent: "bg-cyan/15 text-cyan ring-cyan/30",
    Negotiation: "bg-warning/15 text-warning ring-warning/30",
    Approved: "bg-success/15 text-success ring-success/30",
    Healthy: "bg-success/15 text-success ring-success/30",
    Watchlist: "bg-warning/15 text-warning ring-warning/30",
    Expansion: "bg-cyan/15 text-cyan ring-cyan/30",
    High: "bg-danger/15 text-danger ring-danger/30",
    Medium: "bg-warning/15 text-warning ring-warning/30",
    Low: "bg-cyan/15 text-cyan ring-cyan/30",
    Open: "bg-cyan/15 text-cyan ring-cyan/30",
    "In Progress": "bg-warning/15 text-warning ring-warning/30",
    Done: "bg-success/15 text-success ring-success/30"
  };

  return map[status] ?? "bg-slate-500/15 text-slate-200 ring-slate-500/30";
}
