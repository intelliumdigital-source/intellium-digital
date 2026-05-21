"use client";

import { createBrowserClient } from "@supabase/ssr";

import { getSupabaseEnv } from "@/lib/env";

export function createBrowserSupabaseClient() {
  const { url, anonKey } = getSupabaseEnv();
  return createBrowserClient(url, anonKey);
}
