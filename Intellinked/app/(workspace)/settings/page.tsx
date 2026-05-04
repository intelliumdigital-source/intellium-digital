import {
  BlockedUsersPanel,
  BusinessProfileEditor,
  ProfileEditor,
} from "@/app/_components/profile-management";
import { PageIntro, Pill, Surface } from "@/app/_components/ui";
import { requireSessionUser } from "@/lib/auth/session";
import { getProfilePageData } from "@/lib/social/queries";

const preferenceGroups = [
  {
    title: "Visibility controls",
    items: [
      "Public profile flag is saved to Supabase",
      "Business profile visibility is saved separately",
      "Blocked users are filtered out of the feed where practical",
    ],
  },
  {
    title: "Data readiness",
    items: [
      "Profile edits update the live workspace",
      "Services now publish into the directory",
      "Business profile changes reflect on public business pages",
    ],
  },
  {
    title: "Safety controls",
    items: [
      "Report workflow is stored in Supabase",
      "Admin-only moderation remains protected",
      "No service role key is exposed to the app",
    ],
  },
];

export default async function SettingsPage() {
  const user = await requireSessionUser();
  const data = await getProfilePageData(user.id);

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Settings"
        title="Manage profile visibility, business details, and trust controls."
        description="Settings now updates the same live Supabase-backed profile foundation used by the rest of the authenticated workspace."
      />

      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <ProfileEditor viewer={data.viewer} returnPath="/settings" />

        <div className="grid gap-6 xl:grid-cols-3">
          {preferenceGroups.map((group) => (
            <Surface key={group.title}>
              <div className="flex items-center justify-between">
                <h2 className="font-heading text-xl font-semibold text-white">{group.title}</h2>
                <Pill active>Live</Pill>
              </div>
              <div className="mt-5 space-y-3">
                {group.items.map((item) => (
                  <div
                    key={item}
                    className="premium-card-soft rounded-3xl p-4 text-sm text-muted-strong"
                  >
                    {item}
                  </div>
                ))}
              </div>
            </Surface>
          ))}
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <BlockedUsersPanel blockedUsers={data.blockedUsers} />
        <BusinessProfileEditor business={data.business} returnPath="/settings" />
      </div>
    </div>
  );
}
