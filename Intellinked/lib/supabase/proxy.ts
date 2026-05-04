import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getSupabaseEnv, hasSupabaseEnv } from "@/lib/supabase/env";

const authRoute = "/auth";
const protectedPrefixes = [
  "/home",
  "/explore",
  "/profile",
  "/create",
  "/services",
  "/messages",
  "/notifications",
  "/settings",
  "/admin",
  "/people/",
  "/businesses/",
];

function isProtectedPath(pathname: string) {
  return protectedPrefixes.some((prefix) => pathname.startsWith(prefix));
}

export async function updateSession(request: NextRequest) {
  const pathname = request.nextUrl.pathname;

  if (!hasSupabaseEnv()) {
    if (isProtectedPath(pathname)) {
      return NextResponse.redirect(new URL("/auth", request.url));
    }

    return NextResponse.next({ request });
  }

  let response = NextResponse.next({ request });
  const { url, anonKey } = getSupabaseEnv();

  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => {
          request.cookies.set(name, value);
        });

        response = NextResponse.next({ request });

        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options);
        });
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user && isProtectedPath(pathname)) {
    const redirectUrl = new URL("/auth", request.url);
    return NextResponse.redirect(redirectUrl);
  }

  if (user && pathname === authRoute) {
    return NextResponse.redirect(new URL("/home", request.url));
  }

  return response;
}
