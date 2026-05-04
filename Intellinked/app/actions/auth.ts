"use server";

import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { hasSupabaseEnv } from "@/lib/supabase/env";
import type { AuthActionState } from "@/app/auth/auth-state";

function getField(formData: FormData, field: string) {
  return formData.get(field)?.toString().trim() ?? "";
}

function mapSupabaseError(message: string) {
  if (message.toLowerCase().includes("invalid login credentials")) {
    return "Incorrect email or password.";
  }

  if (message.toLowerCase().includes("email not confirmed")) {
    return "Your email is not confirmed yet. Check your inbox and try again after confirming.";
  }

  if (message.toLowerCase().includes("user already registered")) {
    return "This email is already registered. Try logging in instead.";
  }

  return message;
}

export async function signInAction(
  _: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  if (!hasSupabaseEnv()) {
    return {
      errorMessage:
        "Supabase is not configured yet. Add NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY first.",
    };
  }

  const email = getField(formData, "email");
  const password = getField(formData, "password");

  if (!email || !password) {
    return {
      errorMessage: "Email and password are required.",
    };
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    return { errorMessage: mapSupabaseError(error.message) };
  }

  redirect("/home");
}

export async function signUpAction(
  _: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  if (!hasSupabaseEnv()) {
    return {
      errorMessage:
        "Supabase is not configured yet. Add NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY first.",
    };
  }

  const displayName = getField(formData, "display_name");
  const accountType = getField(formData, "account_type");
  const email = getField(formData, "email");
  const password = getField(formData, "password");

  if (!displayName || !email || !password || !accountType) {
    return {
      errorMessage: "All registration fields are required.",
    };
  }

  if (password.length < 8) {
    return {
      errorMessage: "Password must be at least 8 characters long.",
    };
  }

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        display_name: displayName,
        account_type: accountType,
      },
    },
  });

  if (error) {
    return { errorMessage: mapSupabaseError(error.message) };
  }

  if (data.session) {
    redirect("/home");
  }

  return {
    successMessage:
      "Registration created. Check your inbox to confirm your email before signing in if confirmation is enabled.",
  };
}

export async function signOutAction() {
  if (hasSupabaseEnv()) {
    const supabase = await createServerSupabaseClient();
    await supabase.auth.signOut();
  }

  redirect("/auth");
}
