import { PageIntro, Pill, Surface } from "@/app/_components/ui";
import { notifications } from "@/app/_data/mock-data";

export default function NotificationsPage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Notifications"
        title="Keep the network responsive without building the backend yet."
        description="This placeholder page shows the kinds of social, lead, and moderation signals the product will surface."
      />

      <div className="space-y-4">
        {notifications.map((notification) => (
          <Surface key={notification.id} className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
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
    </div>
  );
}
