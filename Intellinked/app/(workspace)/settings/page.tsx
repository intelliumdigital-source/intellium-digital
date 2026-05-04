import { PageIntro, Pill, Surface } from "@/app/_components/ui";

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

      <Surface>
        <h2 className="font-heading text-2xl font-semibold text-white">Account note</h2>
        <p className="mt-4 max-w-3xl text-sm leading-7 text-muted">
          This MVP does not persist settings yet. The page exists to sell the product direction and show how user control and moderation tooling fit into the overall social platform.
        </p>
      </Surface>
    </div>
  );
}
