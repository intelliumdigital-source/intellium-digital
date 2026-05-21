import type { Lead } from "@/lib/types";
import { EmptyState } from "@/components/empty-state";
import { StatusBadge } from "@/components/status-badge";

export function LeadTable({ items }: { items: Lead[] }) {
  if (!items.length) {
    return (
      <EmptyState
        ctaHref="/dashboard"
        ctaLabel="Back to Dashboard"
        description="New leads will appear here once you start receiving inquiries from forms, Facebook, or manual imports."
        title="No leads in this workspace yet"
      />
    );
  }

  return (
    <>
      <div className="hidden overflow-hidden rounded-[28px] border border-white/10 xl:block">
        <table className="min-w-full divide-y divide-white/10">
          <thead className="bg-white/5 text-left text-xs uppercase tracking-[0.2em] text-slate-400">
            <tr>
              <th className="px-5 py-4">Lead</th>
              <th className="px-5 py-4">Contact</th>
              <th className="px-5 py-4">Source</th>
              <th className="px-5 py-4">Service</th>
              <th className="px-5 py-4">Budget</th>
              <th className="px-5 py-4">Follow-up</th>
              <th className="px-5 py-4">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/10 text-sm text-slate-200">
            {items.map((lead) => (
              <tr key={lead.id} className="bg-slate-950/30">
                <td className="px-5 py-4">
                  <p className="font-medium text-white">{lead.businessName}</p>
                  <p className="text-slate-400">{lead.fullName}</p>
                </td>
                <td className="px-5 py-4 text-slate-300">
                  <p>{lead.phone}</p>
                  <p className="text-slate-500">{lead.email}</p>
                </td>
                <td className="px-5 py-4">{lead.source}</td>
                <td className="px-5 py-4">
                  <p>{lead.service}</p>
                  <p className="mt-1 text-xs text-slate-500">{lead.notes}</p>
                </td>
                <td className="px-5 py-4 text-slate-300">{lead.budget}</td>
                <td className="px-5 py-4">{lead.nextFollowUp}</td>
                <td className="px-5 py-4">
                  <StatusBadge label={lead.status} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="grid gap-4 xl:hidden">
        {items.map((lead) => (
          <article key={lead.id} className="rounded-[28px] border border-white/10 bg-slate-950/40 p-5">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="font-medium text-white">{lead.businessName}</p>
                <p className="text-sm text-slate-400">{lead.fullName}</p>
              </div>
              <StatusBadge label={lead.status} />
            </div>
            <div className="mt-5 grid gap-2 text-sm text-slate-300">
              <p>Phone: {lead.phone}</p>
              <p>Email: {lead.email}</p>
              <p>Source: {lead.source}</p>
              <p>Service: {lead.service}</p>
              <p>Budget: {lead.budget}</p>
              <p>Next follow-up: {lead.nextFollowUp}</p>
              <p className="text-slate-400">{lead.notes}</p>
            </div>
          </article>
        ))}
      </div>
    </>
  );
}
