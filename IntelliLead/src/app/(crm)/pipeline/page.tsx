import { CrmShell } from "@/components/crm-shell";
import { PipelineBoard } from "@/components/pipeline-board";
import { SectionCard } from "@/components/section-card";

export default function PipelinePage() {
  return (
    <CrmShell subtitle="Visualize deal flow from new inquiry to closed revenue." title="Sales Pipeline">
      <SectionCard title="Pipeline Board">
        <PipelineBoard />
      </SectionCard>
    </CrmShell>
  );
}
