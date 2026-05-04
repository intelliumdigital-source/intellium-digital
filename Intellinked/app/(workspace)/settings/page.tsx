import { EmptyState, PageIntro, Pill, Surface } from "@/app/_components/ui";

const preferenceGroups = [
  {
    title: "Profile visibility",
    items: ["Appear in explore search", "Show services on profile", "Display location publicly"],
  },
  {
    title: "Notifications",
    items: ["Lead inquiries", "Community mentions", "Moderation updates"],
  },
  {
    title: "Safety controls",
    items: ["Blocked users list", "Report history", "Sensitive category warnings"],
  },
];

export default function SettingsPage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Settings"
        title="Local-first preferences and trust controls."
        description="The settings page demonstrates how members will tune visibility, notifications, and moderation behavior once persistence is added."
      />

      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <Surface>
          <h2 className="font-heading text-2xl font-semibold text-white">Profile basics</h2>
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <label className="text-sm text-muted-strong">
              Display name
              <input
                className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                defaultValue="Mika Reyes"
              />
            </label>
            <label className="text-sm text-muted-strong">
              Location
              <input
                className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
                defaultValue="Makati City"
              />
            </label>
            <label className="text-sm text-muted-strong sm:col-span-2">
              Bio
              <textarea
                rows={5}
                className="input-shell mt-2 w-full rounded-[24px] px-4 py-3 text-white outline-none"
                defaultValue="Helping founders sharpen positioning, launch faster, and build credible community trust around premium local brands."
              />
            </label>
          </div>
        </Surface>

        <div className="grid gap-6 xl:grid-cols-3">
          {preferenceGroups.map((group) => (
            <Surface key={group.title}>
              <div className="flex items-center justify-between">
                <h2 className="font-heading text-xl font-semibold text-white">{group.title}</h2>
                <Pill active>Draft</Pill>
              </div>
              <div className="mt-5 space-y-3">
                {group.items.map((item) => (
                  <label
                    key={item}
                    className="premium-card-soft flex items-center justify-between rounded-3xl p-4 text-sm text-muted-strong"
                  >
                    <span>{item}</span>
                    <span className="h-6 w-11 rounded-full border border-cyan/20 bg-cyan/12" />
                  </label>
                ))}
              </div>
            </Surface>
          ))}
        </div>
      </div>

      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <EmptyState
          eyebrow="Safety"
          title="Blocked users list is still empty"
          description="The trust surface is staged now so backend-backed block lists and report history can be connected later without redesigning the page."
        />
        <Surface>
          <h2 className="font-heading text-2xl font-semibold text-white">Account note</h2>
          <p className="mt-4 max-w-3xl text-sm leading-7 text-muted">
            This MVP does not persist settings yet. The page exists to sell the product direction and show how user control and moderation tooling fit into the overall social platform.
          </p>
        </Surface>
      </div>
    </div>
  );
}
