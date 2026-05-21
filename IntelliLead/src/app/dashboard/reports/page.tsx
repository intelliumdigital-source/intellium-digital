import { BarChart3 } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { SectionCard } from "@/components/section-card";
import { SimpleBars } from "@/components/simple-bars";
import { dashboardStats, emptyStates, monthlyPerformance, sourceMix } from "@/lib/mock-data";
import { routes } from "@/lib/routes";
import { formatCurrency } from "@/lib/utils";

export default function ReportsPage() {
  return (
    <CrmShell subtitle="Review lead generation, conversion activity, and pipeline value." title="Reports">
      <div className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <SectionCard description="Revenue trend from the current mock CRM records." title="Monthly Revenue Report">
          <SimpleBars items={monthlyPerformance.map((item) => ({ label: item.month, value: item.revenue }))} prefix="PHP " />
        </SectionCard>
        <SectionCard description="Acquisition channel distribution for local lead sources." title="Lead Source Report">
          <SimpleBars
            items={sourceMix.map((item) => ({
              label: item.source,
              value: item.count,
              accent: "from-cyan via-blue to-violet"
            }))}
          />
        </SectionCard>
      </div>

      <div className="mt-6 grid gap-6 md:grid-cols-3">
        <SectionCard title="Projected Revenue">
          <p className="font-[var(--font-display)] text-4xl font-semibold text-white">{formatCurrency(dashboardStats.estimatedRevenue)}</p>
          <p className="mt-3 text-slate-400">Calculated from all active non-lost opportunities in the current local dataset.</p>
        </SectionCard>
        <SectionCard title="Average Deal Size">
          <p className="font-[var(--font-display)] text-4xl font-semibold text-white">{formatCurrency(49667)}</p>
          <p className="mt-3 text-slate-400">Premium service positioning with larger-ticket CRM implementation offers.</p>
        </SectionCard>
        <SectionCard title="Current Win Rate">
          <p className="font-[var(--font-display)] text-4xl font-semibold text-white">26%</p>
          <p className="mt-3 text-slate-400">Mock conversion benchmark used to present a clean reporting view.</p>
        </SectionCard>
      </div>

      <div className="mt-6">
        {!emptyStates.integrations.length ? (
          <EmptyState
            ctaHref={routes.settings}
            ctaLabel="Review Settings"
            description="Real database sync and live reporting are not connected yet. The charts are intentionally mock-driven so you can integrate Supabase later without redesigning the frontend."
            eyebrow="Reporting Ready"
            icon={<BarChart3 className="h-5 w-5" />}
            title="Live analytics sync is not connected yet"
          />
        ) : null}
      </div>
    </CrmShell>
  );
}
