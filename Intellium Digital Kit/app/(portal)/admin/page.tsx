import Link from "next/link";

import { saveCommissionAction, updateLeadAction } from "@/app/actions";
import { EmptyState } from "@/components/shared/empty-state";
import { FormSubmitButton } from "@/components/shared/form-submit-button";
import { SetupNotice } from "@/components/shared/setup-notice";
import { StatCard } from "@/components/shared/stat-card";
import { StatusBadge } from "@/components/shared/status-badge";
import { commissionStatuses, leadStatuses, reviewStatuses } from "@/lib/data/statuses";
import { requireRole } from "@/lib/auth";
import { createProofSignedUrl } from "@/lib/leads";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Announcement, Commission, Lead, Profile } from "@/lib/types";
import {
  formatCurrency,
  formatDate,
  getCommissionTone,
  getLeadStatusTone,
  getReviewTone
} from "@/lib/utils";

export const dynamic = "force-dynamic";

type LeadRecord = Lead & {
  proofUrl: string | null;
};

export default async function AdminDashboardPage() {
  const session = await requireRole(["admin"]);

  if (!session.configured || !session.profile) {
    return <SetupNotice />;
  }

  const supabase = await createServerSupabaseClient();
  const [{ data: researchersData }, { data: leadsData }, { data: commissionsData }, { data: announcementsData }] =
    await Promise.all([
      supabase.from("profiles").select("*").eq("role", "researcher").order("created_at", { ascending: true }),
      supabase.from("leads").select("*").order("submitted_at", { ascending: false }),
      supabase.from("commissions").select("*").order("created_at", { ascending: false }),
      supabase
        .from("announcements")
        .select("*")
        .order("published_at", { ascending: false })
        .limit(3)
    ]);

  const researchers = (researchersData ?? []) as Profile[];
  const leadsBase = (leadsData ?? []) as Lead[];
  const commissions = (commissionsData ?? []) as Commission[];
  const announcements = (announcementsData ?? []) as Announcement[];

  const leads: LeadRecord[] = await Promise.all(
    leadsBase.map(async (lead) => ({
      ...lead,
      proofUrl: await createProofSignedUrl(lead.screenshot_path)
    }))
  );

  const researcherMap = new Map(
    researchers.map((researcher) => [researcher.id, researcher.full_name || researcher.email])
  );
  const commissionMap = new Map(commissions.map((commission) => [commission.lead_id, commission]));

  const totalPending = commissions
    .filter((commission) => commission.status === "Pending")
    .reduce((sum, commission) => sum + (commission.commission_amount ?? 0), 0);

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <div className="page-header" style={{ marginBottom: 0 }}>
          <div>
            <p className="eyebrow">Admin Dashboard</p>
            <h1 className="title">Manage outreach operations</h1>
            <p className="subtitle">
              Review researchers, validate lead quality, update lead status, control commissions, and publish new resources.
            </p>
          </div>
          <div className="inline-actions">
            <Link href="/admin/resources" className="button">
              Manage Resources
            </Link>
            <Link href="/announcements" className="button-secondary">
              View Announcements
            </Link>
          </div>
        </div>
      </section>

      <section className="grid grid-4">
        <StatCard label="Researchers" value={researchers.length} />
        <StatCard label="All Leads" value={leads.length} />
        <StatCard label="Closed Won" value={leads.filter((lead) => lead.status === "Closed Won").length} />
        <StatCard label="Pending Commission" value={formatCurrency(totalPending)} />
      </section>

      <section className="grid grid-2">
        <div className="card">
          <h2 className="section-title">Researchers</h2>
          <p className="section-description">
            All active researcher profiles in the portal.
          </p>
          {researchers.length === 0 ? (
            <EmptyState
              title="No researchers found"
              description="Create auth users and corresponding profile rows to onboard researchers."
            />
          ) : (
            <div className="stack">
              {researchers.map((researcher) => (
                <div key={researcher.id} className="card">
                  <strong>{researcher.full_name || "Unnamed researcher"}</strong>
                  <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
                    {researcher.email}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="card">
          <h2 className="section-title">Recent Announcements</h2>
          <p className="section-description">
            Quick view of the latest admin posts.
          </p>
          {announcements.length === 0 ? (
            <EmptyState
              title="No announcements yet"
              description="Create one from the Resources page."
            />
          ) : (
            <div className="stack">
              {announcements.map((announcement) => (
                <div key={announcement.id} className="card">
                  <div className="inline-actions" style={{ justifyContent: "space-between" }}>
                    <strong>{announcement.title}</strong>
                    {announcement.is_pinned ? <StatusBadge label="Pinned" tone="info" /> : null}
                  </div>
                  <p style={{ margin: "0.7rem 0 0", color: "var(--text-soft)" }}>
                    {announcement.content}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      </section>

      <section className="card">
        <h2 className="section-title">Lead Management</h2>
        <p className="section-description">
          Approve or reject submissions, mark duplicates, and update pipeline status.
        </p>

        {leads.length === 0 ? (
          <EmptyState
            title="No leads submitted"
            description="Lead submissions from researchers will appear here."
          />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Business</th>
                  <th>Researcher</th>
                  <th>Service</th>
                  <th>Score</th>
                  <th>Review</th>
                  <th>Status</th>
                  <th>Proof</th>
                  <th>Update</th>
                </tr>
              </thead>
              <tbody>
                {leads.map((lead) => (
                  <tr key={lead.id}>
                    <td>
                      <strong>{lead.business_name}</strong>
                      <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
                        {lead.business_type} - {lead.location}
                      </p>
                    </td>
                    <td>{researcherMap.get(lead.researcher_id) ?? "Unknown"}</td>
                    <td>{lead.recommended_service}</td>
                    <td>{lead.lead_score}</td>
                    <td>
                      <StatusBadge
                        label={lead.review_status}
                        tone={getReviewTone(lead.review_status)}
                      />
                    </td>
                    <td>
                      <StatusBadge
                        label={lead.status}
                        tone={getLeadStatusTone(lead.status)}
                      />
                    </td>
                    <td>
                      {lead.proofUrl ? (
                        <Link
                          className="button-ghost"
                          href={lead.proofUrl}
                          target="_blank"
                          rel="noreferrer noopener"
                        >
                          Open proof
                        </Link>
                      ) : (
                        <span className="helper-text">No proof</span>
                      )}
                    </td>
                    <td>
                      <form action={updateLeadAction} className="stack" style={{ gap: "0.65rem" }}>
                        <input type="hidden" name="lead_id" value={lead.id} />
                        <select name="review_status" defaultValue={lead.review_status}>
                          {reviewStatuses.map((status) => (
                            <option key={status} value={status}>
                              {status}
                            </option>
                          ))}
                        </select>
                        <select name="status" defaultValue={lead.status}>
                          {leadStatuses.map((status) => (
                            <option key={status} value={status}>
                              {status}
                            </option>
                          ))}
                        </select>
                        <FormSubmitButton
                          label="Save Lead"
                          pendingLabel="Saving..."
                          variant="secondary"
                        />
                      </form>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="card">
        <h2 className="section-title">Commission Management</h2>
        <p className="section-description">
          Create or update project amount, commission amount, payout status, and paid date.
        </p>

        {leads.length === 0 ? (
          <EmptyState
            title="No leads available"
            description="Commissions can be created once leads exist."
          />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Client</th>
                  <th>Researcher</th>
                  <th>Current Commission</th>
                  <th>Manage</th>
                </tr>
              </thead>
              <tbody>
                {leads.map((lead) => {
                  const commission = commissionMap.get(lead.id);

                  return (
                    <tr key={lead.id}>
                      <td>
                        <strong>{lead.business_name}</strong>
                        <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
                          Submitted {formatDate(lead.submitted_at)}
                        </p>
                      </td>
                      <td>{researcherMap.get(lead.researcher_id) ?? "Unknown"}</td>
                      <td>
                        {commission ? (
                          <div className="stack" style={{ gap: "0.45rem" }}>
                            <StatusBadge
                              label={commission.status}
                              tone={getCommissionTone(commission.status)}
                            />
                            <span className="helper-text">
                              {commission.package_name || "Package not set"} -{" "}
                              {formatCurrency(commission.commission_amount)}
                            </span>
                          </div>
                        ) : (
                          <span className="helper-text">No commission record yet</span>
                        )}
                      </td>
                      <td>
                        <form action={saveCommissionAction} className="stack" style={{ gap: "0.65rem" }}>
                          <input type="hidden" name="lead_id" value={lead.id} />
                          <input type="hidden" name="commission_id" value={commission?.id ?? ""} />
                          <input
                            name="package_name"
                            defaultValue={commission?.package_name ?? lead.recommended_service}
                            placeholder="Package"
                          />
                          <div className="field-grid">
                            <input
                              name="project_amount"
                              type="number"
                              min={0}
                              defaultValue={commission?.project_amount ?? ""}
                              placeholder="Project amount"
                            />
                            <input
                              name="commission_amount"
                              type="number"
                              min={0}
                              defaultValue={commission?.commission_amount ?? ""}
                              placeholder="Commission amount"
                            />
                          </div>
                          <div className="field-grid">
                            <select name="status" defaultValue={commission?.status ?? "Pending"}>
                              {commissionStatuses.map((status) => (
                                <option key={status} value={status}>
                                  {status}
                                </option>
                              ))}
                            </select>
                            <input
                              name="paid_date"
                              type="date"
                              defaultValue={commission?.paid_date?.slice(0, 10) ?? ""}
                            />
                          </div>
                          <textarea
                            name="notes"
                            defaultValue={commission?.notes ?? ""}
                            placeholder="Notes"
                          />
                          <FormSubmitButton
                            label="Save Commission"
                            pendingLabel="Saving..."
                            variant="secondary"
                          />
                        </form>
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
