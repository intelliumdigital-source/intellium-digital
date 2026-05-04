import { Activity, CircleDollarSign, Handshake, Target, TimerReset } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { MetricCard } from "@/components/metric-card";
import { SectionCard } from "@/components/section-card";
import { StatusBadge } from "@/components/status-badge";
import { dashboardStats, followUps, leads, monthlyPerformance, sourceMix, tasks } from "@/lib/mock-data";
import { formatCurrency } from "@/lib/utils";
import { SimpleBars } from "@/components/simple-bars";

export default function DashboardPage() {
  return (
    <CrmShell subtitle="Overview of your premium local-first CRM workspace." title="Dashboard">
      <div className="grid gap-4 lg:grid-cols-5">
        <MetricCard change="+12% this month" icon={<Target className="h-5 w-5" />} label="Total Leads" value={String(dashboardStats.totalLeads)} />
        <MetricCard change="+3 today" icon={<Activity className="h-5 w-5" />} label="New Leads" value={String(dashboardStats.newLeads)} />
        <MetricCard
          change="Due before 5 PM"
          icon={<TimerReset className="h-5 w-5" />}
          label="Follow-ups Today"
          value={String(dashboardStats.followUpsToday)}
        />
        <MetricCard change="+1 this week" icon={<Handshake className="h-5 w-5" />} label="Won Deals" value={String(dashboardStats.wonDeals)} />
        <MetricCard
          change="Active pipeline"
          icon={<CircleDollarSign className="h-5 w-5" />}
          label="Estimated Revenue"
          value={formatCurrency(dashboardStats.estimatedRevenue)}
        />
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <SectionCard title="Revenue Momentum">
          <SimpleBars items={monthlyPerformance.map((item) => ({ label: item.month, value: item.revenue }))} prefix="₱" />
        </SectionCard>
        <SectionCard title="Lead Source Mix">
          <SimpleBars
            items={sourceMix.map((item) => ({
              label: item.source,
              value: item.count,
              accent: "from-violet via-blue to-cyan"
            }))}
          />
        </SectionCard>
      </div>

      <div className="mt-6 grid gap-6 xl:grid-cols-[1.2fr_0.8fr]">
        <SectionCard action={<span className="text-sm text-slate-400">Top 5 active leads</span>} title="Active Lead Feed">
          <div className="space-y-4">
            {leads.slice(0, 5).map((lead) => (
              <article key={lead.id} className="flex flex-col gap-4 rounded-3xl border border-white/10 bg-slate-950/40 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div>
                  <p className="font-medium text-white">{lead.businessName}</p>
                  <p className="mt-1 text-sm text-slate-400">
                    {lead.fullName} • {lead.service}
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

        <SectionCard title="Today’s Follow-ups">
          <div className="space-y-4">
            {followUps.map((item) => (
              <article key={item.id} className="rounded-3xl border border-white/10 bg-slate-950/40 p-4">
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

      <div className="mt-6">
        <SectionCard title="Team Tasks">
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {tasks.map((task) => (
              <article key={task.id} className="rounded-3xl border border-white/10 bg-slate-950/40 p-4">
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
      </div>
    </CrmShell>
  );
}
