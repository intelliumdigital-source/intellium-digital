import { CrmShell } from "@/components/crm-shell";
import { SectionCard } from "@/components/section-card";
import { SimpleBars } from "@/components/simple-bars";
import { dashboardStats, monthlyPerformance, sourceMix } from "@/lib/mock-data";
import { formatCurrency } from "@/lib/utils";

export default function ReportsPage() {
  return (
    <CrmShell subtitle="Review lead generation, conversion activity, and pipeline value." title="Reports">
      <div className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <SectionCard title="Monthly Revenue Report">
          <SimpleBars items={monthlyPerformance.map((item) => ({ label: item.month, value: item.revenue }))} prefix="₱" />
        </SectionCard>
        <SectionCard title="Lead Source Report">
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
          <p className="text-4xl font-semibold text-white">{formatCurrency(dashboardStats.estimatedRevenue)}</p>
          <p className="mt-3 text-slate-400">Calculated from all active non-lost opportunities in the local mock dataset.</p>
        </SectionCard>
        <SectionCard title="Average Deal Size">
          <p className="text-4xl font-semibold text-white">{formatCurrency(49667)}</p>
          <p className="mt-3 text-slate-400">Premium service positioning with larger-ticket CRM implementation offers.</p>
        </SectionCard>
        <SectionCard title="Current Win Rate">
          <p className="text-4xl font-semibold text-white">26%</p>
          <p className="mt-3 text-slate-400">Mock conversion benchmark used to present a clean reporting view.</p>
        </SectionCard>
      </div>
    </CrmShell>
  );
}
