import { ServicesDirectory } from "@/app/_components/services-directory";
import { GhostLink, PageIntro, PrimaryLink } from "@/app/_components/ui";

export default function ServicesPage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Services directory"
        title="Browse local offers that are ready to convert into conversations."
        description="The services directory gives businesses and professionals a clear listing surface, while keeping the MVP lightweight and mock-data driven."
        actions={
          <>
            <PrimaryLink href="/create">Promote a service</PrimaryLink>
            <GhostLink href="/explore">Back to explore</GhostLink>
          </>
        }
      />
      <ServicesDirectory />
    </div>
  );
}
