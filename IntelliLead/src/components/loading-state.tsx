export function LoadingState() {
  return (
    <div className="space-y-6 animate-pulse">
      <div className="grid gap-4 lg:grid-cols-5">
        {Array.from({ length: 5 }).map((_, index) => (
          <div key={index} className="rounded-[28px] border border-white/10 bg-white/5 p-5">
            <div className="h-12 w-12 rounded-2xl bg-white/10" />
            <div className="mt-6 h-4 w-24 rounded-full bg-white/10" />
            <div className="mt-3 h-8 w-32 rounded-full bg-white/10" />
          </div>
        ))}
      </div>
      <div className="grid gap-6 xl:grid-cols-2">
        <div className="rounded-[28px] border border-white/10 bg-white/5 p-6">
          <div className="h-5 w-48 rounded-full bg-white/10" />
          <div className="mt-6 space-y-4">
            {Array.from({ length: 5 }).map((_, index) => (
              <div key={index} className="h-4 rounded-full bg-white/10" />
            ))}
          </div>
        </div>
        <div className="rounded-[28px] border border-white/10 bg-white/5 p-6">
          <div className="h-5 w-40 rounded-full bg-white/10" />
          <div className="mt-6 grid gap-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <div key={index} className="h-20 rounded-[24px] bg-white/10" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
