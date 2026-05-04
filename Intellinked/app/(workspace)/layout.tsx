import { SiteChrome } from "@/app/_components/site-chrome";
import { requireSessionUser } from "@/lib/auth/session";
import { hasSupabaseEnv } from "@/lib/supabase/env";

export const dynamic = "force-dynamic";

export default async function WorkspaceLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const user = hasSupabaseEnv() ? await requireSessionUser() : null;

  return (
    <SiteChrome
      user={
        user
          ? {
              id: user.id,
              email: user.email ?? null,
              displayName:
                user.user_metadata.display_name?.toString() ?? user.email ?? "Member",
            }
          : null
      }
    >
      {children}
    </SiteChrome>
  );
}
