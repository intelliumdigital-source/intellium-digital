import { redirect } from "next/navigation";

import { SignInForm } from "@/components/forms/sign-in-form";
import { SetupNotice } from "@/components/shared/setup-notice";
import { getCurrentProfile } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function LoginPage() {
  const session = await getCurrentProfile();

  if (!session.configured) {
    return <SetupNotice />;
  }

  if (session.user && session.profile) {
    redirect(session.profile.role === "admin" ? "/admin" : "/dashboard");
  }

  return (
    <main className="auth-shell">
      <div className="auth-card">
        <section className="hero-card auth-brand-panel">
          <div className="auth-brand-copy">
            <p className="eyebrow">Intellium Digital</p>
            <h1 className="title">IntelliLead Outreach Portal</h1>
            <p className="subtitle">
              Private operations space for commission-based outreach researchers.
              Submit stronger leads, use approved scripts, and track commission
              progress without losing handoff context.
            </p>
          </div>

          <div className="grid grid-2">
            <div className="card">
              <p className="metric-label">Portal Focus</p>
              <p style={{ margin: "0.4rem 0 0" }}>
                Legitimize. Digitize. Grow.
              </p>
            </div>
            <div className="card">
              <p className="metric-label">Includes</p>
              <p style={{ margin: "0.4rem 0 0" }}>
                Leads, resources, commissions, announcements
              </p>
            </div>
          </div>

          <div className="card">
            <p className="metric-label">Portal Rules</p>
            <ul style={{ margin: 0, paddingLeft: "1.1rem", lineHeight: 1.8 }}>
              <li>No spam.</li>
              <li>Proof is required for every lead.</li>
              <li>Only approved scripts, pricing, and claims are allowed.</li>
            </ul>
          </div>
        </section>

        <section className="card auth-form-panel">
          <p className="eyebrow">Secure Login</p>
          <h2 className="section-title">Access your workspace</h2>
          <p className="section-description">
            Use your assigned email and password. Researcher and admin access are
            controlled by your role in Supabase.
          </p>
          <SignInForm />
        </section>
      </div>
    </main>
  );
}
