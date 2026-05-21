import { AppShell } from "@/components/layout/app-shell";
import { SetupNotice } from "@/components/shared/setup-notice";
import { requireAuthenticatedProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function PortalLayout({
  children
}: {
  children: React.ReactNode;
}) {
  const session = await requireAuthenticatedProfile();

  if (!session.configured || !session.profile || !session.user) {
    return <SetupNotice />;
  }

  return (
    <AppShell
      role={session.profile.role}
      name={session.profile.full_name || session.user.email || "Portal User"}
      email={session.user.email || session.profile.email}
    >
      {children}
    </AppShell>
  );
}
