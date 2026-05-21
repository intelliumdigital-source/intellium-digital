import { Filter, Plus } from "lucide-react";
import { ButtonLink } from "@/components/button";
import { CrmShell } from "@/components/crm-shell";
import { LeadTable } from "@/components/lead-table";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { leadStatusSummary, leads } from "@/lib/mock-data";
import { routes } from "@/lib/routes";

export default function LeadsPage() {
  return (
    <CrmShell subtitle="Manage inquiries, follow-ups, and conversion stages." title="Leads">
      <SectionCard
        action={
          <div className="flex items-center gap-2 text-sm text-slate-400">
            <Filter className="h-4 w-4" />
            Mock filters only
          </div>
        }
        description="Status chips and counts mirror the lead workflow that will later connect to your database."
        title="Lead Status Overview"
      >
        <div className="grid gap-4 md:grid-cols-3 xl:grid-cols-6">
          {leadStatusSummary.map((item) => (
            <article key={item.status} className="rounded-[24px] border border-white/10 bg-slate-950/35 p-4">
              <StatusBadge label={item.status} />
              <p className="mt-4 font-[var(--font-display)] text-3xl font-semibold text-white">{item.count}</p>
            </article>
          ))}
        </div>
      </SectionCard>

      <div className="mt-6">
        <SectionCard
          action={
            <ButtonLink href={routes.leads} variant="secondary">
              <Plus className="h-4 w-4" />
              Add Lead
            </ButtonLink>
          }
          description="Responsive table on desktop, premium cards on smaller screens."
          title="Lead Database"
        >
          <LeadTable items={leads} />
        </SectionCard>
      </div>
    </CrmShell>
  );
}
