import {
  blockUserAction,
  toggleFollowBusinessAction,
  toggleFollowProfileAction,
  unblockUserAction,
  updateProfileAction,
  upsertBusinessProfileAction,
  upsertServiceAction,
  deleteServiceAction,
  createReportAction,
} from "@/app/actions/workspace";
import { EmptyState, Pill, Surface } from "@/app/_components/ui";
import { categories } from "@/app/_data/mock-data";
import type {
  BlockedProfileView,
  BusinessView,
  ProfileView,
  ServiceListingView,
  ViewerWorkspace,
} from "@/lib/social/types";

export function ProfileEditor({
  viewer,
  returnPath,
}: {
  viewer: ViewerWorkspace;
  returnPath: string;
}) {
  return (
    <Surface>
      <div className="flex items-center justify-between gap-3">
        <div>
          <h2 className="font-heading text-2xl font-semibold text-white">Profile basics</h2>
          <p className="mt-2 text-sm text-muted">
            These details are now saved in Supabase and used across the feed, explore, and profile pages.
          </p>
        </div>
        <Pill active>Live</Pill>
      </div>

      <form action={updateProfileAction} className="mt-5 grid gap-4 sm:grid-cols-2">
        <input type="hidden" name="return_path" value={returnPath} />
        <label className="text-sm text-muted-strong">
          Display name
          <input
            name="display_name"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={viewer.displayName}
          />
        </label>
        <label className="text-sm text-muted-strong">
          Username
          <input
            name="username"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={viewer.username ?? ""}
            placeholder="your-public-handle"
          />
        </label>
        <label className="text-sm text-muted-strong">
          Account type
          <select
            name="account_type"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={viewer.accountType}
          >
            <option value="Professional" className="bg-slate-950">
              Professional
            </option>
            <option value="Business" className="bg-slate-950">
              Business
            </option>
            <option value="Freelancer" className="bg-slate-950">
              Freelancer
            </option>
            <option value="Customer" className="bg-slate-950">
              Customer
            </option>
          </select>
        </label>
        <label className="text-sm text-muted-strong">
          Location
          <input
            name="location"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={viewer.location}
          />
        </label>
        <label className="text-sm text-muted-strong sm:col-span-2">
          Website URL
          <input
            name="website_url"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={viewer.websiteUrl ?? ""}
            placeholder="https://your-site.com"
          />
        </label>
        <label className="text-sm text-muted-strong sm:col-span-2">
          Bio
          <textarea
            name="bio"
            rows={5}
            className="input-shell mt-2 w-full rounded-[24px] px-4 py-3 text-white outline-none"
            defaultValue={viewer.bio}
          />
        </label>
        <label className="premium-card-soft sm:col-span-2 flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong">
          <span>Public profile visibility</span>
          <input
            name="is_public"
            type="checkbox"
            defaultChecked={viewer.isPublic}
            className="h-5 w-5 accent-cyan"
          />
        </label>
        <div className="sm:col-span-2">
          <button
            type="submit"
            className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:text-white"
          >
            Save profile
          </button>
        </div>
      </form>
    </Surface>
  );
}

export function BusinessProfileEditor({
  business,
  returnPath,
}: {
  business: BusinessView | null;
  returnPath: string;
}) {
  return (
    <Surface>
      <div className="flex items-center justify-between gap-3">
        <div>
          <h2 className="font-heading text-2xl font-semibold text-white">Business profile</h2>
          <p className="mt-2 text-sm text-muted">
            Create or update the public business page tied to your account.
          </p>
        </div>
        <Pill active={Boolean(business)}>{business ? "Configured" : "Create"}</Pill>
      </div>

      <form action={upsertBusinessProfileAction} className="mt-5 grid gap-4 sm:grid-cols-2">
        <input type="hidden" name="return_path" value={returnPath} />
        <label className="text-sm text-muted-strong sm:col-span-2">
          Business name
          <input
            name="business_name"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.businessName ?? ""}
          />
        </label>
        <label className="text-sm text-muted-strong">
          Public slug
          <input
            name="slug"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.slug ?? ""}
            placeholder="your-business-slug"
          />
        </label>
        <label className="text-sm text-muted-strong">
          Category
          <select
            name="category"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.category ?? "Small businesses"}
          >
            {categories.map((category) => (
              <option key={category} value={category} className="bg-slate-950">
                {category}
              </option>
            ))}
          </select>
        </label>
        <label className="text-sm text-muted-strong">
          Location
          <input
            name="location"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.location ?? ""}
          />
        </label>
        <label className="text-sm text-muted-strong">
          Contact email
          <input
            name="contact_email"
            type="email"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.contactEmail ?? ""}
          />
        </label>
        <label className="text-sm text-muted-strong">
          Contact phone
          <input
            name="contact_phone"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.contactPhone ?? ""}
          />
        </label>
        <label className="text-sm text-muted-strong">
          Website URL
          <input
            name="website_url"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.website ?? ""}
          />
        </label>
        <label className="text-sm text-muted-strong">
          Facebook URL
          <input
            name="facebook_url"
            className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
            defaultValue={business?.facebook ?? ""}
          />
        </label>
        <label className="text-sm text-muted-strong sm:col-span-2">
          Description
          <textarea
            name="description"
            rows={5}
            className="input-shell mt-2 w-full rounded-[24px] px-4 py-3 text-white outline-none"
            defaultValue={business?.description ?? ""}
          />
        </label>
        <label className="premium-card-soft sm:col-span-2 flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong">
          <span>Public business visibility</span>
          <input
            name="is_public"
            type="checkbox"
            defaultChecked={business?.isPublic ?? true}
            className="h-5 w-5 accent-cyan"
          />
        </label>
        <div className="sm:col-span-2">
          <button
            type="submit"
            className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:text-white"
          >
            Save business profile
          </button>
        </div>
      </form>
    </Surface>
  );
}

export function ServiceManager({
  services,
  businessProfileId,
  returnPath,
}: {
  services: ServiceListingView[];
  businessProfileId: string | null;
  returnPath: string;
}) {
  return (
    <div className="space-y-6">
      <Surface>
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="font-heading text-2xl font-semibold text-white">Create a service</h2>
            <p className="mt-2 text-sm text-muted">
              Add service cards that will appear in the live services directory.
            </p>
          </div>
          <Pill active>Supabase-backed</Pill>
        </div>

        <form action={upsertServiceAction} className="mt-5 grid gap-4 sm:grid-cols-2">
          <input type="hidden" name="return_path" value={returnPath} />
          <input type="hidden" name="business_profile_id" value={businessProfileId ?? ""} />
          <label className="text-sm text-muted-strong sm:col-span-2">
            Title
            <input
              name="title"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="Launch-ready Website Sprint"
            />
          </label>
          <label className="text-sm text-muted-strong">
            Category
            <select
              name="category"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              defaultValue="Digital services"
            >
              {categories.map((category) => (
                <option key={category} value={category} className="bg-slate-950">
                  {category}
                </option>
              ))}
            </select>
          </label>
          <label className="text-sm text-muted-strong">
            Location
            <input
              name="location"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="Makati City"
            />
          </label>
          <label className="text-sm text-muted-strong">
            Price label
            <input
              name="price_label"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="Starts at PHP 25,000"
            />
          </label>
          <label className="text-sm text-muted-strong">
            Availability
            <input
              name="availability"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="2 slots this month"
            />
          </label>
          <label className="text-sm text-muted-strong sm:col-span-2">
            Summary
            <textarea
              name="summary"
              rows={4}
              className="input-shell mt-2 w-full rounded-[24px] px-4 py-3 text-white outline-none"
              placeholder="Explain what the service includes and who it is for."
            />
          </label>
          <label className="premium-card-soft flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong">
            <span>Visible publicly</span>
            <input name="is_public" type="checkbox" defaultChecked className="h-5 w-5 accent-cyan" />
          </label>
          <label className="premium-card-soft flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong">
            <span>Active listing</span>
            <input name="is_active" type="checkbox" defaultChecked className="h-5 w-5 accent-cyan" />
          </label>
          <div className="sm:col-span-2">
            <button
              type="submit"
              className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:text-white"
            >
              Publish service
            </button>
          </div>
        </form>
      </Surface>

      {services.length === 0 ? (
        <EmptyState
          eyebrow="Services"
          title="No services published yet"
          description="Create your first live listing to start appearing in the intellinked services directory."
        />
      ) : (
        services.map((service) => (
          <Surface key={service.id}>
            <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <div className="flex flex-wrap gap-2">
                  <Pill active>{service.category}</Pill>
                  <Pill>{service.location}</Pill>
                </div>
                <h3 className="mt-3 font-heading text-xl font-semibold text-white">
                  {service.title}
                </h3>
                <p className="mt-3 text-sm leading-7 text-muted-strong">{service.summary}</p>
              </div>
              <form action={deleteServiceAction}>
                <input type="hidden" name="service_id" value={service.id} />
                <button className="rounded-full border border-danger/25 bg-danger/10 px-4 py-2 text-sm text-danger hover:text-white">
                  Delete
                </button>
              </form>
            </div>

            <form action={upsertServiceAction} className="mt-5 grid gap-4 sm:grid-cols-2">
              <input type="hidden" name="return_path" value={returnPath} />
              <input type="hidden" name="service_id" value={service.id} />
              <input type="hidden" name="business_profile_id" value={service.businessProfileId ?? ""} />
              <label className="text-sm text-muted-strong sm:col-span-2">
                Title
                <input
                  name="title"
                  className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                  defaultValue={service.title}
                />
              </label>
              <label className="text-sm text-muted-strong">
                Category
                <select
                  name="category"
                  className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                  defaultValue={service.category}
                >
                  {categories.map((category) => (
                    <option key={category} value={category} className="bg-slate-950">
                      {category}
                    </option>
                  ))}
                </select>
              </label>
              <label className="text-sm text-muted-strong">
                Location
                <input
                  name="location"
                  className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                  defaultValue={service.location}
                />
              </label>
              <label className="text-sm text-muted-strong">
                Price label
                <input
                  name="price_label"
                  className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                  defaultValue={service.price}
                />
              </label>
              <label className="text-sm text-muted-strong">
                Availability
                <input
                  name="availability"
                  className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                  defaultValue={service.availability}
                />
              </label>
              <label className="text-sm text-muted-strong sm:col-span-2">
                Summary
                <textarea
                  name="summary"
                  rows={4}
                  className="input-shell mt-2 w-full rounded-[24px] px-4 py-3 text-white outline-none"
                  defaultValue={service.summary}
                />
              </label>
              <label className="premium-card-soft flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong">
                <span>Visible publicly</span>
                <input
                  name="is_public"
                  type="checkbox"
                  defaultChecked={service.isPublic}
                  className="h-5 w-5 accent-cyan"
                />
              </label>
              <label className="premium-card-soft flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong">
                <span>Active listing</span>
                <input
                  name="is_active"
                  type="checkbox"
                  defaultChecked={service.isActive}
                  className="h-5 w-5 accent-cyan"
                />
              </label>
              <div className="sm:col-span-2">
                <button
                  type="submit"
                  className="rounded-full border border-border bg-white/4 px-5 py-3 text-sm font-medium text-muted-strong hover:text-white"
                >
                  Update service
                </button>
              </div>
            </form>
          </Surface>
        ))
      )}
    </div>
  );
}

export function FollowProfileForm({ profile }: { profile: ProfileView }) {
  if (profile.isOwn) {
    return null;
  }

  return (
    <form action={toggleFollowProfileAction}>
      <input type="hidden" name="target_user_id" value={profile.userId} />
      <button className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:text-white">
        {profile.isFollowing ? "Unfollow" : "Follow / Connect"}
      </button>
    </form>
  );
}

export function FollowBusinessForm({ business }: { business: BusinessView }) {
  if (business.isOwn) {
    return null;
  }

  return (
    <form action={toggleFollowBusinessAction}>
      <input type="hidden" name="business_profile_id" value={business.id} />
      <input type="hidden" name="business_user_id" value={business.userId} />
      <button className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:text-white">
        {business.isFollowing ? "Unfollow" : "Follow / Connect"}
      </button>
    </form>
  );
}

export function ReportAndBlockPanel({
  targetType,
  targetId,
  reportedUserId,
  blockedUserId,
}: {
  targetType: "profile" | "business" | "service";
  targetId: string;
  reportedUserId: string;
  blockedUserId?: string;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      <form action={createReportAction}>
        <input type="hidden" name="target_type" value={targetType} />
        <input type="hidden" name="target_id" value={targetId} />
        <input type="hidden" name="reported_user_id" value={reportedUserId} />
        <input type="hidden" name="reason" value="Profile or listing needs review" />
        <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
          Report
        </button>
      </form>
      {blockedUserId ? (
        <form action={blockUserAction}>
          <input type="hidden" name="blocked_user_id" value={blockedUserId} />
          <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
            Block
          </button>
        </form>
      ) : null}
    </div>
  );
}

export function BlockedUsersPanel({
  blockedUsers,
}: {
  blockedUsers: BlockedProfileView[];
}) {
  if (blockedUsers.length === 0) {
    return (
      <EmptyState
        eyebrow="Safety"
        title="Blocked users list is still empty"
        description="Anyone you block will be hidden from the feed, explore, and services directory where practical."
      />
    );
  }

  return (
    <Surface>
      <h2 className="font-heading text-2xl font-semibold text-white">Blocked users</h2>
      <div className="mt-5 space-y-3">
        {blockedUsers.map((blockedUser) => (
          <div
            key={blockedUser.userId}
            className="premium-card-soft flex flex-col gap-3 rounded-3xl p-4 sm:flex-row sm:items-center sm:justify-between"
          >
            <div>
              <p className="font-medium text-white">{blockedUser.displayName}</p>
              <p className="mt-1 text-sm text-muted">
                {blockedUser.username ? `@${blockedUser.username}` : "Private member handle not set"}
              </p>
            </div>
            <form action={unblockUserAction}>
              <input type="hidden" name="blocked_user_id" value={blockedUser.userId} />
              <button className="rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
                Unblock
              </button>
            </form>
          </div>
        ))}
      </div>
    </Surface>
  );
}
