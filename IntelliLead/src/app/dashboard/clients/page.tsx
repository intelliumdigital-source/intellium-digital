import { Building2 } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { clientHealthSummary, clients, emptyStates } from "@/lib/mock-data";
import { routes } from "@/lib/routes";
import { formatCurrency } from "@/lib/utils";

export default function ClientsPage() {
  return (
    <CrmShell subtitle="Track active accounts, plan renewals, and monitor client health." title="Clients">
      <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <SectionCard description="Current mock accounts already converted from the lead pipeline." title="Active Clients">
          <div className="grid gap-4 xl:grid-cols-2">
            {clients.map((client) => (
              <article key={client.id} className="rounded-[28px] border border-white/10 bg-slate-950/40 p-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-xl font-semibold text-white">{client.businessName}</p>
                    <p className="mt-1 text-sm text-slate-400">{client.contactPerson}</p>
                  </div>
                  <StatusBadge label={client.health} />
                </div>
                <div className="mt-6 grid gap-3 text-sm text-slate-300 sm:grid-cols-3">
                  <div>
                    <p className="text-slate-500">Plan</p>
                    <p className="mt-1 text-white">{client.servicePlan}</p>
                  </div>
                  <div>
                    <p className="text-slate-500">Monthly Value</p>
                    <p className="mt-1 text-white">{formatCurrency(client.monthlyValue)}</p>
                  </div>
                  <div>
                    <p className="text-slate-500">Renewal</p>
                    <p className="mt-1 text-white">{client.renewalDate}</p>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>

        <div className="space-y-6">
          <SectionCard description="Quick health summary across active client accounts." title="Account Health">
            <div className="grid gap-4">
              {clientHealthSummary.map((item) => (
                <div key={item.label} className="flex items-center justify-between rounded-[24px] border border-white/10 bg-slate-950/40 px-4 py-4">
                  <p className="text-slate-300">{item.label}</p>
                  <p className="font-[var(--font-display)] text-2xl text-white">{item.value}</p>
                </div>
              ))}
            </div>
          </SectionCard>

          {!emptyStates.archivedClients.length ? (
            <EmptyState
              ctaHref={routes.dashboard}
              ctaLabel="Back to Dashboard"
              description="Archived or churned client records are not part of this MVP yet. The current view stays focused on active accounts and renewals."
              eyebrow="Clean Workspace"
              icon={<Building2 className="h-5 w-5" />}
              title="No archived clients to review"
            />
          ) : null}
        </div>
      </div>
    </CrmShell>
  );
}
