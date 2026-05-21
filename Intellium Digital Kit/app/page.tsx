import { redirect } from "next/navigation";

import { getCurrentProfile } from "@/lib/auth";
import { SetupNotice } from "@/components/shared/setup-notice";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const session = await getCurrentProfile();

  if (!session.configured) {
    return <SetupNotice />;
  }

  if (!session.user || !session.profile) {
    redirect("/login");
  }

  redirect(session.profile.role === "admin" ? "/admin" : "/dashboard");
}
