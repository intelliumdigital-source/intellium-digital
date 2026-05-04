import Link from "next/link";

import { BrandLockup, EmptyState, Surface } from "@/app/_components/ui";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-[980px] items-center px-4 py-10 sm:px-6">
      <Surface className="w-full overflow-hidden">
        <div className="premium-grid absolute inset-0 opacity-40" />
        <div className="relative">
          <BrandLockup />
          <div className="mt-8">
            <EmptyState
              eyebrow="404"
              title="This intellinked page does not exist"
              description="The route may have moved, the mock data target may be missing, or the URL may be incomplete."
              action={
                <Link
                  href="/home"
                  className="inline-flex min-h-11 items-center justify-center rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:bg-cyan/18 hover:text-white"
                >
                  Back to home
                </Link>
              }
            />
          </div>
        </div>
      </Surface>
    </main>
  );
}
