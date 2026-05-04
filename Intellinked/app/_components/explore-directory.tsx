"use client";

import { useDeferredValue, useState } from "react";
import { Search } from "lucide-react";

import {
  BusinessCard,
  EmptyState,
  Pill,
  ProfileCard,
  ServiceCard,
  Surface,
} from "@/app/_components/ui";
import { categories } from "@/app/_data/mock-data";
import type {
  BusinessView,
  ProfileView,
  ServiceListingView,
} from "@/lib/social/types";

type Focus = "All" | "People" | "Businesses" | "Services";

export function ExploreDirectory({
  people,
  businesses,
  services,
  initialQuery = "",
  initialCategory = "All",
}: {
  people: ProfileView[];
  businesses: BusinessView[];
  services: ServiceListingView[];
  initialQuery?: string;
  initialCategory?: string;
}) {
  const [query, setQuery] = useState(initialQuery);
  const [selectedCategory, setSelectedCategory] = useState<string>(initialCategory);
  const [focus, setFocus] = useState<Focus>("All");

  const deferredQuery = useDeferredValue(query);
  const normalizedQuery = deferredQuery.toLowerCase().trim();

  const filteredPeople = people.filter((person) => {
    const matchesQuery =
      !normalizedQuery ||
      person.fullName.toLowerCase().includes(normalizedQuery) ||
      person.role.toLowerCase().includes(normalizedQuery) ||
      person.skills.join(" ").toLowerCase().includes(normalizedQuery) ||
      person.bio.toLowerCase().includes(normalizedQuery);

    const matchesCategory =
      selectedCategory === "All" || person.focusCategory === selectedCategory;

    return matchesQuery && matchesCategory;
  });

  const filteredBusinesses = businesses.filter((business) => {
    const matchesQuery =
      !normalizedQuery ||
      business.businessName.toLowerCase().includes(normalizedQuery) ||
      business.description.toLowerCase().includes(normalizedQuery) ||
      business.servicesOffered.join(" ").toLowerCase().includes(normalizedQuery);

    const matchesCategory =
      selectedCategory === "All" || business.category === selectedCategory;

    return matchesQuery && matchesCategory;
  });

  const filteredServices = services.filter((service) => {
    const matchesQuery =
      !normalizedQuery ||
      service.title.toLowerCase().includes(normalizedQuery) ||
      service.providerName.toLowerCase().includes(normalizedQuery) ||
      service.summary.toLowerCase().includes(normalizedQuery) ||
      service.tags.join(" ").toLowerCase().includes(normalizedQuery);

    const matchesCategory =
      selectedCategory === "All" || service.category === selectedCategory;

    return matchesQuery && matchesCategory;
  });

  const showPeople = focus === "All" || focus === "People";
  const showBusinesses = focus === "All" || focus === "Businesses";
  const showServices = focus === "All" || focus === "Services";
  const totalResults =
    filteredPeople.length + filteredBusinesses.length + filteredServices.length;

  return (
    <div className="space-y-6">
      <Surface>
        <div className="flex flex-col gap-4">
          <label className="input-shell flex items-center gap-3 rounded-3xl px-4 py-4 text-sm text-muted">
            <Search className="h-4 w-4 text-cyan" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search people, businesses, and services"
              className="w-full bg-transparent text-white outline-none placeholder:text-muted"
            />
          </label>

          <div className="flex flex-wrap gap-2">
            {(["All", "People", "Businesses", "Services"] as Focus[]).map((item) => (
              <button
                key={item}
                onClick={() => setFocus(item)}
                className="rounded-full"
                type="button"
              >
                <Pill active={focus === item}>{item}</Pill>
              </button>
            ))}
          </div>

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

      <div className="flex items-center justify-between">
        <p className="text-sm text-muted">{totalResults} matches in the local demo network</p>
        {(query || selectedCategory !== "All") && (
          <button
            type="button"
            onClick={() => {
              setQuery("");
              setSelectedCategory("All");
            }}
            className="text-sm text-cyan hover:text-white"
          >
            Clear filters
          </button>
        )}
      </div>

      {totalResults === 0 ? (
        <EmptyState
          eyebrow="Discovery"
          title="No results matched this filter set"
          description="Try a broader category or remove a keyword to reopen the discovery pool."
        />
      ) : null}

      {showPeople && filteredPeople.length > 0 ? (
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="font-heading text-xl font-semibold text-white">People</h2>
            <p className="text-sm text-muted">{filteredPeople.length} profiles</p>
          </div>
          <div className="grid gap-4 lg:grid-cols-2">
            {filteredPeople.map((person) => (
              <ProfileCard key={person.slug} person={person} />
            ))}
          </div>
        </section>
      ) : null}

      {showBusinesses && filteredBusinesses.length > 0 ? (
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="font-heading text-xl font-semibold text-white">Businesses</h2>
            <p className="text-sm text-muted">{filteredBusinesses.length} listings</p>
          </div>
          <div className="grid gap-4 lg:grid-cols-2">
            {filteredBusinesses.map((business) => (
              <BusinessCard key={business.slug} business={business} />
            ))}
          </div>
        </section>
      ) : null}

      {showServices && filteredServices.length > 0 ? (
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="font-heading text-xl font-semibold text-white">Services</h2>
            <p className="text-sm text-muted">{filteredServices.length} offers</p>
          </div>
          <div className="grid gap-4 lg:grid-cols-2">
            {filteredServices.map((service) => (
              <ServiceCard key={service.id} service={service} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
