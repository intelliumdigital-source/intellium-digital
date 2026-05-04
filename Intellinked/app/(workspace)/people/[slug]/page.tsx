import { notFound } from "next/navigation";

import { PersonProfileView } from "@/app/_components/profile-pages";
import { getPersonBySlug } from "@/app/_data/mock-data";

export default async function PersonPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const person = getPersonBySlug(slug);

  if (!person) {
    notFound();
  }

  return <PersonProfileView person={person} />;
}
