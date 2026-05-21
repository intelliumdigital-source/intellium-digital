export function EmptyState({
  title,
  description
}: {
  title: string;
  description: string;
}) {
  return (
    <div className="empty-state">
      <h3 className="section-title">{title}</h3>
      <p className="section-description" style={{ marginBottom: 0 }}>
        {description}
      </p>
    </div>
  );
}
