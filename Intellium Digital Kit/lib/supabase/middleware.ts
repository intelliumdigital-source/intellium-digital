import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getSupabaseEnv, isSupabaseConfigured } from "@/lib/env";

export async function updateSession(request: NextRequest) {
  if (!isSupabaseConfigured()) {
    return NextResponse.next({ request });
  }

  let response = NextResponse.next({
    request
  });

  const { url, anonKey } = getSupabaseEnv();
  type CookieToSet = { name: string; value: string; options: CookieOptions };

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: CookieToSet[]) {
        cookiesToSet.forEach(({ name, value, options }) => {
          request.cookies.set(name, value);
          response.cookies.set(name, value, options);
        });
      }
    }
  });

  await supabase.auth.getUser();

  return response;
}
