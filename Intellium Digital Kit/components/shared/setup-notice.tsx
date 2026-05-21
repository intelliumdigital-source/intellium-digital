export function SetupNotice() {
  return (
    <main className="page-shell">
      <section className="card">
        <p className="eyebrow">Setup Required</p>
        <h1 className="section-title">Connect Supabase to activate the portal.</h1>
        <p className="section-description">
          Add <code>NEXT_PUBLIC_SUPABASE_URL</code> and{" "}
          <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> to your environment, then apply the
          SQL schema in <code>supabase/schema.sql</code>.
        </p>
      </section>
    </main>
  );
}
