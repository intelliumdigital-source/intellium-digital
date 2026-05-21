export default function Loading() {
  return (
    <main className="page-shell">
      <div className="loading-grid">
        <div className="skeleton" />
        <div className="grid grid-3">
          <div className="skeleton" />
          <div className="skeleton" />
          <div className="skeleton" />
        </div>
        <div className="skeleton" style={{ minHeight: 360 }} />
      </div>
    </main>
  );
}
