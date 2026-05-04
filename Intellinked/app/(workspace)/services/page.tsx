import { ServicesDirectory } from "@/app/_components/services-directory";
import { GhostLink, PageIntro, PrimaryLink } from "@/app/_components/ui";
import { ServiceManager } from "@/app/_components/profile-management";
import { requireSessionUser } from "@/lib/auth/session";
import { getServicesPageData } from "@/lib/social/queries";

export default async function ServicesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string }>;
}) {
  const user = await requireSessionUser();
  const data = await getServicesPageData(user.id);
  const params = await searchParams;

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Services directory"
        title="Browse local offers that are ready to convert into conversations."
        description="The services directory is now powered by Supabase. Active public services are browseable, and your own listings can be created, edited, and removed here."
        actions={
          <>
            <PrimaryLink href="/create">Promote a service</PrimaryLink>
            <GhostLink href="/explore">Back to explore</GhostLink>
          </>
        }
      />
      <ServicesDirectory
        services={data.services}
        initialQuery={params.q ?? ""}
        initialCategory={params.category ?? "All"}
      />
      <ServiceManager
        services={data.ownServices}
        businessProfileId={data.business?.id ?? null}
        returnPath="/services"
      />
    </div>
  );
}
