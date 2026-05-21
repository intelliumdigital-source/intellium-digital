"use client";

export default function Error({
  error,
  reset
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="page-shell">
      <section className="card">
        <p className="eyebrow">Portal Error</p>
        <h1 className="section-title">Something went wrong.</h1>
        <p className="section-description">{error.message}</p>
        <button className="button" onClick={() => reset()}>
          Retry
        </button>
      </section>
    </main>
  );
}
