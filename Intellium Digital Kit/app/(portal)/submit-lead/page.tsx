import { SubmitLeadForm } from "@/components/forms/submit-lead-form";
import { SetupNotice } from "@/components/shared/setup-notice";
import { requireRole } from "@/lib/auth";

export default async function SubmitLeadPage() {
  const session = await requireRole(["researcher"]);

  if (!session.configured) {
    return <SetupNotice />;
  }

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <p className="eyebrow">Lead Submission</p>
        <h1 className="title">Submit a qualified lead</h1>
        <p className="subtitle">
          Include clear proof, a realistic score, and a concise problem summary.
          Duplicate detection checks the business name and business link before save.
        </p>
      </section>

      <section className="card">
        <h2 className="section-title">Lead Details</h2>
        <p className="section-description">
          Use only accurate information. Fake or duplicate submissions disqualify commission.
        </p>
        <SubmitLeadForm />
      </section>
    </div>
  );
}
