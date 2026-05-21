import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { cookies } from "next/headers";

import { getSupabaseEnv } from "@/lib/env";

export async function createServerSupabaseClient() {
  const cookieStore = await cookies();
  const { url, anonKey } = getSupabaseEnv();
  type CookieToSet = { name: string; value: string; options: CookieOptions };

  return createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet: CookieToSet[]) {
        cookiesToSet.forEach(({ name, value, options }) => {
          cookieStore.set(name, value, options);
        });
      }
    }
  });
}
