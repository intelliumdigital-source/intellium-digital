import { EmptyState } from "@/components/shared/empty-state";
import { SetupNotice } from "@/components/shared/setup-notice";
import { StatusBadge } from "@/components/shared/status-badge";
import { requireAuthenticatedProfile } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Announcement } from "@/lib/types";
import { formatDate } from "@/lib/utils";

export default async function AnnouncementsPage() {
  const session = await requireAuthenticatedProfile();

  if (!session.configured) {
    return <SetupNotice />;
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("announcements")
    .select("*")
    .eq("is_published", true)
    .order("is_pinned", { ascending: false })
    .order("published_at", { ascending: false });

  const announcements = (data ?? []) as Announcement[];

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <p className="eyebrow">Announcements</p>
        <h1 className="title">Updates from admin</h1>
        <p className="subtitle">
          Check for pricing clarifications, new scripts, compliance reminders, and campaign updates.
        </p>
      </section>

      {announcements.length === 0 ? (
        <EmptyState
          title="No announcements posted"
          description="Admin updates will appear here once they are published."
        />
      ) : (
        <div className="stack">
          {announcements.map((announcement) => (
            <article key={announcement.id} className="card">
              <div className="page-header" style={{ marginBottom: "0.75rem" }}>
                <div>
                  <h2 className="section-title" style={{ marginBottom: "0.25rem" }}>
                    {announcement.title}
                  </h2>
                  <p className="helper-text">{formatDate(announcement.published_at)}</p>
                </div>
                {announcement.is_pinned ? (
                  <StatusBadge label="Pinned" tone="info" />
                ) : null}
              </div>
              <p
                style={{
                  margin: 0,
                  whiteSpace: "pre-wrap",
                  lineHeight: 1.8,
                  color: "var(--text-soft)"
                }}
              >
                {announcement.content}
              </p>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
