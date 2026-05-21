import { Globe, Link2Off, Shield, SlidersHorizontal } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { EmptyState } from "@/components/empty-state";
import { SectionCard } from "@/components/section-card";
import { routes } from "@/lib/routes";

const settingsGroups = [
  {
    title: "Brand Profile",
    icon: Globe,
    items: [
      "Product: IntelliLead",
      "Parent brand: Intellium Digital",
      "Tagline: Smart lead tracking for growing businesses.",
      "Website: intelliumdigital.online",
      "Facebook: facebook.com/IntelliumDigitalPH"
    ]
  },
  {
    title: "Workflow Defaults",
    icon: SlidersHorizontal,
    items: ["Lead statuses ready", "Mock local data enabled", "Quotation module active", "Responsive dashboard shell configured"]
  },
  {
    title: "Access and Security",
    icon: Shield,
    items: ["Login UI prepared", "Authentication intentionally disabled", "Supabase not connected", "Demo mode only"]
  }
];

export default function SettingsPage() {
  return (
    <CrmShell subtitle="Manage product identity, workflow defaults, and integration readiness." title="Settings">
      <div className="grid gap-6 xl:grid-cols-3">
        {settingsGroups.map((group) => {
          const Icon = group.icon;
          return (
            <SectionCard
              key={group.title}
              action={
                <div className="rounded-2xl border border-cyan/20 bg-cyan/10 p-2 text-cyan">
                  <Icon className="h-4 w-4" />
                </div>
              }
              description="Prepared for later database and auth integration."
              title={group.title}
            >
              <div className="space-y-3 text-sm text-slate-300">
                {group.items.map((item) => (
                  <p key={item} className="rounded-[24px] border border-white/10 bg-slate-950/40 px-4 py-3">
                    {item}
                  </p>
                ))}
              </div>
            </SectionCard>
          );
        })}
      </div>

      <div className="mt-6">
        <EmptyState
          ctaHref={routes.dashboard}
          ctaLabel="Return to Dashboard"
          description="No live integrations are enabled yet. This is the correct state for the MVP while mock data remains the source of truth."
          eyebrow="Integration Status"
          icon={<Link2Off className="h-5 w-5" />}
          title="Supabase and real auth are still intentionally offline"
        />
      </div>
    </CrmShell>
  );
}
