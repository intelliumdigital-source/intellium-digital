import { CrmShell } from "@/components/crm-shell";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { clients } from "@/lib/mock-data";
import { formatCurrency } from "@/lib/utils";

export default function ClientsPage() {
  return (
    <CrmShell subtitle="Track active accounts, plan renewals, and account health." title="Clients">
      <SectionCard title="Active Clients">
        <div className="grid gap-4 xl:grid-cols-2">
          {clients.map((client) => (
            <article key={client.id} className="rounded-3xl border border-white/10 bg-slate-950/40 p-5">
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
    </CrmShell>
  );
}
