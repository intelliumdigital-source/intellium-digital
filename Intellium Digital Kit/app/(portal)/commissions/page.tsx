import { EmptyState } from "@/components/shared/empty-state";
import { SetupNotice } from "@/components/shared/setup-notice";
import { StatusBadge } from "@/components/shared/status-badge";
import { requireRole } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Commission, Lead } from "@/lib/types";
import { formatCurrency, formatDate, getCommissionTone } from "@/lib/utils";

export default async function CommissionsPage() {
  const session = await requireRole(["researcher"]);

  if (!session.configured || !session.profile) {
    return <SetupNotice />;
  }

  const supabase = await createServerSupabaseClient();
  const { data: commissionsData } = await supabase
    .from("commissions")
    .select("*")
    .eq("researcher_id", session.profile.id)
    .order("created_at", { ascending: false });

  const commissions = (commissionsData ?? []) as Commission[];
  const leadIds = commissions.map((commission) => commission.lead_id);

  const { data: leadsData } = leadIds.length
    ? await supabase.from("leads").select("id, business_name").in("id", leadIds)
    : { data: [] as Partial<Lead>[] };

  const leadMap = new Map(
    ((leadsData ?? []) as Array<Pick<Lead, "id" | "business_name">>).map((lead) => [
      lead.id,
      lead.business_name
    ])
  );

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <p className="eyebrow">Commissions</p>
        <h1 className="title">Commission progress and payouts</h1>
        <p className="subtitle">
          Commission applies only after the client successfully pays Intellium Digital.
        </p>
      </section>

      <section className="card">
        <h2 className="section-title">Commission Records</h2>
        <p className="section-description">
          View client package, project amount, commission amount, status, and paid date.
        </p>

        {commissions.length === 0 ? (
          <EmptyState
            title="No commission records yet"
            description="Closed projects will appear here once admin creates the commission record."
          />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Client / Business</th>
                  <th>Package</th>
                  <th>Project Amount</th>
                  <th>Commission Amount</th>
                  <th>Status</th>
                  <th>Paid Date</th>
                </tr>
              </thead>
              <tbody>
                {commissions.map((commission) => (
                  <tr key={commission.id}>
                    <td>{leadMap.get(commission.lead_id) ?? "Unknown business"}</td>
                    <td>{commission.package_name || "Not set"}</td>
                    <td>{formatCurrency(commission.project_amount)}</td>
                    <td>{formatCurrency(commission.commission_amount)}</td>
                    <td>
                      <StatusBadge
                        label={commission.status}
                        tone={getCommissionTone(commission.status)}
                      />
                    </td>
                    <td>{formatDate(commission.paid_date)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
