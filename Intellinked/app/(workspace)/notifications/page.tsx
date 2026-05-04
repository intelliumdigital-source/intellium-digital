import { markNotificationReadAction } from "@/app/actions/workspace";
import { EmptyState, PageIntro, Pill, Surface } from "@/app/_components/ui";
import { requireSessionUser } from "@/lib/auth/session";
import { getNotificationsPageData } from "@/lib/social/queries";

export default async function NotificationsPage() {
  const user = await requireSessionUser();
  const data = await getNotificationsPageData(user.id);
  const unreadCount = data.notifications.filter((notification) => !notification.isRead).length;
  const leadCount = data.notifications.filter((notification) =>
    notification.type.toLowerCase().includes("lead"),
  ).length;
  const engagementCount = data.notifications.filter((notification) =>
    notification.type.toLowerCase().includes("engagement"),
  ).length;

  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Notifications"
        title="Keep the network responsive with live workspace signals."
        description="Notifications now read from Supabase when available. Message threads still remain intentionally placeholder-only."
      />

      <div className="grid gap-4 md:grid-cols-3">
        <Surface>
          <p className="text-xs uppercase tracking-[0.18em] text-cyan">Unread signals</p>
          <p className="mt-3 font-heading text-3xl font-semibold text-white">
            {unreadCount}
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

      {data.notifications.length === 0 ? (
        <EmptyState
          eyebrow="Notifications"
          title="No live notifications yet"
          description="Likes, follows, comments, and moderation updates will appear here as the workspace becomes more active."
        />
      ) : (
        <div className="grid gap-6 xl:grid-cols-[1fr_0.72fr]">
          <div className="space-y-4">
            {data.notifications.map((notification) => (
              <Surface
                key={notification.id}
                className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
              >
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <Pill active={!notification.isRead}>{notification.type}</Pill>
                    <p className="text-xs text-muted">{notification.time}</p>
                  </div>
                  <h2 className="mt-3 font-heading text-xl font-semibold text-white">
                    {notification.title}
                  </h2>
                  <p className="mt-3 text-sm leading-7 text-muted-strong">
                    {notification.detail}
                  </p>
                </div>
                {!notification.isRead ? (
                  <form action={markNotificationReadAction}>
                    <input type="hidden" name="notification_id" value={notification.id} />
                    <button className="rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
                      Mark as seen
                    </button>
                  </form>
                ) : (
                  <Pill>Read</Pill>
                )}
              </Surface>
            ))}
          </div>

          <Surface>
            <h2 className="font-heading text-2xl font-semibold text-white">Priority queue</h2>
            <div className="mt-5 space-y-3">
              <div className="premium-card-soft rounded-[24px] p-4">
                <p className="text-sm font-medium text-white">Lead follow-ups</p>
                <p className="mt-2 text-sm leading-7 text-muted">
                  High-intent inquiries and community responses will become more useful here as notifications accumulate.
                </p>
              </div>
              <div className="premium-card-soft rounded-[24px] p-4">
                <p className="text-sm font-medium text-white">Moderation updates</p>
                <p className="mt-2 text-sm leading-7 text-muted">
                  Reports and trust actions can now surface here when notification records exist.
                </p>
              </div>
            </div>
          </Surface>
        </div>
      )}
    </div>
  );
}
