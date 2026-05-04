"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireSessionUser } from "@/lib/auth/session";
import { createServerSupabaseClient } from "@/lib/supabase/server";

function getField(formData: FormData, field: string) {
  return formData.get(field)?.toString().trim() ?? "";
}

function getCheckboxValue(formData: FormData, field: string) {
  return formData.get(field) === "on";
}

function normalizeAccountType(value: string) {
  const normalized = value.toLowerCase();

  if (
    normalized === "professional" ||
    normalized === "business" ||
    normalized === "freelancer" ||
    normalized === "customer"
  ) {
    return normalized;
  }

  return "professional";
}

function normalizeUsername(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 40);
}

function slugify(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60);
}

function normalizeUrl(value: string) {
  if (!value) {
    return null;
  }

  return value.startsWith("http://") || value.startsWith("https://")
    ? value
    : `https://${value}`;
}

async function getOwnProfileRow(userId: string) {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("id, user_id, username, is_admin")
    .eq("user_id", userId)
    .single();

  if (error || !data) {
    throw new Error("Could not load the signed-in profile.");
  }

  return data as {
    id: string;
    user_id: string;
    username: string | null;
    is_admin: boolean;
  };
}

function revalidateWorkspace() {
  [
    "/home",
    "/explore",
    "/profile",
    "/services",
    "/settings",
    "/notifications",
    "/admin",
  ].forEach((path) => revalidatePath(path));
}

function revalidateProfilePath(slugOrId: string | null | undefined) {
  if (slugOrId) {
    revalidatePath(`/people/${slugOrId}`);
  }
}

function revalidateBusinessPath(slugOrId: string | null | undefined) {
  if (slugOrId) {
    revalidatePath(`/businesses/${slugOrId}`);
  }
}

async function createReportNotification(
  targetUserId: string | null,
  title: string,
  body: string,
) {
  if (!targetUserId) {
    return;
  }

  const supabase = await createServerSupabaseClient();
  const actor = await requireSessionUser();

  const { data: actorProfile } = await supabase
    .from("profiles")
    .select("display_name")
    .eq("user_id", actor.id)
    .maybeSingle();

  if (targetUserId !== actor.id) {
    // This insert may be blocked by RLS. We silently ignore it because notifications
    // are a secondary enhancement, not an authorization bypass.
    await supabase.from("notifications").insert({
      user_id: targetUserId,
      actor_user_id: actor.id,
      title,
      body:
        actorProfile?.display_name
          ? `${actorProfile.display_name} ${body}`
          : body,
      type: "Community",
    });
  }
}

export async function updateProfileAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const returnPath = getField(formData, "return_path") || "/profile";
  const username = normalizeUsername(getField(formData, "username"));

  const { error } = await supabase
    .from("profiles")
    .update({
      display_name: getField(formData, "display_name") || null,
      username: username || null,
      account_type: normalizeAccountType(getField(formData, "account_type")),
      location: getField(formData, "location") || null,
      bio: getField(formData, "bio") || null,
      website_url: normalizeUrl(getField(formData, "website_url")),
      is_public: getCheckboxValue(formData, "is_public"),
    })
    .eq("user_id", user.id);

  if (error) {
    throw new Error(error.message);
  }

  revalidateWorkspace();
  revalidateProfilePath(username || user.id);
  redirect(returnPath);
}

export async function upsertBusinessProfileAction(formData: FormData) {
  const user = await requireSessionUser();
  const profile = await getOwnProfileRow(user.id);
  const supabase = await createServerSupabaseClient();
  const returnPath = getField(formData, "return_path") || "/profile";
  const businessName = getField(formData, "business_name");

  if (!businessName) {
    throw new Error("Business name is required.");
  }

  const payload = {
    user_id: user.id,
    profile_id: profile.id,
    business_name: businessName,
    slug: slugify(getField(formData, "slug") || businessName),
    category: getField(formData, "category") || null,
    location: getField(formData, "location") || null,
    description: getField(formData, "description") || null,
    contact_email: getField(formData, "contact_email") || null,
    contact_phone: getField(formData, "contact_phone") || null,
    website_url: normalizeUrl(getField(formData, "website_url")),
    facebook_url: normalizeUrl(getField(formData, "facebook_url")),
    is_public: getCheckboxValue(formData, "is_public"),
  };

  const { error } = await supabase.from("business_profiles").upsert(payload, {
    onConflict: "user_id",
  });

  if (error) {
    throw new Error(error.message);
  }

  revalidateWorkspace();
  revalidateBusinessPath(payload.slug);
  redirect(returnPath);
}

export async function createPostAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const content = getField(formData, "content");

  if (!content) {
    throw new Error("Post content is required.");
  }

  const businessProfileId = getField(formData, "business_profile_id") || null;
  const authorType = normalizeAccountType(getField(formData, "author_type"));
  const cta = getField(formData, "cta") as "Connect" | "Message" | "View Service";
  const visibility = getField(formData, "visibility") || "public";

  const { error } = await supabase.from("posts").insert({
    user_id: user.id,
    business_profile_id: businessProfileId,
    author_type: authorType,
    category: getField(formData, "category") || null,
    content,
    cta:
      cta === "Message" || cta === "View Service" ? cta : "Connect",
    visibility:
      visibility === "followers" || visibility === "private" ? visibility : "public",
    is_published: true,
  });

  if (error) {
    throw new Error(error.message);
  }

  revalidateWorkspace();
  redirect("/home");
}

export async function deletePostAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const postId = getField(formData, "post_id");

  if (!postId) {
    return;
  }

  await supabase.from("posts").delete().eq("id", postId).eq("user_id", user.id);
  revalidateWorkspace();
}

export async function togglePostLikeAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const postId = getField(formData, "post_id");
  const authorUserId = getField(formData, "author_user_id") || null;

  if (!postId) {
    return;
  }

  const { data: existingLike } = await supabase
    .from("post_likes")
    .select("id")
    .eq("post_id", postId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (existingLike) {
    await supabase.from("post_likes").delete().eq("id", existingLike.id);
  } else {
    await supabase.from("post_likes").insert({
      post_id: postId,
      user_id: user.id,
    });
    await createReportNotification(
      authorUserId,
      "New post like",
      "liked one of your posts.",
    );
  }

  revalidateWorkspace();
}

export async function createCommentAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const postId = getField(formData, "post_id");
  const content = getField(formData, "content");
  const authorUserId = getField(formData, "author_user_id") || null;

  if (!postId || !content) {
    return;
  }

  await supabase.from("comments").insert({
    post_id: postId,
    user_id: user.id,
    content,
  });

  await createReportNotification(
    authorUserId,
    "New comment on your post",
    "commented on one of your posts.",
  );

  revalidateWorkspace();
}

export async function deleteCommentAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const commentId = getField(formData, "comment_id");

  if (!commentId) {
    return;
  }

  await supabase.from("comments").delete().eq("id", commentId).eq("user_id", user.id);
  revalidateWorkspace();
}

export async function upsertServiceAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const returnPath = getField(formData, "return_path") || "/services";
  const title = getField(formData, "title");

  if (!title) {
    throw new Error("Service title is required.");
  }

  const serviceId = getField(formData, "service_id");
  const payload = {
    user_id: user.id,
    business_profile_id: getField(formData, "business_profile_id") || null,
    title,
    category: getField(formData, "category") || null,
    location: getField(formData, "location") || null,
    summary: getField(formData, "summary") || null,
    price_label: getField(formData, "price_label") || null,
    availability: getField(formData, "availability") || null,
    is_public: getCheckboxValue(formData, "is_public"),
    is_active: getCheckboxValue(formData, "is_active"),
  };

  if (serviceId) {
    const { error } = await supabase
      .from("services")
      .update(payload)
      .eq("id", serviceId)
      .eq("user_id", user.id);

    if (error) {
      throw new Error(error.message);
    }
  } else {
    const { error } = await supabase.from("services").insert(payload);

    if (error) {
      throw new Error(error.message);
    }
  }

  revalidateWorkspace();
  redirect(returnPath);
}

export async function deleteServiceAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const serviceId = getField(formData, "service_id");

  if (!serviceId) {
    return;
  }

  await supabase.from("services").delete().eq("id", serviceId).eq("user_id", user.id);
  revalidateWorkspace();
}

export async function toggleFollowProfileAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const targetUserId = getField(formData, "target_user_id");

  if (!targetUserId || targetUserId === user.id) {
    return;
  }

  const { data: existingFollow } = await supabase
    .from("follows")
    .select("id")
    .eq("follower_id", user.id)
    .eq("following_user_id", targetUserId)
    .maybeSingle();

  if (existingFollow) {
    await supabase.from("follows").delete().eq("id", existingFollow.id);
  } else {
    await supabase.from("follows").insert({
      follower_id: user.id,
      following_user_id: targetUserId,
    });
    await createReportNotification(
      targetUserId,
      "New follower",
      "started following your profile.",
    );
  }

  revalidateWorkspace();
}

export async function toggleFollowBusinessAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const businessProfileId = getField(formData, "business_profile_id");
  const businessUserId = getField(formData, "business_user_id") || null;

  if (!businessProfileId) {
    return;
  }

  const { data: existingFollow } = await supabase
    .from("follows")
    .select("id")
    .eq("follower_id", user.id)
    .eq("following_business_profile_id", businessProfileId)
    .maybeSingle();

  if (existingFollow) {
    await supabase.from("follows").delete().eq("id", existingFollow.id);
  } else {
    await supabase.from("follows").insert({
      follower_id: user.id,
      following_business_profile_id: businessProfileId,
    });
    await createReportNotification(
      businessUserId,
      "New business follower",
      "started following your business profile.",
    );
  }

  revalidateWorkspace();
}

export async function createReportAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const targetType = getField(formData, "target_type");
  const targetId = getField(formData, "target_id");
  const reportedUserId = getField(formData, "reported_user_id") || null;
  const reason = getField(formData, "reason") || "Needs review";
  const details = getField(formData, "details") || null;

  if (!targetType || !targetId) {
    return;
  }

  const payload: Record<string, string | null> = {
    reporter_user_id: user.id,
    reason,
    details,
    reported_user_id: null,
    post_id: null,
    comment_id: null,
    service_id: null,
    business_profile_id: null,
  };

  if (targetType === "profile") {
    payload.reported_user_id = reportedUserId ?? targetId;
  } else if (targetType === "post") {
    payload.post_id = targetId;
    payload.reported_user_id = reportedUserId;
  } else if (targetType === "comment") {
    payload.comment_id = targetId;
    payload.reported_user_id = reportedUserId;
  } else if (targetType === "service") {
    payload.service_id = targetId;
    payload.reported_user_id = reportedUserId;
  } else if (targetType === "business") {
    payload.business_profile_id = targetId;
    payload.reported_user_id = reportedUserId;
  } else {
    return;
  }

  await supabase.from("reports").insert(payload);
  revalidateWorkspace();
}

export async function blockUserAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const blockedUserId = getField(formData, "blocked_user_id");

  if (!blockedUserId || blockedUserId === user.id) {
    return;
  }

  await supabase.from("blocks").upsert(
    {
      blocker_user_id: user.id,
      blocked_user_id: blockedUserId,
    },
    {
      onConflict: "blocker_user_id,blocked_user_id",
      ignoreDuplicates: true,
    },
  );

  revalidateWorkspace();
}

export async function unblockUserAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const blockedUserId = getField(formData, "blocked_user_id");

  if (!blockedUserId) {
    return;
  }

  await supabase
    .from("blocks")
    .delete()
    .eq("blocker_user_id", user.id)
    .eq("blocked_user_id", blockedUserId);

  revalidateWorkspace();
}

export async function updateReportStatusAction(formData: FormData) {
  const user = await requireSessionUser();
  const profile = await getOwnProfileRow(user.id);

  if (!profile.is_admin) {
    redirect("/home");
  }

  const supabase = await createServerSupabaseClient();
  const reportId = getField(formData, "report_id");
  const status = getField(formData, "status");

  if (!reportId || !status) {
    return;
  }

  const nextStatus =
    status === "in_review" || status === "resolved" || status === "dismissed"
      ? status
      : "pending";

  await supabase
    .from("reports")
    .update({
      status: nextStatus,
      reviewed_by: user.id,
      reviewed_at: new Date().toISOString(),
      moderation_notes: getField(formData, "moderation_notes") || null,
    })
    .eq("id", reportId);

  revalidateWorkspace();
  revalidatePath("/admin");
}

export async function markNotificationReadAction(formData: FormData) {
  const user = await requireSessionUser();
  const supabase = await createServerSupabaseClient();
  const notificationId = getField(formData, "notification_id");

  if (!notificationId) {
    return;
  }

  await supabase
    .from("notifications")
    .update({ is_read: true })
    .eq("id", notificationId)
    .eq("user_id", user.id);

  revalidatePath("/notifications");
}
