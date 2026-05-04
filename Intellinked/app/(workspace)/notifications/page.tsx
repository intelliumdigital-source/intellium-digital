import { PageIntro, Pill, Surface } from "@/app/_components/ui";
import { notifications } from "@/app/_data/mock-data";

export default function NotificationsPage() {
  const engagementCount = notifications.filter(
    (notification) => notification.type === "Engagement",
  ).length;
  const leadCount = notifications.filter((notification) => notification.type === "Lead").length;

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Notifications"
        title="Keep the network responsive without building the backend yet."
        description="This placeholder page shows the kinds of social, lead, and moderation signals the product will surface."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-cyan">Unread signals</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">
            {notifications.length}
          </p>
        </Surface>
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-blue">Lead alerts</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">{leadCount}</p>
        </Surface>
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-purple">Engagement</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">
            {engagementCount}
          </p>
        </Surface>
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_0.72fr]">
        <div className="space-y-4">
          {notifications.map((notification) => (
            <Surface
              key={notification.id}
              className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
            >
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  <Pill active>{notification.type}</Pill>
                  <p className="text-xs text-muted">{notification.time}</p>
                </div>
                <h2 className="mt-3 font-heading text-xl font-semibold text-white">
                  {notification.title}
                </h2>
                <p className="mt-3 text-sm leading-7 text-muted-strong">
                  {notification.detail}
                </p>
              </div>
              <button className="rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
                Mark as seen
              </button>
            </Surface>
          ))}
        </div>

        <Surface>
          <h2 className="font-heading text-2xl font-semibold text-white">Priority queue</h2>
          <div className="mt-5 space-y-3">
            <div className="premium-card-soft rounded-[24px] p-4">
              <p className="text-sm font-medium text-white">Lead follow-ups</p>
              <p className="mt-2 text-sm leading-7 text-muted">
                High-intent inquiries should stay visible here before live inbox delivery exists.
              </p>
            </div>
            <div className="premium-card-soft rounded-[24px] p-4">
              <p className="text-sm font-medium text-white">Moderation updates</p>
              <p className="mt-2 text-sm leading-7 text-muted">
                Reviewed reports, warnings, and hidden content should be easy to confirm at a glance.
              </p>
            </div>
          </div>
        </Surface>
      </div>
    </div>
  );
}
