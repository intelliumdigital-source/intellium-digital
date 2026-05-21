import { CrmShell } from "@/components/crm-shell";
import { LoadingState } from "@/components/loading-state";

export default function DashboardLoading() {
  return (
    <CrmShell subtitle="Preparing your CRM workspace." title="Loading">
      <LoadingState />
    </CrmShell>
  );
}
