import {
  GhostLink,
  ModerationActions,
  Pill,
  PostCard,
  PrimaryLink,
  SmallList,
  StatCard,
  Surface,
} from "@/app/_components/ui";
import type { Business, Person } from "@/app/_data/mock-data";
import { getPostsByIds, people, services } from "@/app/_data/mock-data";

export function PersonProfileView({ person }: { person: Person }) {
  const recentPosts = getPostsByIds(person.recentPostIds);
  const matchingServices = services.filter(
    (service) => service.providerSlug === person.slug,
  );
  const recommendations = people.filter((candidate) => candidate.slug !== person.slug).slice(0, 3);

  return (
    <div className="space-y-6">
      <Surface>
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <Pill active>{person.authorType}</Pill>
              <Pill>{person.location}</Pill>
            </div>
            <h1 className="mt-4 font-heading text-4xl font-semibold text-white">
              {person.fullName}
            </h1>
            <p className="mt-2 text-lg text-muted-strong">{person.role}</p>
            <p className="mt-4 max-w-2xl text-sm leading-7 text-muted">{person.bio}</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <GhostLink href="/messages">Contact</GhostLink>
            <PrimaryLink href="/messages">Follow / Connect</PrimaryLink>
          </div>
        </div>
        <div className="mt-6 flex flex-wrap gap-2">
          {person.skills.map((skill) => (
            <Pill key={skill}>{skill}</Pill>
          ))}
        </div>
      </Surface>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          label="Followers"
          value={person.stats.followers.toLocaleString("en-US")}
        />
        <StatCard
          label="Connections"
          value={person.stats.connections.toLocaleString("en-US")}
        />
        <StatCard
          label="Opportunity wins"
          value={person.stats.opportunities.toString()}
        />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-4">
          <Surface>
            <h2 className="font-heading text-2xl font-semibold text-white">Recent posts</h2>
            <p className="mt-2 text-sm text-muted">
              Local-first activity, partnerships, and opportunity signals.
            </p>
          </Surface>
          {recentPosts.map((post) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>

        <div className="space-y-4">
          <SmallList
            title="Recommended collaborators"
            items={recommendations.map(
              (candidate) => `${candidate.fullName} • ${candidate.role} • ${candidate.location}`,
            )}
          />

          <SmallList
            title="Skills and services"
            items={
              matchingServices.length > 0
                ? matchingServices.map((service) => `${service.title} • ${service.price}`)
                : person.skills
            }
          />

          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">Safety tools</h3>
            <p className="mt-3 text-sm leading-7 text-muted">
              Trust and moderation are visible by design in the MVP, even before full backend workflows are connected.
            </p>
            <div className="mt-4">
              <ModerationActions />
            </div>
          </Surface>
        </div>
      </div>
    </div>
  );
}

export function BusinessProfileView({ business }: { business: Business }) {
  const recentPosts = getPostsByIds(business.recentPostIds);

  return (
    <div className="space-y-6">
      <Surface>
        <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <Pill active>{business.category}</Pill>
              <Pill>{business.location}</Pill>
            </div>
            <h1 className="mt-4 font-heading text-4xl font-semibold text-white">
              {business.businessName}
            </h1>
            <p className="mt-4 max-w-3xl text-sm leading-7 text-muted">
              {business.description}
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <GhostLink href="/messages">Contact</GhostLink>
            <PrimaryLink href="/services">View Service</PrimaryLink>
          </div>
        </div>
      </Surface>

      <div className="grid gap-4 md:grid-cols-3">
        <StatCard
          label="Followers"
          value={business.stats.followers.toLocaleString("en-US")}
        />
        <StatCard label="Leads" value={business.stats.leads.toString()} />
        <StatCard label="Response rate" value={business.stats.responseRate} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="space-y-4">
          <Surface>
            <h2 className="font-heading text-2xl font-semibold text-white">Recent posts</h2>
            <p className="mt-2 text-sm text-muted">
              Business updates, offers, and local community signals.
            </p>
          </Surface>
          {recentPosts.map((post) => (
            <PostCard key={post.id} post={post} />
          ))}
        </div>

        <div className="space-y-4">
          <SmallList title="Services offered" items={business.servicesOffered} />

          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">Contact details</h3>
            <div className="mt-4 space-y-3 text-sm text-muted-strong">
              <p>{business.contactDetails}</p>
              <a
                href={business.website}
                target="_blank"
                rel="noreferrer"
                className="block text-cyan hover:text-white"
              >
                {business.website}
              </a>
              <a
                href={business.facebook}
                target="_blank"
                rel="noreferrer"
                className="block text-cyan hover:text-white"
              >
                {business.facebook}
              </a>
            </div>
          </Surface>

          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">Moderation tools</h3>
            <p className="mt-3 text-sm leading-7 text-muted">
              Businesses can be reported and reviewed with visible queue status from the admin side.
            </p>
            <div className="mt-4">
              <ModerationActions />
            </div>
          </Surface>
        </div>
      </div>
    </div>
  );
}
