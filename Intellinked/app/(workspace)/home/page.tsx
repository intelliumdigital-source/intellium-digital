import Link from "next/link";

import {
  BusinessCard,
  GhostLink,
  PageIntro,
  Pill,
  PostCard,
  PrimaryLink,
  ProfileCard,
  ServiceCard,
  StatCard,
  Surface,
} from "@/app/_components/ui";
import {
  businesses,
  feedPosts,
  people,
  platformStats,
  services,
} from "@/app/_data/mock-data";

export default function HomePage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Home feed"
        title="A community feed built for practical local opportunities."
        description="The home experience combines social momentum with business intent: discover posts, featured professionals, and active services without relying on live infrastructure yet."
        actions={
          <>
            <PrimaryLink href="/create">Create post</PrimaryLink>
            <GhostLink href="/explore">Explore network</GhostLink>
          </>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {platformStats.map((stat) => (
          <StatCard key={stat.label} label={stat.label} value={stat.value} />
        ))}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-4">
          <Surface>
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="font-heading text-2xl font-semibold text-white">
                  Feed activity
                </h2>
                <p className="mt-2 text-sm text-muted">
                  Mock posts with like, comment, share, connect, and moderation UI.
                </p>
              </div>
              <Pill active>Local-first signal</Pill>
            </div>
          </Surface>

          {feedPosts.slice(0, 6).map((post) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>

        <div className="space-y-4">
          <Surface>
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-heading text-xl font-semibold text-white">
                  Featured professionals
                </h3>
                <p className="mt-2 text-sm text-muted">
                  Recommended people worth connecting with this week.
                </p>
              </div>
              <Link href="/profile" className="text-sm text-cyan hover:text-white">
                View profile
              </Link>
            </div>
          </Surface>

          {people.slice(0, 2).map((person) => (
            <ProfileCard key={person.slug} person={person} />
          ))}

          <BusinessCard business={businesses[0]} />
          <ServiceCard service={services[0]} />
        </div>
      </div>
    </div>
  );
}
