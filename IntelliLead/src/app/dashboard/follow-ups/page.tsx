import { BellRing, Clock3 } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { emptyStates, followUps } from "@/lib/mock-data";
import { routes } from "@/lib/routes";

export default function FollowUpsPage() {
  return (
    <CrmShell subtitle="Keep response times fast and sales conversations moving." title="Follow-ups">
      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <SectionCard action={<BellRing className="h-4 w-4 text-cyan" />} description="All reminders are local mock records for now." title="Follow-up Queue">
          <div className="space-y-4">
            {followUps.map((item) => (
              <article key={item.id} className="rounded-[28px] border border-white/10 bg-slate-950/40 p-5">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <p className="text-lg font-semibold text-white">{item.leadName}</p>
                    <p className="mt-1 text-slate-400">{item.company}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <StatusBadge label={item.priority} />
                    <span className="rounded-full border border-white/10 px-3 py-1 text-sm text-slate-300">{item.due}</span>
                  </div>
                </div>
                <div className="mt-5 grid gap-3 text-sm text-slate-300 sm:grid-cols-3">
                  <p>Channel: {item.channel}</p>
                  <p>Owner: {item.owner}</p>
                  <p>Reminder window: Today</p>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>

        {!emptyStates.overdueFollowUps.length ? (
          <EmptyState
            ctaHref={routes.leads}
            ctaLabel="Review Leads"
            description="The current mock schedule has no overdue follow-ups. This is a good place for later database-driven alerts and overdue reminders."
            eyebrow="No Delays"
            icon={<Clock3 className="h-5 w-5" />}
            title="No overdue follow-ups today"
          />
        ) : null}
      </div>
    </CrmShell>
  );
}
