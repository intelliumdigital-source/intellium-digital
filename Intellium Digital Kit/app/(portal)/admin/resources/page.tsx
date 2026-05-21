import { AnnouncementForm } from "@/components/forms/announcement-form";
import { ResourceForm } from "@/components/forms/resource-form";
import { SetupNotice } from "@/components/shared/setup-notice";
import { requireRole } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Announcement, ResourceItem } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function AdminResourcesPage() {
  const session = await requireRole(["admin"]);

  if (!session.configured) {
    return <SetupNotice />;
  }

  const supabase = await createServerSupabaseClient();
  const [{ data: resourcesData }, { data: announcementsData }] = await Promise.all([
    supabase
      .from("resource_items")
      .select("*")
      .order("category", { ascending: true })
      .order("order_index", { ascending: true }),
    supabase.from("announcements").select("*").order("updated_at", { ascending: false })
  ]);

  const resources = (resourcesData ?? []) as ResourceItem[];
  const announcements = (announcementsData ?? []) as Announcement[];

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <p className="eyebrow">Admin Resources</p>
        <h1 className="title">Training hub resources and announcements</h1>
        <p className="subtitle">
          Maintain the Outreach Kit training center here. Researchers only see published content,
          so use these resource entries to update onboarding, workflow, scripts, pricing replies,
          image guidance, handoff rules, commission policy, report templates, and FAQ content.
        </p>
      </section>

      <section className="grid grid-2">
        <div className="stack">
          <div>
            <h2 className="section-title">Create Resource</h2>
            <p className="section-description">
              Add or replace section content for the training hub. Use the category field to place
              the content under the correct Outreach Kit section.
            </p>
          </div>
          <ResourceForm />
        </div>

        <div className="stack">
          <div>
            <h2 className="section-title">Post Announcement</h2>
            <p className="section-description">
              Publish admin notes to the announcement feed.
            </p>
          </div>
          <AnnouncementForm />
        </div>
      </section>

      <section className="stack">
        <div>
          <h2 className="section-title">Existing Resources</h2>
          <p className="section-description">Edit any existing resource entry.</p>
        </div>
        <div className="grid grid-2">
          {resources.map((resource) => (
            <ResourceForm key={resource.id} resource={resource} />
          ))}
        </div>
      </section>

      <section className="stack">
        <div>
          <h2 className="section-title">Existing Announcements</h2>
          <p className="section-description">Update pinned state, publishing, or copy.</p>
        </div>
        <div className="grid grid-2">
          {announcements.map((announcement) => (
            <AnnouncementForm key={announcement.id} announcement={announcement} />
          ))}
        </div>
      </section>
    </div>
  );
}
