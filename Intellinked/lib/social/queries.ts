import "server-only";

import { cache } from "react";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import type {
  AccountTypeLabel,
  BlockedProfileView,
  BusinessView,
  FeedPostView,
  ModerationReportView,
  ProfileView,
  ServiceListingView,
  ViewerWorkspace,
} from "@/lib/social/types";

type ProfileRow = {
  id: string;
  user_id: string;
  username: string | null;
  display_name: string | null;
  account_type: string;
  location: string | null;
  bio: string | null;
  website_url: string | null;
  is_public: boolean;
  is_admin: boolean;
};

type BusinessProfileRow = {
  id: string;
  user_id: string;
  profile_id: string;
  business_name: string;
  slug: string | null;
  category: string | null;
  location: string | null;
  description: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  website_url: string | null;
  facebook_url: string | null;
  is_public: boolean;
};

type PostRow = {
  id: string;
  user_id: string;
  business_profile_id: string | null;
  author_type: string;
  category: string | null;
  content: string;
  cta: "Connect" | "Message" | "View Service";
  visibility: string;
  is_published: boolean;
  created_at: string;
};

type LikeRow = {
  post_id: string;
  user_id: string;
};

type CommentRow = {
  id: string;
  post_id: string;
  user_id: string;
  content: string;
  created_at: string;
};

type FollowRow = {
  follower_id: string;
  following_user_id: string | null;
  following_business_profile_id: string | null;
};

type ServiceRow = {
  id: string;
  user_id: string;
  business_profile_id: string | null;
  title: string;
  category: string | null;
  location: string | null;
  summary: string | null;
  price_label: string | null;
  availability: string | null;
  is_public: boolean;
  is_active: boolean;
  created_at: string;
};

type ReportRow = {
  id: string;
  status: "pending" | "in_review" | "resolved" | "dismissed";
  reason: string;
  details: string | null;
  reporter_user_id: string;
  reported_user_id: string | null;
  post_id: string | null;
  comment_id: string | null;
  service_id: string | null;
  business_profile_id: string | null;
  created_at: string;
};

type NotificationRow = {
  id: string;
  title: string;
  body: string | null;
  type: string;
  is_read: boolean;
  created_at: string;
};

type ViewerWorkspaceBundle = {
  viewer: ViewerWorkspace;
  business: BusinessView | null;
  posts: FeedPostView[];
  services: ServiceListingView[];
  blockedUsers: BlockedProfileView[];
};

function ensureArray<T>(value: T[] | null | undefined) {
  return value ?? [];
}

function formatRelativeTime(value: string) {
  const date = new Date(value);
  const diffMs = date.getTime() - Date.now();
  const absSeconds = Math.abs(Math.round(diffMs / 1000));
  const formatter = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

  if (absSeconds < 60) {
    return formatter.format(Math.round(diffMs / 1000), "second");
  }

  const absMinutes = Math.abs(Math.round(diffMs / 60000));
  if (absMinutes < 60) {
    return formatter.format(Math.round(diffMs / 60000), "minute");
  }

  const absHours = Math.abs(Math.round(diffMs / 3600000));
  if (absHours < 24) {
    return formatter.format(Math.round(diffMs / 3600000), "hour");
  }

  const absDays = Math.abs(Math.round(diffMs / 86400000));
  if (absDays < 7) {
    return formatter.format(Math.round(diffMs / 86400000), "day");
  }

  return new Intl.DateTimeFormat("en-PH", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

function humanizeAccountType(value: string): AccountTypeLabel {
  switch (value) {
    case "business":
      return "Business";
    case "freelancer":
      return "Freelancer";
    case "customer":
      return "Customer";
    default:
      return "Professional";
  }
}

function firstDefinedString(...values: Array<string | null | undefined>) {
  return values.find((value) => Boolean(value && value.trim())) ?? "";
}

function buildCountMap(values: string[]) {
  return values.reduce<Record<string, number>>((accumulator, value) => {
    accumulator[value] = (accumulator[value] ?? 0) + 1;
    return accumulator;
  }, {});
}

async function getBlockedUserIds(userId: string) {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("blocks")
    .select("blocked_user_id")
    .eq("blocker_user_id", userId);

  return new Set(ensureArray(data).map((row) => row.blocked_user_id as string));
}

const getViewerProfileRow = cache(async (userId: string) => {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("profiles")
    .select(
      "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
    )
    .eq("user_id", userId)
    .single();

  if (error || !data) {
    throw new Error("Could not load the signed-in profile.");
  }

  return data as ProfileRow;
});

function mapViewerWorkspace(profile: ProfileRow): ViewerWorkspace {
  return {
    userId: profile.user_id,
    profileId: profile.id,
    displayName: profile.display_name ?? "Member",
    username: profile.username,
    accountType: humanizeAccountType(profile.account_type),
    location: profile.location ?? "Philippines",
    bio: profile.bio ?? "",
    websiteUrl: profile.website_url,
    isPublic: profile.is_public,
    isAdmin: profile.is_admin,
  };
}

async function getProfilesByUserIds(userIds: string[]) {
  if (userIds.length === 0) {
    return [] as ProfileRow[];
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("profiles")
    .select(
      "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
    )
    .in("user_id", userIds);

  return ensureArray(data) as ProfileRow[];
}

async function getBusinessProfilesByIds(ids: string[]) {
  if (ids.length === 0) {
    return [] as BusinessProfileRow[];
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("business_profiles")
    .select(
      "id, user_id, profile_id, business_name, slug, category, location, description, contact_email, contact_phone, website_url, facebook_url, is_public",
    )
    .in("id", ids);

  return ensureArray(data) as BusinessProfileRow[];
}

async function getBusinessProfileByUserId(userId: string) {
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("business_profiles")
    .select(
      "id, user_id, profile_id, business_name, slug, category, location, description, contact_email, contact_phone, website_url, facebook_url, is_public",
    )
    .eq("user_id", userId)
    .maybeSingle();

  return (data as BusinessProfileRow | null) ?? null;
}

async function getServicesByUserIds(userIds: string[]) {
  if (userIds.length === 0) {
    return [] as ServiceRow[];
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("services")
    .select(
      "id, user_id, business_profile_id, title, category, location, summary, price_label, availability, is_public, is_active, created_at",
    )
    .in("user_id", userIds);

  return ensureArray(data) as ServiceRow[];
}

async function getPostsByUserIds(userIds: string[]) {
  if (userIds.length === 0) {
    return [] as PostRow[];
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("posts")
    .select(
      "id, user_id, business_profile_id, author_type, category, content, cta, visibility, is_published, created_at",
    )
    .in("user_id", userIds);

  return ensureArray(data) as PostRow[];
}

async function getFollowRowsForUsers(userIds: string[]) {
  if (userIds.length === 0) {
    return [] as FollowRow[];
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("follows")
    .select("follower_id, following_user_id, following_business_profile_id")
    .in("following_user_id", userIds);

  return ensureArray(data) as FollowRow[];
}

async function getFollowRowsForBusinesses(businessIds: string[]) {
  if (businessIds.length === 0) {
    return [] as FollowRow[];
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("follows")
    .select("follower_id, following_user_id, following_business_profile_id")
    .in("following_business_profile_id", businessIds);

  return ensureArray(data) as FollowRow[];
}

function createProfileSlug(profile: ProfileRow) {
  return profile.username ?? profile.id;
}

function createBusinessSlug(business: BusinessProfileRow) {
  return business.slug ?? business.id;
}

function mapServiceTags(service: ServiceRow) {
  return [
    service.category ?? null,
    service.availability ?? null,
    service.location ?? null,
  ].filter(Boolean) as string[];
}

function mapServiceListing(
  service: ServiceRow,
  profilesByUserId: Map<string, ProfileRow>,
  businessesById: Map<string, BusinessProfileRow>,
  viewerUserId: string,
): ServiceListingView {
  const profile = profilesByUserId.get(service.user_id);
  const business = service.business_profile_id
    ? businessesById.get(service.business_profile_id)
    : null;
  const providerType = business
    ? "Business"
    : humanizeAccountType(profile?.account_type ?? "professional");

  return {
    id: service.id,
    userId: service.user_id,
    businessProfileId: service.business_profile_id,
    title: service.title,
    providerName:
      business?.business_name ?? profile?.display_name ?? "intellinked member",
    providerType,
    providerSlug:
      !business && profile ? createProfileSlug(profile) : undefined,
    businessSlug: business ? createBusinessSlug(business) : undefined,
    businessName: business?.business_name,
    category: service.category ?? "Small businesses",
    location: service.location ?? profile?.location ?? "Philippines",
    summary:
      service.summary ??
      "This member has not added a service summary yet.",
    price: service.price_label ?? "Message for pricing",
    availability: service.availability ?? "Availability on request",
    tags: mapServiceTags(service),
    isOwned: service.user_id === viewerUserId,
    isPublic: service.is_public,
    isActive: service.is_active,
  };
}

function mapProfileView(
  profile: ProfileRow,
  serviceRows: ServiceRow[],
  postRows: PostRow[],
  followerCount: number,
  viewerUserId: string,
  isFollowing: boolean,
): ProfileView {
  const accountType = humanizeAccountType(profile.account_type);
  const visibleServices = serviceRows.filter((service) => service.is_active);
  const leadingCategory =
    visibleServices[0]?.category ?? postRows[0]?.category ?? "Small businesses";

  return {
    id: profile.id,
    userId: profile.user_id,
    slug: createProfileSlug(profile),
    username: profile.username,
    fullName: profile.display_name ?? "intellinked member",
    role:
      accountType === "Professional"
        ? "Professional member"
        : accountType === "Freelancer"
          ? "Freelancer"
          : accountType === "Customer"
            ? "Customer"
            : "Business member",
    authorType:
      accountType === "Business" ? "Professional" : accountType,
    focusCategory: leadingCategory,
    location: profile.location ?? "Philippines",
    bio:
      profile.bio ??
      "This member has not added a public bio yet.",
    skills:
      visibleServices.slice(0, 4).map((service) => service.title) ||
      [],
    contactPreference: profile.website_url
      ? `Best reached through ${profile.website_url}.`
      : "Open to local opportunities, introductions, and direct profile contact.",
    websiteUrl: profile.website_url,
    isPublic: profile.is_public,
    isAdmin: profile.is_admin,
    isOwn: profile.user_id === viewerUserId,
    isFollowing,
    stats: {
      followers: followerCount,
      posts: postRows.length,
      services: visibleServices.length,
    },
  };
}

function mapBusinessView(
  business: BusinessProfileRow,
  serviceRows: ServiceRow[],
  postRows: PostRow[],
  followerCount: number,
  viewerUserId: string,
  isFollowing: boolean,
): BusinessView {
  return {
    id: business.id,
    userId: business.user_id,
    slug: createBusinessSlug(business),
    businessName: business.business_name,
    category: business.category ?? "Small businesses",
    location: business.location ?? "Philippines",
    description:
      business.description ??
      "This business has not added a public description yet.",
    servicesOffered:
      serviceRows.map((service) => service.title).slice(0, 6),
    contactEmail: business.contact_email,
    contactPhone: business.contact_phone,
    website: business.website_url,
    facebook: business.facebook_url,
    isPublic: business.is_public,
    isOwn: business.user_id === viewerUserId,
    isFollowing,
    stats: {
      followers: followerCount,
      services: serviceRows.length,
      posts: postRows.length,
    },
  };
}

export async function getViewerWorkspace(userId: string): Promise<ViewerWorkspaceBundle> {
  const profile = await getViewerProfileRow(userId);
  const businessRow = await getBusinessProfileByUserId(userId);
  const blockedUserIds = await getBlockedUserIds(userId);
  const supabase = await createServerSupabaseClient();

  const { data: postsData } = await supabase
    .from("posts")
    .select(
      "id, user_id, business_profile_id, author_type, category, content, cta, visibility, is_published, created_at",
    )
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  const { data: servicesData } = await supabase
    .from("services")
    .select(
      "id, user_id, business_profile_id, title, category, location, summary, price_label, availability, is_public, is_active, created_at",
    )
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  const businessRows = businessRow ? [businessRow] : [];
  const businessById = new Map(businessRows.map((row) => [row.id, row]));
  const profilesByUserId = new Map([[profile.user_id, profile]]);
  const ownPosts = ensureArray(postsData) as PostRow[];
  const ownServices = ensureArray(servicesData) as ServiceRow[];

  const feedPosts = await mapFeedPosts({
    viewerUserId: userId,
    posts: ownPosts,
    blockedUserIds,
  });

  const blockedUsers = blockedUserIds.size
    ? await getProfilesByUserIds([...blockedUserIds])
    : [];

  return {
    viewer: mapViewerWorkspace(profile),
    business: businessRow
      ? mapBusinessView(
          businessRow,
          ownServices.filter((service) => service.business_profile_id === businessRow.id),
          ownPosts.filter((post) => post.business_profile_id === businessRow.id),
          0,
          userId,
          false,
        )
      : null,
    posts: feedPosts,
    services: ownServices.map((service) =>
      mapServiceListing(service, profilesByUserId, businessById, userId),
    ),
    blockedUsers: blockedUsers.map((blockedProfile) => ({
      userId: blockedProfile.user_id,
      displayName: blockedProfile.display_name ?? "Blocked member",
      username: blockedProfile.username,
    })),
  };
}

async function mapFeedPosts({
  viewerUserId,
  posts,
  blockedUserIds,
}: {
  viewerUserId: string;
  posts: PostRow[];
  blockedUserIds?: Set<string>;
}) {
  const hiddenUserIds = blockedUserIds ?? new Set<string>();
  const filteredPosts = posts;
  const postIds = filteredPosts.map((post) => post.id);
  const userIds = [...new Set(filteredPosts.map((post) => post.user_id))];
  const businessIds = [
    ...new Set(
      filteredPosts
        .map((post) => post.business_profile_id)
        .filter((value): value is string => Boolean(value)),
    ),
  ];

  const [profiles, businesses] = await Promise.all([
    getProfilesByUserIds(userIds),
    getBusinessProfilesByIds(businessIds),
  ]);
  const profilesByUserId = new Map(profiles.map((profile) => [profile.user_id, profile]));
  const businessesById = new Map(businesses.map((business) => [business.id, business]));

  const supabase = await createServerSupabaseClient();
  const [{ data: likesData }, { data: commentsData }] = await Promise.all([
    postIds.length
      ? supabase.from("post_likes").select("post_id, user_id").in("post_id", postIds)
      : Promise.resolve({ data: [] as LikeRow[] | null }),
    postIds.length
      ? supabase
          .from("comments")
          .select("id, post_id, user_id, content, created_at")
          .in("post_id", postIds)
          .order("created_at", { ascending: true })
      : Promise.resolve({ data: [] as CommentRow[] | null }),
  ]);

  const likes = (ensureArray(likesData) as LikeRow[]).filter(
    (like) => !hiddenUserIds.has(like.user_id),
  );
  const comments = (ensureArray(commentsData) as CommentRow[]).filter(
    (comment) => !hiddenUserIds.has(comment.user_id),
  );
  const commentProfiles = await getProfilesByUserIds([
    ...new Set(comments.map((comment) => comment.user_id)),
  ]);
  const commentProfilesByUserId = new Map(
    commentProfiles.map((profile) => [profile.user_id, profile]),
  );

  const likeCounts = buildCountMap(likes.map((like) => like.post_id));
  const commentCounts = buildCountMap(comments.map((comment) => comment.post_id));
  const likedPostIds = new Set(
    likes.filter((like) => like.user_id === viewerUserId).map((like) => like.post_id),
  );
  const commentsByPostId = comments.reduce<Record<string, CommentRow[]>>((accumulator, comment) => {
    accumulator[comment.post_id] = accumulator[comment.post_id]
      ? [...accumulator[comment.post_id], comment]
      : [comment];
    return accumulator;
  }, {});

  return filteredPosts.map((post) => {
    const profile = profilesByUserId.get(post.user_id);
    const business = post.business_profile_id
      ? businessesById.get(post.business_profile_id)
      : null;
    const authorType = business
      ? "Business"
      : humanizeAccountType(post.author_type);

    return {
      id: post.id,
      userId: post.user_id,
      authorName:
        business?.business_name ?? profile?.display_name ?? "intellinked member",
      authorType,
      authorSlug:
        !business && profile ? createProfileSlug(profile) : undefined,
      businessSlug: business ? createBusinessSlug(business) : undefined,
      businessName: business?.business_name,
      content: post.content,
      category: post.category ?? "Small businesses",
      timestamp: formatRelativeTime(post.created_at),
      likes: likeCounts[post.id] ?? 0,
      comments: commentCounts[post.id] ?? 0,
      shares: 0,
      cta: post.cta,
      likedByViewer: likedPostIds.has(post.id),
      canDelete: post.user_id === viewerUserId,
      commentsList: ensureArray(commentsByPostId[post.id]).map((comment) => {
        const commenter = commentProfilesByUserId.get(comment.user_id);

        return {
          id: comment.id,
          userId: comment.user_id,
          authorName: commenter?.display_name ?? "intellinked member",
          authorSlug: commenter ? createProfileSlug(commenter) : undefined,
          content: comment.content,
          timestamp: formatRelativeTime(comment.created_at),
          canDelete: comment.user_id === viewerUserId,
        };
      }),
      businessProfileId: post.business_profile_id,
    } satisfies FeedPostView;
  });
}

export async function getHomePageData(userId: string) {
  const viewerProfile = await getViewerProfileRow(userId);
  const blockedUserIds = await getBlockedUserIds(userId);
  const supabase = await createServerSupabaseClient();

  const [{ data: postsData }, { data: profilesData }, { data: businessData }, { data: servicesData }] =
    await Promise.all([
      supabase
        .from("posts")
        .select(
          "id, user_id, business_profile_id, author_type, category, content, cta, visibility, is_published, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(18),
      supabase
        .from("profiles")
        .select(
          "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
        )
        .order("created_at", { ascending: false })
        .limit(12),
      supabase
        .from("business_profiles")
        .select(
          "id, user_id, profile_id, business_name, slug, category, location, description, contact_email, contact_phone, website_url, facebook_url, is_public",
        )
        .order("created_at", { ascending: false })
        .limit(12),
      supabase
        .from("services")
        .select(
          "id, user_id, business_profile_id, title, category, location, summary, price_label, availability, is_public, is_active, created_at",
        )
        .order("created_at", { ascending: false })
        .limit(18),
    ]);

  const posts = (ensureArray(postsData) as PostRow[]).filter(
    (post) => !blockedUserIds.has(post.user_id),
  );
  const profiles = (ensureArray(profilesData) as ProfileRow[]).filter(
    (profile) => !blockedUserIds.has(profile.user_id),
  );
  const businesses = (ensureArray(businessData) as BusinessProfileRow[]).filter(
    (business) => !blockedUserIds.has(business.user_id),
  );
  const services = (ensureArray(servicesData) as ServiceRow[]).filter(
    (service) => !blockedUserIds.has(service.user_id),
  );

  const [feedPosts, people, businessProfiles, serviceListings] = await Promise.all([
    mapFeedPosts({ viewerUserId: userId, posts, blockedUserIds }),
    mapProfileList({
      viewerUserId: userId,
      profiles: profiles.filter((profile) => profile.user_id !== userId),
    }),
    mapBusinessList({
      viewerUserId: userId,
      businesses: businesses.filter((business) => business.user_id !== userId),
    }),
    mapServiceList({
      viewerUserId: userId,
      services,
    }),
  ]);

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    stats: [
      {
        label: "Active members",
        value: profiles.length.toLocaleString("en-US"),
        note: "Authenticated profiles currently visible in intellinked.",
      },
      {
        label: "Service listings",
        value: services.length.toLocaleString("en-US"),
        note: "Active Supabase-backed services in the workspace.",
      },
      {
        label: "Feed posts",
        value: posts.length.toLocaleString("en-US"),
        note: "Public and own posts now loading from Supabase.",
      },
      {
        label: "Business profiles",
        value: businesses.length.toLocaleString("en-US"),
        note: "Live business cards connected to the current schema.",
      },
    ],
    posts: feedPosts,
    people: people.slice(0, 4),
    businesses: businessProfiles.slice(0, 3),
    services: serviceListings.slice(0, 4),
  };
}

async function mapProfileList({
  viewerUserId,
  profiles,
}: {
  viewerUserId: string;
  profiles: ProfileRow[];
}) {
  const userIds = profiles.map((profile) => profile.user_id);
  const [services, posts, follows] = await Promise.all([
    getServicesByUserIds(userIds),
    getPostsByUserIds(userIds),
    getFollowRowsForUsers(userIds),
  ]);

  const servicesByUserId = services.reduce<Record<string, ServiceRow[]>>((accumulator, service) => {
    accumulator[service.user_id] = accumulator[service.user_id]
      ? [...accumulator[service.user_id], service]
      : [service];
    return accumulator;
  }, {});
  const postsByUserId = posts.reduce<Record<string, PostRow[]>>((accumulator, post) => {
    accumulator[post.user_id] = accumulator[post.user_id]
      ? [...accumulator[post.user_id], post]
      : [post];
    return accumulator;
  }, {});
  const followerCounts = buildCountMap(
    follows
      .map((follow) => follow.following_user_id)
      .filter((value): value is string => Boolean(value)),
  );
  const followedUserIds = new Set(
    follows
      .filter((follow) => follow.follower_id === viewerUserId)
      .map((follow) => follow.following_user_id)
      .filter((value): value is string => Boolean(value)),
  );

  return profiles.map((profile) =>
    mapProfileView(
      profile,
      servicesByUserId[profile.user_id] ?? [],
      postsByUserId[profile.user_id] ?? [],
      followerCounts[profile.user_id] ?? 0,
      viewerUserId,
      followedUserIds.has(profile.user_id),
    ),
  );
}

async function mapBusinessList({
  viewerUserId,
  businesses,
}: {
  viewerUserId: string;
  businesses: BusinessProfileRow[];
}) {
  const userIds = [...new Set(businesses.map((business) => business.user_id))];
  const businessIds = businesses.map((business) => business.id);
  const [services, posts, follows] = await Promise.all([
    getServicesByUserIds(userIds),
    getPostsByUserIds(userIds),
    getFollowRowsForBusinesses(businessIds),
  ]);

  const servicesByBusinessId = services.reduce<Record<string, ServiceRow[]>>((accumulator, service) => {
    if (!service.business_profile_id) {
      return accumulator;
    }

    accumulator[service.business_profile_id] = accumulator[service.business_profile_id]
      ? [...accumulator[service.business_profile_id], service]
      : [service];
    return accumulator;
  }, {});
  const postsByBusinessId = posts.reduce<Record<string, PostRow[]>>((accumulator, post) => {
    if (!post.business_profile_id) {
      return accumulator;
    }

    accumulator[post.business_profile_id] = accumulator[post.business_profile_id]
      ? [...accumulator[post.business_profile_id], post]
      : [post];
    return accumulator;
  }, {});
  const followerCounts = buildCountMap(
    follows
      .map((follow) => follow.following_business_profile_id)
      .filter((value): value is string => Boolean(value)),
  );
  const followedBusinessIds = new Set(
    follows
      .filter((follow) => follow.follower_id === viewerUserId)
      .map((follow) => follow.following_business_profile_id)
      .filter((value): value is string => Boolean(value)),
  );

  return businesses.map((business) =>
    mapBusinessView(
      business,
      servicesByBusinessId[business.id] ?? [],
      postsByBusinessId[business.id] ?? [],
      followerCounts[business.id] ?? 0,
      viewerUserId,
      followedBusinessIds.has(business.id),
    ),
  );
}

async function mapServiceList({
  viewerUserId,
  services,
}: {
  viewerUserId: string;
  services: ServiceRow[];
}) {
  const userIds = [...new Set(services.map((service) => service.user_id))];
  const businessIds = [
    ...new Set(
      services
        .map((service) => service.business_profile_id)
        .filter((value): value is string => Boolean(value)),
    ),
  ];
  const [profiles, businesses] = await Promise.all([
    getProfilesByUserIds(userIds),
    getBusinessProfilesByIds(businessIds),
  ]);
  const profilesByUserId = new Map(profiles.map((profile) => [profile.user_id, profile]));
  const businessesById = new Map(businesses.map((business) => [business.id, business]));

  return services.map((service) =>
    mapServiceListing(service, profilesByUserId, businessesById, viewerUserId),
  );
}

export async function getExplorePageData(userId: string) {
  const viewerProfile = await getViewerProfileRow(userId);
  const blockedUserIds = await getBlockedUserIds(userId);
  const supabase = await createServerSupabaseClient();

  const [{ data: profilesData }, { data: businessesData }, { data: servicesData }] =
    await Promise.all([
      supabase
        .from("profiles")
        .select(
          "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
        )
        .order("created_at", { ascending: false }),
      supabase
        .from("business_profiles")
        .select(
          "id, user_id, profile_id, business_name, slug, category, location, description, contact_email, contact_phone, website_url, facebook_url, is_public",
        )
        .order("created_at", { ascending: false }),
      supabase
        .from("services")
        .select(
          "id, user_id, business_profile_id, title, category, location, summary, price_label, availability, is_public, is_active, created_at",
        )
        .order("created_at", { ascending: false }),
    ]);

  const profiles = (ensureArray(profilesData) as ProfileRow[]).filter(
    (profile) => !blockedUserIds.has(profile.user_id),
  );
  const businesses = (ensureArray(businessesData) as BusinessProfileRow[]).filter(
    (business) => !blockedUserIds.has(business.user_id),
  );
  const services = (ensureArray(servicesData) as ServiceRow[]).filter(
    (service) => !blockedUserIds.has(service.user_id),
  );

  const [people, businessProfiles, serviceListings] = await Promise.all([
    mapProfileList({ viewerUserId: userId, profiles }),
    mapBusinessList({ viewerUserId: userId, businesses }),
    mapServiceList({ viewerUserId: userId, services }),
  ]);

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    people,
    businesses: businessProfiles,
    services: serviceListings,
  };
}

export async function getServicesPageData(userId: string) {
  const viewerProfile = await getViewerProfileRow(userId);
  const viewerBusiness = await getBusinessProfileByUserId(userId);
  const blockedUserIds = await getBlockedUserIds(userId);
  const supabase = await createServerSupabaseClient();

  const { data: servicesData } = await supabase
    .from("services")
    .select(
      "id, user_id, business_profile_id, title, category, location, summary, price_label, availability, is_public, is_active, created_at",
    )
    .order("created_at", { ascending: false });

  const services = (ensureArray(servicesData) as ServiceRow[]).filter(
    (service) => !blockedUserIds.has(service.user_id),
  );
  const serviceListings = await mapServiceList({ viewerUserId: userId, services });

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    business: viewerBusiness
      ? {
          id: viewerBusiness.id,
          name: viewerBusiness.business_name,
        }
      : null,
    services: serviceListings,
    ownServices: serviceListings.filter((service) => service.userId === userId),
  };
}

export async function getProfilePageData(userId: string) {
  const bundle = await getViewerWorkspace(userId);
  const viewerProfileRow = await getViewerProfileRow(userId);
  const businessRow = await getBusinessProfileByUserId(userId);
  const [follows, posts, services] = await Promise.all([
    getFollowRowsForUsers([userId]),
    getPostsByUserIds([userId]),
    getServicesByUserIds([userId]),
  ]);
  const followerCount = buildCountMap(
    follows
      .map((follow) => follow.following_user_id)
      .filter((value): value is string => Boolean(value)),
  )[userId] ?? 0;

  const profile = mapProfileView(
    viewerProfileRow,
    services,
    posts,
    followerCount,
    userId,
    false,
  );

  return {
    viewer: bundle.viewer,
    profile,
    business: bundle.business,
    posts: bundle.posts,
    services: bundle.services,
    blockedUsers: bundle.blockedUsers,
    businessProfileId: businessRow?.id ?? null,
  };
}

export async function getProfileBySlug(userId: string, slug: string) {
  const viewerProfile = await getViewerProfileRow(userId);
  const blockedUserIds = await getBlockedUserIds(userId);
  const supabase = await createServerSupabaseClient();

  const { data: profileData } = await supabase
    .from("profiles")
    .select(
      "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
    )
    .or(`username.eq.${slug},id.eq.${slug}`)
    .maybeSingle();

  const profile = (profileData as ProfileRow | null) ?? null;

  if (!profile || blockedUserIds.has(profile.user_id)) {
    return null;
  }

  const [services, posts, follows] = await Promise.all([
    getServicesByUserIds([profile.user_id]),
    getPostsByUserIds([profile.user_id]),
    getFollowRowsForUsers([profile.user_id]),
  ]);
  const followerCount = buildCountMap(
    follows
      .map((follow) => follow.following_user_id)
      .filter((value): value is string => Boolean(value)),
  )[profile.user_id] ?? 0;
  const isFollowing = follows.some(
    (follow) =>
      follow.follower_id === userId && follow.following_user_id === profile.user_id,
  );

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    profile: mapProfileView(
      profile,
      services,
      posts,
      followerCount,
      userId,
      isFollowing,
    ),
    posts: await mapFeedPosts({ viewerUserId: userId, posts, blockedUserIds }),
    services: await mapServiceList({ viewerUserId: userId, services }),
  };
}

export async function getBusinessBySlug(userId: string, slug: string) {
  const viewerProfile = await getViewerProfileRow(userId);
  const blockedUserIds = await getBlockedUserIds(userId);
  const supabase = await createServerSupabaseClient();

  const { data: businessData } = await supabase
    .from("business_profiles")
    .select(
      "id, user_id, profile_id, business_name, slug, category, location, description, contact_email, contact_phone, website_url, facebook_url, is_public",
    )
    .or(`slug.eq.${slug},id.eq.${slug}`)
    .maybeSingle();

  const business = (businessData as BusinessProfileRow | null) ?? null;

  if (!business || blockedUserIds.has(business.user_id)) {
    return null;
  }

  const [services, posts, follows] = await Promise.all([
    getServicesByUserIds([business.user_id]),
    getPostsByUserIds([business.user_id]),
    getFollowRowsForBusinesses([business.id]),
  ]);
  const businessServices = services.filter(
    (service) => service.business_profile_id === business.id,
  );
  const businessPosts = posts.filter((post) => post.business_profile_id === business.id);
  const followerCount = buildCountMap(
    follows
      .map((follow) => follow.following_business_profile_id)
      .filter((value): value is string => Boolean(value)),
  )[business.id] ?? 0;
  const isFollowing = follows.some(
    (follow) =>
      follow.follower_id === userId &&
      follow.following_business_profile_id === business.id,
  );

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    business: mapBusinessView(
      business,
      businessServices,
      businessPosts,
      followerCount,
      userId,
      isFollowing,
    ),
    posts: await mapFeedPosts({
      viewerUserId: userId,
      posts: businessPosts,
      blockedUserIds,
    }),
    services: await mapServiceList({ viewerUserId: userId, services: businessServices }),
  };
}

export async function getNotificationsPageData(userId: string) {
  const viewerProfile = await getViewerProfileRow(userId);
  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("notifications")
    .select("id, title, body, type, is_read, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  const notifications = (ensureArray(data) as NotificationRow[]).map((notification) => ({
    id: notification.id,
    title: notification.title,
    detail:
      notification.body ??
      "This notification does not have extra detail yet.",
    time: formatRelativeTime(notification.created_at),
    type: notification.type,
    isRead: notification.is_read,
  }));

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    notifications,
  };
}

export async function getAdminPageData(userId: string) {
  const viewerProfile = await getViewerProfileRow(userId);

  if (!viewerProfile.is_admin) {
    return {
      viewer: mapViewerWorkspace(viewerProfile),
      reports: [] as ModerationReportView[],
      isAdmin: false,
    };
  }

  const supabase = await createServerSupabaseClient();
  const { data: reportsData } = await supabase
    .from("reports")
    .select(
      "id, status, reason, details, reporter_user_id, reported_user_id, post_id, comment_id, service_id, business_profile_id, created_at",
    )
    .order("created_at", { ascending: false });

  const reports = ensureArray(reportsData) as ReportRow[];
  const reporterIds = [...new Set(reports.map((report) => report.reporter_user_id))];
  const reportedUserIds = [
    ...new Set(
      reports
        .map((report) => report.reported_user_id)
        .filter((value): value is string => Boolean(value)),
    ),
  ];
  const serviceIds = [
    ...new Set(
      reports
        .map((report) => report.service_id)
        .filter((value): value is string => Boolean(value)),
    ),
  ];
  const postIds = [
    ...new Set(
      reports
        .map((report) => report.post_id)
        .filter((value): value is string => Boolean(value)),
    ),
  ];
  const businessIds = [
    ...new Set(
      reports
        .map((report) => report.business_profile_id)
        .filter((value): value is string => Boolean(value)),
    ),
  ];

  const [{ data: reporterProfiles }, { data: reportedProfiles }, { data: services }, { data: posts }, { data: businesses }] =
    await Promise.all([
      reporterIds.length
        ? supabase
            .from("profiles")
            .select(
              "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
            )
            .in("user_id", reporterIds)
        : Promise.resolve({ data: [] as ProfileRow[] | null }),
      reportedUserIds.length
        ? supabase
            .from("profiles")
            .select(
              "id, user_id, username, display_name, account_type, location, bio, website_url, is_public, is_admin",
            )
            .in("user_id", reportedUserIds)
        : Promise.resolve({ data: [] as ProfileRow[] | null }),
      serviceIds.length
        ? supabase
            .from("services")
            .select(
              "id, user_id, business_profile_id, title, category, location, summary, price_label, availability, is_public, is_active, created_at",
            )
            .in("id", serviceIds)
        : Promise.resolve({ data: [] as ServiceRow[] | null }),
      postIds.length
        ? supabase
            .from("posts")
            .select(
              "id, user_id, business_profile_id, author_type, category, content, cta, visibility, is_published, created_at",
            )
            .in("id", postIds)
        : Promise.resolve({ data: [] as PostRow[] | null }),
      businessIds.length
        ? supabase
            .from("business_profiles")
            .select(
              "id, user_id, profile_id, business_name, slug, category, location, description, contact_email, contact_phone, website_url, facebook_url, is_public",
            )
            .in("id", businessIds)
        : Promise.resolve({ data: [] as BusinessProfileRow[] | null }),
    ]);

  const reporterByUserId = new Map(
    (ensureArray(reporterProfiles) as ProfileRow[]).map((profile) => [
      profile.user_id,
      profile,
    ]),
  );
  const reportedByUserId = new Map(
    (ensureArray(reportedProfiles) as ProfileRow[]).map((profile) => [
      profile.user_id,
      profile,
    ]),
  );
  const serviceById = new Map(
    (ensureArray(services) as ServiceRow[]).map((service) => [service.id, service]),
  );
  const postById = new Map(
    (ensureArray(posts) as PostRow[]).map((post) => [post.id, post]),
  );
  const businessById = new Map(
    (ensureArray(businesses) as BusinessProfileRow[]).map((business) => [
      business.id,
      business,
    ]),
  );

  return {
    viewer: mapViewerWorkspace(viewerProfile),
    isAdmin: true,
    reports: reports.map((report) => {
      const reporter = reporterByUserId.get(report.reporter_user_id);
      const target = report.reported_user_id
        ? `User: ${reportedByUserId.get(report.reported_user_id)?.display_name ?? "Unknown member"}`
        : report.post_id
          ? `Post: ${firstDefinedString(postById.get(report.post_id)?.content)?.slice(0, 48) || "Reported post"}`
          : report.service_id
            ? `Service: ${serviceById.get(report.service_id)?.title ?? "Reported service"}`
            : report.business_profile_id
              ? `Business: ${businessById.get(report.business_profile_id)?.business_name ?? "Reported business"}`
              : report.comment_id
                ? "Comment"
                : "Report";

      return {
        id: report.id,
        status:
          report.status === "in_review"
            ? "In Review"
            : report.status === "resolved"
              ? "Resolved"
              : report.status === "dismissed"
                ? "Dismissed"
                : "Pending",
        rawStatus: report.status,
        target,
        reason: report.reason,
        submittedBy: reporter?.display_name ?? "intellinked member",
        time: formatRelativeTime(report.created_at),
        notes: report.details ?? "No moderator notes added yet.",
      } satisfies ModerationReportView;
    }),
  };
}
