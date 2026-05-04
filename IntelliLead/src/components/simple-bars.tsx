type BarDatum = {
  label: string;
  value: number;
  accent?: string;
};

export function SimpleBars({ items, prefix = "" }: { items: BarDatum[]; prefix?: string }) {
  const max = Math.max(...items.map((item) => item.value));

  return (
    <div className="space-y-4">
      {items.map((item, index) => (
        <div key={item.label}>
          <div className="mb-2 flex items-center justify-between text-sm">
            <span className="text-slate-300">{item.label}</span>
            <span className="text-slate-400">
              {prefix}
              {item.value.toLocaleString()}
            </span>
          </div>
          <div className="h-3 overflow-hidden rounded-full bg-white/5">
            <div
              className={`h-full rounded-full bg-gradient-to-r ${item.accent ?? "from-cyan via-blue to-violet"}`}
              style={{
                width: `${(item.value / max) * 100}%`,
                animationDelay: `${index * 100}ms`
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}
