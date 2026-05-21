export function StatCard({
  label,
  value,
  note
}: {
  label: string;
  value: string | number;
  note?: string;
}) {
  return (
    <article className="card metric-card">
      <p className="metric-label">{label}</p>
      <p className="metric-value">{value}</p>
      {note ? <p className="metric-note">{note}</p> : null}
    </article>
  );
}
