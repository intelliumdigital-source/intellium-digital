import { redirect } from "next/navigation";

import { isSupabaseConfigured } from "@/lib/env";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { Profile, UserRole } from "@/lib/types";

export async function getCurrentProfile() {
  if (!isSupabaseConfigured()) {
    return { configured: false as const, user: null, profile: null };
  }

  const supabase = await createServerSupabaseClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    return { configured: true as const, user: null, profile: null };
  }

  const { data: existingProfile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();
  const profile = existingProfile as Profile | null;

  if (profile) {
    return { configured: true as const, user, profile };
  }

  const profilePayload = {
    id: user.id,
    email: user.email ?? "",
    full_name: user.user_metadata?.full_name ?? null
  };

  const { data: createdProfile, error } = await supabase
    .from("profiles")
    .insert(profilePayload)
    .select("*")
    .single();

  if (error) {
    throw error;
  }

  return {
    configured: true as const,
    user,
    profile: createdProfile as Profile
  };
}

export async function requireAuthenticatedProfile() {
  const session = await getCurrentProfile();

  if (!session.configured) {
    return session;
  }

  if (!session.user || !session.profile) {
    redirect("/login");
  }

  return session;
}

export async function requireRole(allowedRoles: UserRole[]) {
  const session = await requireAuthenticatedProfile();

  if (!session.configured) {
    return session;
  }

  if (!session.profile || !allowedRoles.includes(session.profile.role)) {
    redirect(
      session.profile?.role === "admin" ? "/admin" : "/dashboard"
    );
  }

  return session;
}
