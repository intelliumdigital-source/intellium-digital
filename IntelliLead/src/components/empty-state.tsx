import type { Route } from "next";
import type { ReactNode } from "react";
import { Sparkles } from "lucide-react";
import { ButtonLink } from "@/components/button";
import { cn } from "@/lib/utils";

export function EmptyState({
  title,
  description,
  eyebrow = "Empty State",
  ctaLabel,
  ctaHref,
  icon,
  className = ""
}: {
  title: string;
  description: string;
  eyebrow?: string;
  ctaLabel?: string;
  ctaHref?: Route;
  icon?: ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("rounded-[28px] border border-dashed border-white/12 bg-slate-950/35 p-6", className)}>
      <div className="inline-flex rounded-2xl border border-cyan/20 bg-cyan/10 p-3 text-cyan">{icon ?? <Sparkles className="h-5 w-5" />}</div>
      <p className="mt-5 text-xs font-semibold uppercase tracking-[0.24em] text-cyan">{eyebrow}</p>
      <h3 className="mt-3 text-xl font-semibold text-white">{title}</h3>
      <p className="mt-3 max-w-xl text-sm leading-7 text-slate-400">{description}</p>
      {ctaLabel && ctaHref ? (
        <div className="mt-5">
          <ButtonLink href={ctaHref} variant="secondary">
            {ctaLabel}
          </ButtonLink>
        </div>
      ) : null}
    </div>
  );
}
