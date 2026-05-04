import { ExploreDirectory } from "@/app/_components/explore-directory";
import { GhostLink, PageIntro, PrimaryLink } from "@/app/_components/ui";

export default async function ExplorePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string }>;
}) {
  const params = await searchParams;

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Explore"
        title="Search people, businesses, and service offers."
        description="Discovery is where intellinked proves local relevance. Everything here runs on mock data, but the experience is structured like a real social marketplace."
        actions={
          <>
            <PrimaryLink href="/services">Open services</PrimaryLink>
            <GhostLink href="/create">Post an opportunity</GhostLink>
          </>
        }
      />
      <ExploreDirectory
        initialQuery={params.q ?? ""}
        initialCategory={params.category ?? "All"}
      />
    </div>
  );
}
