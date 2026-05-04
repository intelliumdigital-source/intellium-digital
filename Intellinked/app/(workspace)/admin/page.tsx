import { redirect } from "next/navigation";

import { updateReportStatusAction } from "@/app/actions/workspace";
import { PageIntro, Pill, Surface } from "@/app/_components/ui";
import { requireSessionUser } from "@/lib/auth/session";
import { getAdminPageData } from "@/lib/social/queries";

const moderationSteps = ["Review", "Hide or warn", "Escalate", "Resolve"];

export default async function AdminPage() {
  const user = await requireSessionUser();
  const data = await getAdminPageData(user.id);

  if (!data.isAdmin) {
    redirect("/home");
  }

  const pendingCount = data.reports.filter((report) => report.rawStatus === "pending").length;
  const reviewCount = data.reports.filter((report) => report.rawStatus === "in_review").length;
  const resolvedCount = data.reports.filter((report) => report.rawStatus === "resolved").length;

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Admin moderation"
        title="Review reported users, posts, and listings."
        description="This page is now gated by `profiles.is_admin` and loads the live reports queue from Supabase."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-warning">Pending</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">{pendingCount}</p>
        </Surface>
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-purple">In review</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">{reviewCount}</p>
        </Surface>
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-cyan">Resolved</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">{resolvedCount}</p>
        </Surface>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="space-y-4">
          {data.reports.map((report) => (
            <Surface key={report.id}>
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Pill active={report.rawStatus !== "resolved"}>{report.status}</Pill>
                    <p className="text-xs text-muted">{report.time}</p>
                  </div>
                  <h2 className="mt-3 font-heading text-xl font-semibold text-white">
                    {report.target}
                  </h2>
                  <p className="mt-3 text-sm leading-7 text-muted-strong">
                    <span className="font-medium text-white">Reason:</span> {report.reason}
                  </p>
                  <p className="mt-2 text-sm leading-7 text-muted">
                    Submitted by {report.submittedBy}
                  </p>
                  <p className="mt-2 text-sm leading-7 text-muted">{report.notes}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <form action={updateReportStatusAction}>
                    <input type="hidden" name="report_id" value={report.id} />
                    <input type="hidden" name="status" value="in_review" />
                    <button className="rounded-full border border-warning/30 bg-warning/10 px-4 py-2 text-sm font-medium text-warning">
                      Review
                    </button>
                  </form>
                  <form action={updateReportStatusAction}>
                    <input type="hidden" name="report_id" value={report.id} />
                    <input type="hidden" name="status" value="resolved" />
                    <button className="rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-medium text-cyan">
                      Resolve
                    </button>
                  </form>
                  <form action={updateReportStatusAction}>
                    <input type="hidden" name="report_id" value={report.id} />
                    <input type="hidden" name="status" value="dismissed" />
                    <button className="rounded-full border border-border bg-white/4 px-4 py-2 text-sm font-medium text-muted-strong hover:text-white">
                      Dismiss
                    </button>
                  </form>
                </div>
              </div>
            </Surface>
          ))}
        </div>

        <div className="space-y-4">
          <Surface>
            <h2 className="font-heading text-2xl font-semibold text-white">
              Review workflow
            </h2>
            <div className="mt-5 space-y-3">
              {moderationSteps.map((step, index) => (
                <div
                  key={step}
                  className="premium-card-soft flex items-center gap-4 rounded-3xl p-4"
                >
                  <div className="flex h-9 w-9 items-center justify-center rounded-full bg-cyan/12 text-sm font-semibold text-cyan">
                    {index + 1}
                  </div>
                  <div>
                    <p className="font-medium text-white">{step}</p>
                    <p className="mt-1 text-sm text-muted">
                      Stored against the live reports queue in Supabase.
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </Surface>

          <Surface>
            <h3 className="font-heading text-lg font-semibold text-white">
              Moderation principles
            </h3>
            <div className="mt-4 flex flex-wrap gap-2">
              <Pill>Misleading claims</Pill>
              <Pill>Spam and duplication</Pill>
              <Pill>Trust and safety</Pill>
              <Pill>Category misuse</Pill>
            </div>
          </Surface>
        </div>
      </div>
    </div>
  );
}
