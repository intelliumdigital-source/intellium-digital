import {
  EmptyState,
  ExternalTextLink,
  GhostLink,
  PrimaryLink,
  SmallList,
  StatCard,
  Surface,
} from "@/app/_components/ui";
import { FeedPostCard } from "@/app/_components/feed-post-card";
import {
  FollowBusinessForm,
  FollowProfileForm,
  ReportAndBlockPanel,
} from "@/app/_components/profile-management";
import type {
  BusinessView,
  FeedPostView,
  ProfileView,
  ServiceListingView,
} from "@/lib/social/types";

export function PersonProfileView({
  person,
  recentPosts,
  matchingServices,
}: {
  person: ProfileView;
  recentPosts: FeedPostView[];
  matchingServices: ServiceListingView[];
}) {
  return (
    <div className="space-y-6">
      <Surface className="overflow-hidden">
        <div className="premium-grid absolute inset-0 opacity-35" />
        <div className="relative flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center whitespace-nowrap rounded-full border border-cyan/40 bg-cyan/12 px-3 py-1 text-xs font-medium text-cyan">
                {person.authorType}
              </span>
              <span className="inline-flex items-center whitespace-nowrap rounded-full border border-border bg-white/4 px-3 py-1 text-xs font-medium text-muted-strong">
                {person.focusCategory}
              </span>
              <span className="inline-flex items-center whitespace-nowrap rounded-full border border-border bg-white/4 px-3 py-1 text-xs font-medium text-muted-strong">
                {person.location}
              </span>
            </div>
            <h1 className="mt-4 font-heading text-4xl font-semibold text-white">
              {person.fullName}
            </h1>
            <p className="mt-2 text-lg text-muted-strong">{person.role}</p>
            <p className="mt-4 max-w-2xl text-sm leading-7 text-muted">{person.bio}</p>
            <p className="mt-4 max-w-2xl text-sm leading-7 text-muted-strong">
              {person.contactPreference}
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <GhostLink href={`/messages?with=${person.slug}`}>Contact</GhostLink>
            <FollowProfileForm profile={person} />
          </div>
        </div>
        <div className="mt-6 flex flex-wrap gap-2">
          {person.skills.length > 0 ? (
            person.skills.map((skill) => (
              <span
                key={skill}
                className="inline-flex items-center whitespace-nowrap rounded-full border border-border bg-white/4 px-3 py-1 text-xs font-medium text-muted-strong"
              >
                {skill}
              </span>
            ))
          ) : (
            <span className="text-sm text-muted">No services or specialties published yet.</span>
          )}
        </div>
      </Surface>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          label="Followers"
          value={person.stats.followers.toLocaleString("en-US")}
        />
        <StatCard label="Posts" value={person.stats.posts.toString()} />
        <StatCard label="Services" value={person.stats.services.toString()} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-4">
          <Surface>
            <h2 className="font-heading text-2xl font-semibold text-white">Recent posts</h2>
            <p className="mt-2 text-sm text-muted">
              Live Supabase posts, comments, and likes connected to this profile.
            </p>
          </Surface>
          {recentPosts.length > 0 ? (
            recentPosts.map((post) => <FeedPostCard key={post.id} post={post} />)
          ) : (
            <EmptyState
              eyebrow="Posts"
              title="No public posts yet"
              description="This member has not published a post yet, or their recent posts are private."
            />
          )}
        </div>

        <div className="space-y-4">
          {matchingServices.length > 0 ? (
            <SmallList
              title="Skills and services"
              items={matchingServices.map((service) => `${service.title} | ${service.price}`)}
            />
          ) : (
            <EmptyState
              eyebrow="Services"
              title="No featured service cards yet"
              description="This profile is live, but its services section is still empty."
            />
          )}

          {person.websiteUrl ? (
            <Surface>
              <h3 className="font-heading text-lg font-semibold text-white">Website</h3>
              <div className="mt-4 text-sm text-muted-strong">
                <ExternalTextLink href={person.websiteUrl}>{person.websiteUrl}</ExternalTextLink>
              </div>
            </Surface>
          ) : null}

          {!person.isOwn ? (
            <Surface>
              <h3 className="font-heading text-lg font-semibold text-white">Safety tools</h3>
              <p className="mt-3 text-sm leading-7 text-muted">
                Report or block this member without leaving the profile.
              </p>
              <div className="mt-4">
                <ReportAndBlockPanel
                  targetType="profile"
                  targetId={person.userId}
                  reportedUserId={person.userId}
                  blockedUserId={person.userId}
                />
              </div>
            </Surface>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export function BusinessProfileView({
  business,
  recentPosts,
  businessServices,
}: {
  business: BusinessView;
  recentPosts: FeedPostView[];
  businessServices: ServiceListingView[];
}) {
  return (
    <div className="space-y-6">
      <Surface className="overflow-hidden">
        <div className="premium-grid absolute inset-0 opacity-35" />
        <div className="relative flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center whitespace-nowrap rounded-full border border-cyan/40 bg-cyan/12 px-3 py-1 text-xs font-medium text-cyan">
                {business.category}
              </span>
              <span className="inline-flex items-center whitespace-nowrap rounded-full border border-border bg-white/4 px-3 py-1 text-xs font-medium text-muted-strong">
                {business.location}
              </span>
            </div>
            <h1 className="mt-4 font-heading text-4xl font-semibold text-white">
              {business.businessName}
            </h1>
            <p className="mt-4 max-w-3xl text-sm leading-7 text-muted">
              {business.description}
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <GhostLink href={`/messages?with=${business.slug}`}>Contact</GhostLink>
            <FollowBusinessForm business={business} />
          </div>
        </div>
      </Surface>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          label="Followers"
          value={business.stats.followers.toLocaleString("en-US")}
        />
        <StatCard label="Services" value={business.stats.services.toString()} />
        <StatCard label="Posts" value={business.stats.posts.toString()} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="space-y-4">
          <Surface>
            <h2 className="font-heading text-2xl font-semibold text-white">Recent posts</h2>
            <p className="mt-2 text-sm text-muted">
              Business updates, offers, and local community signals.
            </p>
          </Surface>
          {recentPosts.length > 0 ? (
            recentPosts.map((post) => <FeedPostCard key={post.id} post={post} />)
          ) : (
            <EmptyState
              eyebrow="Posts"
              title="No business posts yet"
              description="This business profile is live, but there are no public business posts yet."
            />
          )}
        </div>

        <div className="space-y-4">
          {businessServices.length > 0 ? (
            <SmallList
              title="Services offered"
              items={businessServices.map((service) => `${service.title} | ${service.price}`)}
            />
          ) : business.servicesOffered.length > 0 ? (
            <SmallList title="Services offered" items={business.servicesOffered} />
          ) : (
            <EmptyState
              eyebrow="Services"
              title="No active services published"
              description="This business page is public, but no active service cards are visible yet."
            />
          )}

          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">Contact details</h3>
            <div className="mt-4 space-y-3 text-sm text-muted-strong">
              {business.contactEmail ? <p>{business.contactEmail}</p> : null}
              {business.contactPhone ? <p>{business.contactPhone}</p> : null}
              {business.website ? (
                <ExternalTextLink href={business.website}>{business.website}</ExternalTextLink>
              ) : null}
              {business.facebook ? (
                <ExternalTextLink href={business.facebook}>{business.facebook}</ExternalTextLink>
              ) : null}
              {!business.contactEmail && !business.contactPhone && !business.website && !business.facebook ? (
                <p>No contact details published yet.</p>
              ) : null}
            </div>
          </Surface>

          {!business.isOwn ? (
            <Surface>
              <h3 className="font-heading text-lg font-semibold text-white">Safety tools</h3>
              <p className="mt-3 text-sm leading-7 text-muted">
                Report or block this business from the authenticated workspace.
              </p>
              <div className="mt-4">
                <ReportAndBlockPanel
                  targetType="business"
                  targetId={business.id}
                  reportedUserId={business.userId}
                  blockedUserId={business.userId}
                />
              </div>
            </Surface>
          ) : null}

          <PrimaryLink href={`/services?q=${encodeURIComponent(business.businessName)}`}>
            View related services
          </PrimaryLink>
        </div>
      </div>
    </div>
  );
}
