import {
  BlockedUsersPanel,
  BusinessProfileEditor,
  ProfileEditor,
} from "@/app/_components/profile-management";
import { PersonProfileView } from "@/app/_components/profile-pages";
import { requireSessionUser } from "@/lib/auth/session";
import { getProfilePageData } from "@/lib/social/queries";

export default async function ProfilePage() {
  const user = await requireSessionUser();
  const data = await getProfilePageData(user.id);

  return (
    <div className="space-y-6">
      <PersonProfileView
        person={data.profile}
        recentPosts={data.posts}
        matchingServices={data.services}
      />

      <div className="grid gap-6 xl:grid-cols-[1fr_1fr]">
        <ProfileEditor viewer={data.viewer} returnPath="/profile" />
        <BusinessProfileEditor business={data.business} returnPath="/profile" />
      </div>

      <BlockedUsersPanel blockedUsers={data.blockedUsers} />
    </div>
  );
}
