import { Globe, Shield, SlidersHorizontal } from "lucide-react";
import { CrmShell } from "@/components/crm-shell";
import { SectionCard } from "@/components/section-card";

const settingsGroups = [
  {
    title: "Brand Profile",
    icon: Globe,
    items: [
      "Product: IntelliLead",
      "Parent brand: Intellium Digital",
      "Website: intelliumdigital.online",
      "Facebook: facebook.com/IntelliumDigitalPH"
    ]
  },
  {
    title: "Workflow Defaults",
    icon: SlidersHorizontal,
    items: ["Lead statuses ready", "Mock local data enabled", "Quotation module active", "Dashboard metrics configured"]
  },
  {
    title: "Access & Security",
    icon: Shield,
    items: ["Login UI prepared", "Authentication pending", "Supabase not connected", "Demo mode on"]
  }
];

export default function SettingsPage() {
  return (
    <CrmShell subtitle="Manage product identity, workflow defaults, and app readiness." title="Settings">
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
              title={group.title}
            >
              <div className="space-y-3 text-sm text-slate-300">
                {group.items.map((item) => (
                  <p key={item} className="rounded-2xl border border-white/10 bg-slate-950/40 px-4 py-3">
                    {item}
                  </p>
                ))}
              </div>
            </SectionCard>
          );
        })}
      </div>
    </CrmShell>
  );
}
