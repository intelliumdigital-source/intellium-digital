import { notFound } from "next/navigation";

import { BusinessProfileView } from "@/app/_components/profile-pages";
import { requireSessionUser } from "@/lib/auth/session";
import { getBusinessBySlug } from "@/lib/social/queries";

export default async function BusinessPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const user = await requireSessionUser();
  const { slug } = await params;
  const data = await getBusinessBySlug(user.id, slug);

  if (!data) {
    notFound();
  }

  return (
    <BusinessProfileView
      business={data.business}
      recentPosts={data.posts}
      businessServices={data.services}
    />
  );
}
