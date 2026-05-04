import { SiteChrome } from "@/app/_components/site-chrome";
import { requireSessionUser } from "@/lib/auth/session";
import { getViewerWorkspace } from "@/lib/social/queries";

export const dynamic = "force-dynamic";

export default async function WorkspaceLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const user = await requireSessionUser();
  const data = await getViewerWorkspace(user.id);

  return (
    <SiteChrome
      user={{
        id: user.id,
        email: user.email ?? null,
        displayName: data.viewer.displayName,
        isAdmin: data.viewer.isAdmin,
      }}
    >
      {children}
    </SiteChrome>
  );
}
