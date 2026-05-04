import Link from "next/link";

import {
  BusinessCard,
  EmptyState,
  GhostLink,
  PageIntro,
  Pill,
  PrimaryLink,
  ProfileCard,
  ServiceCard,
  StatCard,
  Surface,
} from "@/app/_components/ui";
import { FeedPostCard } from "@/app/_components/feed-post-card";
import { requireSessionUser } from "@/lib/auth/session";
import { getHomePageData } from "@/lib/social/queries";

export default async function HomePage() {
  const user = await requireSessionUser();
  const data = await getHomePageData(user.id);

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Home feed"
        title="A community feed built for practical local opportunities."
        description="The home feed is now backed by Supabase profiles, posts, likes, comments, services, and business pages while keeping the premium intellinked layout intact."
        actions={
          <>
            <PrimaryLink href="/create">Create post</PrimaryLink>
            <GhostLink href="/explore">Explore network</GhostLink>
          </>
        }
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {data.stats.map((stat) => (
          <StatCard
            key={stat.label}
            label={stat.label}
            value={stat.value}
            note={stat.note}
          />
        ))}
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-4">
          <Surface>
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="font-heading text-2xl font-semibold text-white">
                  Start a new conversation
                </h2>
                <p className="mt-2 text-sm text-muted">
                  Share an opportunity, promote a service, or ask the community for help.
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <Pill active>Connect</Pill>
                <Pill>Promote</Pill>
                <Pill>Grow</Pill>
              </div>
            </div>
            <div className="mt-5 flex flex-wrap gap-3">
              <PrimaryLink href="/create">Write a post</PrimaryLink>
              <GhostLink href="/services">Browse service demand</GhostLink>
            </div>
          </Surface>

          <Surface>
            <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 className="font-heading text-2xl font-semibold text-white">
                  Feed activity
                </h2>
                <p className="mt-2 text-sm text-muted">
                  Live posts with Supabase-backed like, comment, delete, report, and block actions.
                </p>
              </div>
              <Pill active>Local-first signal</Pill>
            </div>
          </Surface>

          {data.posts.length > 0 ? (
            data.posts.slice(0, 8).map((post) => <FeedPostCard key={post.id} post={post} />)
          ) : (
            <EmptyState
              eyebrow="Feed"
              title="No posts are live yet"
              description="Create the first Supabase-backed post to populate the feed."
              action={<GhostLink href="/create">Open composer</GhostLink>}
            />
          )}
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
                View your profile
              </Link>
            </div>
          </Surface>

          {data.people.slice(0, 2).map((person) => (
            <ProfileCard key={person.slug} person={person} />
          ))}

          {data.businesses[0] ? <BusinessCard business={data.businesses[0]} /> : null}
          {data.services[0] ? <ServiceCard service={data.services[0]} /> : null}
          <EmptyState
            eyebrow="Growth hint"
            title="Need more leads in the feed?"
            description="Mix practical insight posts with a direct service CTA. Profiles with live services and recent posts now stand out fastest."
            action={<GhostLink href="/create">Open composer</GhostLink>}
          />
        </div>
      </div>
    </div>
  );
}
