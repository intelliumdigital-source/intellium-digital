import { cn, StatusTone } from "@/lib/utils";

export function StatusBadge({
  label,
  tone
}: {
  label: string;
  tone: StatusTone;
}) {
  return <span className={cn("badge", `badge-${tone}`)}>{label}</span>;
}
