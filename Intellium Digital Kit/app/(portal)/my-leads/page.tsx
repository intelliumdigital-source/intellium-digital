import { EmptyState } from "@/components/shared/empty-state";
import { SetupNotice } from "@/components/shared/setup-notice";
import { StatusBadge } from "@/components/shared/status-badge";
import { requireRole } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Commission, Lead } from "@/lib/types";
import { formatCurrency, formatDate, getCommissionTone, getLeadStatusTone } from "@/lib/utils";

export default async function MyLeadsPage() {
  const session = await requireRole(["researcher"]);

  if (!session.configured || !session.profile) {
    return <SetupNotice />;
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
  const commissionMap = new Map(commissions.map((commission) => [commission.lead_id, commission]));

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <p className="eyebrow">My Leads</p>
        <h1 className="title">Your submitted leads only</h1>
        <p className="subtitle">
          Review each lead’s progression, score, and commission status without exposing other researchers’ data.
        </p>
      </section>

      <section className="card">
        <h2 className="section-title">Lead History</h2>
        <p className="section-description">
          Commission status appears once a lead has an associated commission record.
        </p>

        {leads.length === 0 ? (
          <EmptyState
            title="No submitted leads yet"
            description="Your lead history will appear here after your first submission."
          />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Business Name</th>
                  <th>Business Type</th>
                  <th>Recommended Service</th>
                  <th>Lead Score</th>
                  <th>Status</th>
                  <th>Date Submitted</th>
                  <th>Commission</th>
                </tr>
              </thead>
              <tbody>
                {leads.map((lead) => {
                  const commission = commissionMap.get(lead.id);

                  return (
                    <tr key={lead.id}>
                      <td>{lead.business_name}</td>
                      <td>{lead.business_type}</td>
                      <td>{lead.recommended_service}</td>
                      <td>{lead.lead_score}</td>
                      <td>
                        <StatusBadge label={lead.status} tone={getLeadStatusTone(lead.status)} />
                      </td>
                      <td>{formatDate(lead.submitted_at)}</td>
                      <td>
                        {commission ? (
                          <div className="stack" style={{ gap: "0.45rem" }}>
                            <StatusBadge
                              label={commission.status}
                              tone={getCommissionTone(commission.status)}
                            />
                            <span className="helper-text">
                              {formatCurrency(commission.commission_amount)}
                            </span>
                          </div>
                        ) : (
                          <span className="helper-text">Not available yet</span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
