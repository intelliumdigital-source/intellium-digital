import { notFound } from "next/navigation";

import { BusinessProfileView } from "@/app/_components/profile-pages";
import { getBusinessBySlug } from "@/app/_data/mock-data";

export default async function BusinessPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const business = getBusinessBySlug(slug);

  if (!business) {
    notFound();
  }

  return <BusinessProfileView business={business} />;
}
