import { PageIntro, Pill, Surface } from "@/app/_components/ui";
import { reports } from "@/app/_data/mock-data";

const moderationSteps = ["Review", "Hide or warn", "Escalate", "Resolve"];

export default function AdminPage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Admin moderation"
        title="Review reported users, posts, and listings."
        description="This admin page proves moderation is part of the MVP. Everything remains local and presentational, but the workflow is already visible and pitchable."
      />

      <div className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
        <div className="space-y-4">
          {reports.map((report) => (
            <Surface key={report.id}>
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Pill active={report.status !== "Resolved"}>{report.status}</Pill>
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
                  <button className="rounded-full border border-warning/30 bg-warning/10 px-4 py-2 text-sm font-medium text-warning">
                    Escalate
                  </button>
                  <button className="rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-medium text-cyan">
                    Resolve
                  </button>
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
                      Moderator-facing action placeholder for the MVP.
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
