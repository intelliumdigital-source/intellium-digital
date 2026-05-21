import { Logo } from "@/components/logo";

export default function AppLoading() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-ink px-6">
      <div className="w-full max-w-md rounded-[32px] border border-white/10 bg-white/[0.04] p-8 text-center shadow-glow">
        <div className="mx-auto flex w-fit justify-center">
          <Logo />
        </div>
        <p className="mt-6 text-sm uppercase tracking-[0.24em] text-cyan">Loading Workspace</p>
        <div className="mt-6 h-2 overflow-hidden rounded-full bg-white/10">
          <div className="h-full w-1/2 animate-pulse rounded-full bg-gradient-to-r from-cyan via-blue to-violet" />
        </div>
      </div>
    </div>
  );
}
