import { Activity, CircleDollarSign, Handshake, Link2Off, Target, TimerReset } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { MetricCard } from "@/components/metric-card";
import { SectionCard } from "@/components/section-card";
import { SimpleBars } from "@/components/simple-bars";
import { StatusBadge } from "@/components/status-badge";
import { dashboardStats, followUps, leads, monthlyPerformance, tasks } from "@/lib/mock-data";
import { routes } from "@/lib/routes";
import { formatCompactCurrency, formatCurrency } from "@/lib/utils";

const revenueByMonth = monthlyPerformance.map((item) => ({ label: item.month, value: item.revenue }));
const winsByMonth = monthlyPerformance.map((item) => ({
  label: item.month,
  value: item.won,
  accent: "from-violet via-blue to-cyan"
}));

export default function DashboardPage() {
  return (
    <CrmShell subtitle="Overview of your premium local-first CRM workspace." title="Dashboard">
      <div className="grid gap-4 xl:grid-cols-5">
        <MetricCard change="+12% MoM" icon={<Target className="h-5 w-5" />} label="Total Leads" value={String(dashboardStats.totalLeads)} />
        <MetricCard change="+3 today" icon={<Activity className="h-5 w-5" />} label="New Leads" value={String(dashboardStats.newLeads)} />
        <MetricCard change="Due by 5 PM" icon={<TimerReset className="h-5 w-5" />} label="Follow-ups Today" value={String(dashboardStats.followUpsToday)} />
        <MetricCard change="+1 this week" icon={<Handshake className="h-5 w-5" />} label="Won Deals" value={String(dashboardStats.wonDeals)} />
        <MetricCard
          change="Active pipeline"
          icon={<CircleDollarSign className="h-5 w-5" />}
          label="Estimated Revenue"
          value={formatCompactCurrency(dashboardStats.estimatedRevenue)}
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <SectionCard description="Monthly revenue momentum from the current mock dataset." title="Revenue Momentum">
          <SimpleBars items={revenueByMonth} prefix="PHP " />
        </SectionCard>
        <SectionCard description="Closed deals trend for the last five months." title="Won Deals Trend">
          <SimpleBars items={winsByMonth} />
        </SectionCard>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <SectionCard action={<span className="text-sm text-slate-400">Top 5 active leads</span>} description="Leads currently moving through your sales process." title="Active Lead Feed">
          <div className="space-y-4">
            {leads.slice(0, 5).map((lead) => (
              <article key={lead.id} className="flex flex-col gap-4 rounded-[28px] border border-white/10 bg-slate-950/40 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="font-medium text-white">{lead.businessName}</p>
                  <p className="mt-1 text-sm text-slate-400">
                    {lead.fullName} | {lead.service}
                  </p>
                </div>
                <div className="flex items-center gap-4">
                  <div className="text-right text-sm">
                    <p className="text-white">{formatCurrency(lead.value)}</p>
                    <p className="text-slate-500">{lead.nextFollowUp}</p>
                  </div>
                  <StatusBadge label={lead.status} />
                </div>
              </article>
            ))}
          </div>
        </SectionCard>

        <SectionCard description="High-visibility actions for the day." title="Today's Follow-ups">
          <div className="space-y-4">
            {followUps.map((item) => (
              <article key={item.id} className="rounded-[28px] border border-white/10 bg-slate-950/40 p-4">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="font-medium text-white">{item.leadName}</p>
                    <p className="mt-1 text-sm text-slate-400">{item.company}</p>
                  </div>
                  <StatusBadge label={item.priority} />
                </div>
                <div className="mt-4 flex items-center justify-between text-sm text-slate-300">
                  <span>{item.channel}</span>
                  <span>{item.due}</span>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <SectionCard description="Day-to-day execution work for the sales team." title="Team Tasks">
          <div className="grid gap-4 md:grid-cols-2">
            {tasks.map((task) => (
              <article key={task.id} className="rounded-[28px] border border-white/10 bg-slate-950/40 p-4">
                <div className="flex items-center justify-between gap-3">
                  <p className="font-medium text-white">{task.title}</p>
                  <StatusBadge label={task.status} />
                </div>
                <div className="mt-4 text-sm text-slate-400">
                  <p>{task.owner}</p>
                  <p>{task.due}</p>
                </div>
              </article>
            ))}
          </div>
        </SectionCard>

        <EmptyState
          ctaHref={routes.settings}
          ctaLabel="Open Settings"
          description="Database sync, real auth, and team permissions are intentionally offline. This frontend is ready for those integrations without hardwiring them yet."
          eyebrow="Integration Readiness"
          icon={<Link2Off className="h-5 w-5" />}
          title="No live integrations connected yet"
        />
      </div>
    </CrmShell>
  );
}
