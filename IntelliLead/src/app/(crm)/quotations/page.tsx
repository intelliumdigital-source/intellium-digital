import { FileSpreadsheet } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { quotations } from "@/lib/mock-data";
import { formatCurrency } from "@/lib/utils";

export default function QuotationsPage() {
  return (
    <CrmShell subtitle="Prepare and monitor quotations across active opportunities." title="Quotations">
      <SectionCard action={<FileSpreadsheet className="h-4 w-4 text-cyan" />} title="Quotation Tracker">
        <div className="grid gap-4 xl:grid-cols-2">
          {quotations.map((quote) => (
            <article key={quote.id} className="rounded-3xl border border-white/10 bg-slate-950/40 p-5">
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
    </CrmShell>
  );
}
