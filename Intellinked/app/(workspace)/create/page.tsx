import { CreatePostStudio } from "@/app/_components/create-post-studio";
import { PageIntro } from "@/app/_components/ui";
import { requireSessionUser } from "@/lib/auth/session";
import { getProfilePageData } from "@/lib/social/queries";

export default async function CreatePage() {
  const user = await requireSessionUser();
  const data = await getProfilePageData(user.id);

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Create post"
        title="Compose a premium post flow with live Supabase publishing."
        description="The full-page composer keeps the same premium intellinked experience, but published posts now go straight into the protected workspace feed."
      />
      <CreatePostStudio
        viewer={data.viewer}
        businessProfileId={data.businessProfileId}
      />
    </div>
  );
}
