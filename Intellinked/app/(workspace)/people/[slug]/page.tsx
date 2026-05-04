import { notFound } from "next/navigation";

import { PersonProfileView } from "@/app/_components/profile-pages";
import { requireSessionUser } from "@/lib/auth/session";
import { getProfileBySlug } from "@/lib/social/queries";

export default async function PersonPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const user = await requireSessionUser();
  const { slug } = await params;
  const data = await getProfileBySlug(user.id, slug);

  if (!data) {
    notFound();
  }

  return (
    <PersonProfileView
      person={data.profile}
      recentPosts={data.posts}
      matchingServices={data.services}
    />
  );
}
