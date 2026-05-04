"use client";

import { useDeferredValue, useState } from "react";
import { Search } from "lucide-react";

import { EmptyState, Pill, ServiceCard, Surface } from "@/app/_components/ui";
import { categories } from "@/app/_data/mock-data";
import type { ServiceListingView } from "@/lib/social/types";

export function ServicesDirectory({
  services,
  initialQuery = "",
  initialCategory = "All",
}: {
  services: ServiceListingView[];
  initialQuery?: string;
  initialCategory?: string;
}) {
  const [query, setQuery] = useState(initialQuery);
  const [selectedCategory, setSelectedCategory] = useState<string>(initialCategory);

  const deferredQuery = useDeferredValue(query);
  const normalizedQuery = deferredQuery.toLowerCase().trim();

  const filteredServices = services.filter((service) => {
    const matchesQuery =
      !normalizedQuery ||
      service.title.toLowerCase().includes(normalizedQuery) ||
      service.providerName.toLowerCase().includes(normalizedQuery) ||
      (service.businessName?.toLowerCase().includes(normalizedQuery) ?? false) ||
      service.summary.toLowerCase().includes(normalizedQuery) ||
      service.tags.join(" ").toLowerCase().includes(normalizedQuery);

    const matchesCategory =
      selectedCategory === "All" || service.category === selectedCategory;

    return matchesQuery && matchesCategory;
  });

  return (
    <div className="space-y-6">
      <Surface>
        <div className="flex flex-col gap-4">
          <label className="input-shell flex items-center gap-3 rounded-3xl px-4 py-4 text-sm text-muted">
            <Search className="h-4 w-4 text-cyan" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search offers, skills, price range, or provider"
              className="w-full bg-transparent text-white outline-none placeholder:text-muted"
            />
          </label>

          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setSelectedCategory("All")}
              className="rounded-full"
              type="button"
            >
              <Pill active={selectedCategory === "All"}>All categories</Pill>
            </button>
            {categories.map((category) => (
              <button
                key={category}
                onClick={() => setSelectedCategory(category)}
                className="rounded-full"
                type="button"
              >
                <Pill active={selectedCategory === category}>{category}</Pill>
              </button>
            ))}
          </div>
        </div>
      </Surface>

      <Surface>
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="font-heading text-xl font-semibold text-white">
              Service marketplace snapshot
            </h2>
            <p className="mt-2 text-sm text-muted">
              {filteredServices.length} visible offers across local-first categories.
            </p>
          </div>
          {(query || selectedCategory !== "All") && (
            <button
              type="button"
              onClick={() => {
                setQuery("");
                setSelectedCategory("All");
              }}
              className="text-sm text-cyan hover:text-white"
            >
              Reset filters
            </button>
          )}
        </div>
      </Surface>

      {filteredServices.length === 0 ? (
        <EmptyState
          eyebrow="Directory"
          title="No service listings matched"
          description="Try a different keyword or switch back to all categories to see the current local-first service set."
        />
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          {filteredServices.map((service) => (
            <ServiceCard key={service.id} service={service} />
          ))}
        </div>
      )}
    </div>
  );
}
