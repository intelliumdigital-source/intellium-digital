import type { ReactNode } from "react";

export function SectionCard({
  title,
  description,
  action,
  children,
  className = ""
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`rounded-[28px] border border-white/10 bg-white/[0.05] p-5 shadow-glow backdrop-blur ${className}`}>
      <div className="mb-5 flex items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-white">{title}</h2>
          {description ? <p className="mt-1 text-sm text-slate-400">{description}</p> : null}
        </div>
        {action}
      </div>
      {children}
    </section>
  );
}
