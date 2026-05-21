import Link from "next/link";
import { redirect } from "next/navigation";

import { DailyChecklist } from "@/components/shared/daily-checklist";
import { EmptyState } from "@/components/shared/empty-state";
import { StatCard } from "@/components/shared/stat-card";
import { SetupNotice } from "@/components/shared/setup-notice";
import { requireRole } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Lead, Commission } from "@/lib/types";
import { formatCurrency } from "@/lib/utils";

export default async function DashboardPage() {
  const session = await requireRole(["researcher"]);

  if (!session.configured || !session.profile) {
    return <SetupNotice />;
  }

  if (session.profile.role === "admin") {
    redirect("/admin");
  }

  const supabase = await createServerSupabaseClient();
  const { data: leadsData } = await supabase
    .from("leads")
    .select("*")
    .eq("researcher_id", session.profile.id)
    .order("submitted_at", { ascending: false });

  const { data: commissionsData } = await supabase
    .from("commissions")
    .select("*")
    .eq("researcher_id", session.profile.id);

  const leads = (leadsData ?? []) as Lead[];
  const commissions = (commissionsData ?? []) as Commission[];

  const totalLeads = leads.length;
  const qualifiedLeads = leads.filter((lead) => lead.status === "Qualified").length;
  const interestedLeads = leads.filter((lead) => lead.status === "Interested").length;
  const closedClients = leads.filter((lead) => lead.status === "Closed Won").length;
  const pendingCommission = commissions
    .filter((commission) => commission.status === "Pending")
    .reduce((sum, commission) => sum + (commission.commission_amount ?? 0), 0);
  const paidCommission = commissions
    .filter((commission) => commission.status === "Paid")
    .reduce((sum, commission) => sum + (commission.commission_amount ?? 0), 0);

  return (
    <div className="page-shell">
      <section className="hero-card" style={{ marginBottom: "1rem" }}>
        <div className="page-header" style={{ marginBottom: 0 }}>
          <div>
            <p className="eyebrow">Researcher Dashboard</p>
            <h1 className="title">Lead pipeline at a glance</h1>
            <p className="subtitle">
              Track the quality of your submissions, stay aligned with approved
              outreach process, and watch commission progress without waiting for
              manual updates.
            </p>
          </div>
          <div className="inline-actions">
            <Link className="button" href="/submit-lead">
              Submit a Lead
            </Link>
            <Link className="button-secondary" href="/outreach-kit">
              Open Outreach Kit
            </Link>
          </div>
        </div>
      </section>

      <section className="grid grid-3" style={{ marginBottom: "1rem" }}>
        <StatCard label="Total Leads Submitted" value={totalLeads} />
        <StatCard label="Qualified Leads" value={qualifiedLeads} />
        <StatCard label="Interested Leads" value={interestedLeads} />
        <StatCard label="Closed Clients" value={closedClients} />
        <StatCard label="Pending Commission" value={formatCurrency(pendingCommission)} />
        <StatCard label="Paid Commission" value={formatCurrency(paidCommission)} />
      </section>

      <section className="grid grid-2">
        <div className="card">
          <h2 className="section-title">Daily Task Checklist</h2>
          <p className="section-description">
            Complete these checkpoints before ending the day.
          </p>
          <DailyChecklist userId={session.profile.id} />
        </div>

        <div className="card">
          <h2 className="section-title">Recent Lead Activity</h2>
          <p className="section-description">
            Your latest submissions and how they are moving through review.
          </p>

          {leads.length === 0 ? (
            <EmptyState
              title="No leads submitted yet"
              description="Start with the outreach kit, then submit your first qualified lead."
            />
          ) : (
            <div className="stack">
              {leads.slice(0, 5).map((lead) => (
                <div key={lead.id} className="card">
                  <div className="inline-actions" style={{ justifyContent: "space-between" }}>
                    <div>
                      <strong>{lead.business_name}</strong>
                      <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
                        {lead.business_type} - {lead.location}
                      </p>
                    </div>
                    <span className="badge badge-info">{lead.status}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
