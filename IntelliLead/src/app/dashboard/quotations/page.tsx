import { FileSpreadsheet } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { emptyStates, quotationSummary, quotations } from "@/lib/mock-data";
import { routes } from "@/lib/routes";
import { formatCurrency } from "@/lib/utils";

export default function QuotationsPage() {
  return (
    <CrmShell subtitle="Prepare and monitor quotations across active opportunities." title="Quotations">
      <div className="grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <SectionCard action={<FileSpreadsheet className="h-4 w-4 text-cyan" />} description="All quotation states are mock records and safe to replace later." title="Quotation Tracker">
          <div className="grid gap-4 xl:grid-cols-2">
            {quotations.map((quote) => (
              <article key={quote.id} className="rounded-[28px] border border-white/10 bg-slate-950/40 p-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-lg font-semibold text-white">{quote.client}</p>
                    <p className="mt-1 text-sm text-slate-400">{quote.packageName}</p>
                  </div>
                  <StatusBadge label={quote.status} />
                </div>
                <div className="mt-5 grid gap-3 text-sm text-slate-300 sm:grid-cols-3">
                  <div>
                    <p className="text-slate-500">Amount</p>
                    <p className="mt-1 text-white">{formatCurrency(quote.amount)}</p>
                  </div>
                  <div>
                    <p className="text-slate-500">Quote ID</p>
                    <p className="mt-1 text-white">{quote.id}</p>
                  </div>
                  <div>
                    <p className="text-slate-500">Valid Until</p>
                    <p className="mt-1 text-white">{quote.validUntil}</p>
                  </div>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>

        <div className="space-y-6">
          <SectionCard description="Premium summary cards for the quotation workflow." title="Quote Status Summary">
            <div className="grid gap-4">
              {quotationSummary.map((item) => (
                <div key={item.label} className="flex items-center justify-between rounded-[24px] border border-white/10 bg-slate-950/40 px-4 py-4">
                  <p className="text-slate-300">{item.label}</p>
                  <p className="font-[var(--font-display)] text-2xl text-white">{item.value}</p>
                </div>
              ))}
            </div>
          </SectionCard>

          {!emptyStates.expiredQuotes.length ? (
            <EmptyState
              ctaHref={routes.reports}
              ctaLabel="Open Reports"
              description="There are no expired quotations in the mock dataset. This space is ready for future auto-expiry alerts and reminders."
              eyebrow="Clean Quotations"
              icon={<FileSpreadsheet className="h-5 w-5" />}
              title="No expired quotations to chase"
            />
          ) : null}
        </div>
      </div>
    </CrmShell>
  );
}
