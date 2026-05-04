import { LoadingPanel, Surface } from "@/app/_components/ui";

export default function WorkspaceLoading() {
  return (
    <div className="space-y-6">
      <Surface className="overflow-hidden">
        <div className="premium-grid absolute inset-0 opacity-35" />
        <div className="relative space-y-4">
          <div className="skeleton-bar h-3 w-28 rounded-full" />
          <div className="skeleton-bar h-10 w-2/3 rounded-full" />
          <div className="skeleton-bar h-5 w-full rounded-full" />
        </div>
      </Surface>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <LoadingPanel title="Loading metrics" />
        <LoadingPanel title="Loading metrics" />
        <LoadingPanel title="Loading metrics" />
        <LoadingPanel title="Loading metrics" />
      </div>
      <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
        <LoadingPanel title="Loading feed" />
        <LoadingPanel title="Loading spotlight" />
      </div>
    </div>
  );
}
