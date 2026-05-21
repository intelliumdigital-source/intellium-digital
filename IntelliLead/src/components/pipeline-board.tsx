import { pipelineStages } from "@/lib/mock-data";
import { formatCurrency } from "@/lib/utils";

export function PipelineBoard() {
  return (
    <div className="-mx-1 flex gap-4 overflow-x-auto px-1 pb-2">
      {pipelineStages.map((stage) => (
        <div key={stage.name} className="min-w-[280px] flex-1 rounded-[28px] border border-white/10 bg-slate-950/40 p-4 xl:min-w-0">
          <div className="mb-4 flex items-center justify-between">
            <div>
              <p className="font-medium text-white">{stage.name}</p>
              <p className="text-sm text-slate-400">{stage.total} deals</p>
            </div>
            <span className="rounded-full border border-cyan/20 bg-cyan/10 px-3 py-1 text-xs text-cyan">{stage.leads.length}</span>
          </div>
          <div className="space-y-3">
            {stage.leads.map((lead) => (
              <article key={lead.id} className="rounded-[24px] border border-white/10 bg-white/[0.03] p-4">
                <p className="font-medium text-white">{lead.company}</p>
                <p className="mt-1 text-sm text-slate-400">{lead.contact}</p>
                <div className="mt-4 flex items-center justify-between text-sm">
                  <span className="text-slate-500">{lead.source}</span>
                  <span className="font-medium text-cyan">{formatCurrency(lead.amount)}</span>
                </div>
              </article>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
