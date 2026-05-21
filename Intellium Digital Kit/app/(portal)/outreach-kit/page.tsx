import Link from "next/link";

import { CopyButton } from "@/components/shared/copy-button";
import { EmptyState } from "@/components/shared/empty-state";
import { SetupNotice } from "@/components/shared/setup-notice";
import {
  fallbackResourceContent,
  outreachSections,
  targetClients
} from "@/lib/data/outreach-kit";
import { requireAuthenticatedProfile } from "@/lib/auth";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { ResourceItem } from "@/lib/types";
import type { TrainingResourceItem } from "@/lib/data/outreach-kit";

type DisplayItem = {
  title: string;
  content: string;
  linkUrl?: string | null;
  tags?: string[];
};

function toDisplayItems(items: ResourceItem[] | TrainingResourceItem[]): DisplayItem[] {
  return items.map((item) => ({
    title: item.title,
    content: item.content,
    linkUrl: "link_url" in item ? item.link_url : item.linkUrl,
    tags: "tags" in item ? item.tags : undefined
  }));
}

function mergeDisplayItems(
  fallbackItems: TrainingResourceItem[],
  resourceItems: ResourceItem[]
) {
  const merged = new Map<string, DisplayItem>();

  for (const item of toDisplayItems(fallbackItems)) {
    merged.set(item.title, item);
  }

  for (const item of toDisplayItems(resourceItems)) {
    merged.set(item.title, item);
  }

  return Array.from(merged.values());
}

export default async function OutreachKitPage() {
  const session = await requireAuthenticatedProfile();

  if (!session.configured) {
    return <SetupNotice />;
  }

  const supabase = await createServerSupabaseClient();
  const { data } = await supabase
    .from("resource_items")
    .select("*")
    .eq("is_published", true)
    .order("category", { ascending: true })
    .order("order_index", { ascending: true });

  const resourceItems = (data ?? []) as ResourceItem[];

  return (
    <div className="page-shell stack">
      <section className="hero-card">
        <div className="page-header" style={{ marginBottom: "1rem" }}>
          <div>
            <p className="eyebrow">Intellium Digital Outreach Kit</p>
            <h1 className="title">Researcher Training Center</h1>
            <p className="subtitle">
              Approved scripts, niche playbooks, qualification rules, image guidance,
              handoff standards, pricing transitions, and commission policy for
              commission-based outreach researchers.
            </p>
          </div>
          <div className="inline-actions">
            <Link className="button-secondary" href="https://www.intelliumdigital.online/" target="_blank" rel="noreferrer noopener">
              Visit Website
            </Link>
            <Link className="button-ghost" href="https://www.facebook.com/IntelliumDigitalPH" target="_blank" rel="noreferrer noopener">
              Facebook Page
            </Link>
            {session.profile?.role === "admin" ? (
              <Link className="button" href="/admin/resources">
                Edit Resources
              </Link>
            ) : null}
          </div>
        </div>

        <div className="grid grid-3">
          <div className="card">
            <p className="metric-label">Business</p>
            <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
              Intellium Digital
            </p>
            <p style={{ margin: "0.55rem 0 0" }}>Legitimize. Digitize. Grow.</p>
          </div>
          <div className="card">
            <p className="metric-label">Main Offer</p>
            <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
              Websites, branding, inquiry forms, booking pages, payment-ready setup,
              SEO, automation, launch graphics, and business apps.
            </p>
          </div>
          <div className="card">
            <p className="metric-label">Researcher Rule</p>
            <p style={{ margin: "0.35rem 0 0", color: "var(--text-soft)" }}>
              Find real businesses, qualify honestly, use approved scripts, submit
              proof, and hand off warm leads. Do not negotiate final pricing or collect
              payment.
            </p>
          </div>
        </div>
      </section>

      <section className="card">
        <div className="page-header" style={{ marginBottom: "0.8rem" }}>
          <div>
            <h2 className="section-title">Section Navigator</h2>
            <p className="section-description">
              Jump directly to the training section you need.
            </p>
          </div>
        </div>
        <nav className="pill-nav">
          {outreachSections.map((section) => (
            <a key={section.category} href={`#${section.category}`} className="pill-link">
              {section.title}
            </a>
          ))}
        </nav>
      </section>

      <section className="card">
        <h2 className="section-title">Priority Client Types</h2>
        <p className="section-description">
          Focus your research on active businesses that are visible online but still
          digitally unstructured.
        </p>
        <div className="inline-actions">
          {targetClients.map((client) => (
            <span key={client} className="badge badge-neutral">
              {client}
            </span>
          ))}
        </div>
      </section>

      {outreachSections.map((section) => {
        const items = resourceItems.filter((item) => item.category === section.category);
        const displayItems = mergeDisplayItems(
          fallbackResourceContent[section.category],
          items
        );
        const contentClassName =
          section.category === "target_niches" || section.category === "faq"
            ? "grid grid-2"
            : "stack";

        return (
          <section
            key={section.category}
            id={section.category}
            className="card"
            style={{ scrollMarginTop: "1rem" }}
          >
            <div className="page-header">
              <div>
                <h2 className="section-title">{section.title}</h2>
                <p className="section-description">{section.description}</p>
              </div>
            </div>

            {displayItems.length === 0 ? (
              <EmptyState
                title="No published resources"
                description="Admins can add this section's content from the Resources page."
              />
            ) : (
              <div className={contentClassName}>
                {displayItems.map((item) => (
                  <article key={`${section.category}-${item.title}`} className="card">
                    <div className="page-header" style={{ marginBottom: "0.9rem" }}>
                      <div>
                        <h3 className="section-title" style={{ marginBottom: "0.3rem" }}>
                          {item.title}
                        </h3>
                        {item.tags?.length ? (
                          <div className="inline-actions">
                            {item.tags.map((tag) => (
                              <span key={`${item.title}-${tag}`} className="badge badge-info">
                                {tag}
                              </span>
                            ))}
                          </div>
                        ) : null}
                        {item.linkUrl ? (
                          <Link
                            href={item.linkUrl}
                            target="_blank"
                            rel="noreferrer noopener"
                            className="helper-text"
                          >
                            {item.linkUrl}
                          </Link>
                        ) : null}
                      </div>

                      {section.copyable ? <CopyButton value={item.content} /> : null}
                    </div>

                    <pre
                      style={{
                        margin: 0,
                        whiteSpace: "pre-wrap",
                        color: "var(--text-soft)",
                        lineHeight: 1.75,
                        fontFamily: "inherit"
                      }}
                    >
                      {item.content}
                    </pre>
                  </article>
                ))}
              </div>
            )}
          </section>
        );
      })}
    </div>
  );
}
