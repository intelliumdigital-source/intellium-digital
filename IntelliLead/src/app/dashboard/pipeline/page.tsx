import { BriefcaseBusiness } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { PipelineBoard } from "@/components/pipeline-board";
import { SectionCard } from "@/components/section-card";
import { dashboardStats, emptyStates } from "@/lib/mock-data";
import { routes } from "@/lib/routes";
import { formatCurrency } from "@/lib/utils";

export default function PipelinePage() {
  return (
    <CrmShell subtitle="Visualize deal flow from inquiry to closed revenue." title="Sales Pipeline">
      <SectionCard description={`Current active pipeline value: ${formatCurrency(dashboardStats.estimatedRevenue)}.`} title="Pipeline Board">
        <PipelineBoard />
      </SectionCard>

      <div className="mt-6">
        {!emptyStates.stalledDeals.length ? (
          <EmptyState
            ctaHref={routes.followUps}
            ctaLabel="Check Follow-ups"
            description="No stalled deals beyond 30 days are being shown in the mock pipeline. This panel is ready for future database-driven warnings."
            eyebrow="Healthy Flow"
            icon={<BriefcaseBusiness className="h-5 w-5" />}
            title="No stalled deals needing rescue"
          />
        ) : null}
      </div>
    </CrmShell>
  );
}
