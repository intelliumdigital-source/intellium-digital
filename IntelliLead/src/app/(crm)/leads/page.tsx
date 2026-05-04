import { Filter } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { LeadTable } from "@/components/lead-table";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { leads, statusOrder } from "@/lib/mock-data";

export default function LeadsPage() {
  return (
    <CrmShell subtitle="Manage inquiries, follow-ups, and conversion stages." title="Leads">
      <SectionCard
        action={
          <div className="flex items-center gap-2 text-sm text-slate-400">
            <Filter className="h-4 w-4" />
            Filter by status
          </div>
        }
        title="Lead Status Filters"
      >
        <div className="flex flex-wrap gap-3">
          {statusOrder.map((status) => (
            <StatusBadge key={status} label={status} />
          ))}
        </div>
      </SectionCard>

      <div className="mt-6">
        <SectionCard title="Lead Database">
          <LeadTable items={leads} />
        </SectionCard>
      </div>
    </CrmShell>
  );
}
