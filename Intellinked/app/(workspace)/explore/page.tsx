import { ExploreDirectory } from "@/app/_components/explore-directory";
import { GhostLink, PageIntro, PrimaryLink } from "@/app/_components/ui";
import { requireSessionUser } from "@/lib/auth/session";
import { getExplorePageData } from "@/lib/social/queries";

export default async function ExplorePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string }>;
}) {
  const user = await requireSessionUser();
  const data = await getExplorePageData(user.id);
  const params = await searchParams;

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Explore"
        title="Search people, businesses, and service offers."
        description="Discovery now reads live Supabase profiles, business pages, and service listings while preserving the premium explore experience."
        actions={
          <>
            <PrimaryLink href="/services">Open services</PrimaryLink>
            <GhostLink href="/create">Post an opportunity</GhostLink>
          </>
        }
      />
      <ExploreDirectory
        people={data.people}
        businesses={data.businesses}
        services={data.services}
        initialQuery={params.q ?? ""}
        initialCategory={params.category ?? "All"}
      />
    </div>
  );
}
