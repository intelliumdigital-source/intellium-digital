import { statusColor } from "@/lib/utils";

export function StatusBadge({ label }: { label: string }) {
  return <span className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ring-1 ${statusColor(label)}`}>{label}</span>;
}
