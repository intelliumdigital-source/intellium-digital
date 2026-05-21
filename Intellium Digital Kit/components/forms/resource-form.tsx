"use client";

import { useActionState } from "react";

import { saveResourceAction } from "@/app/actions";
import { FormSubmitButton } from "@/components/shared/form-submit-button";
import { initialActionState } from "@/lib/action-state";
import { ResourceCategory, ResourceItem } from "@/lib/types";

const categories: ResourceCategory[] = [
  "start_here",
  "daily_workflow",
  "target_niches",
  "scripts",
  "niche_scripts",
  "objection_replies",
  "pricing",
  "qualification",
  "scoring",
  "commission",
  "handoff",
  "images",
  "daily_report",
  "dos_donts",
  "faq"
];

function formatCategoryLabel(category: ResourceCategory) {
  return category
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

export function ResourceForm({
  resource
}: {
  resource?: ResourceItem | null;
}) {
  const [state, formAction] = useActionState(saveResourceAction, initialActionState);

  return (
    <form action={formAction} className="card stack">
      <input type="hidden" name="id" defaultValue={resource?.id ?? ""} />

      <div className="field-grid">
        <div className="field">
          <label htmlFor={`category-${resource?.id ?? "new"}`}>Category</label>
          <select
            id={`category-${resource?.id ?? "new"}`}
            name="category"
            defaultValue={resource?.category ?? "scripts"}
          >
            {categories.map((category) => (
              <option key={category} value={category}>
                {formatCategoryLabel(category)}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor={`order-${resource?.id ?? "new"}`}>Display Order</label>
          <input
            id={`order-${resource?.id ?? "new"}`}
            name="order_index"
            type="number"
            min={0}
            defaultValue={resource?.order_index ?? 0}
          />
        </div>
      </div>

      <div className="field">
        <label htmlFor={`title-${resource?.id ?? "new"}`}>Title</label>
        <input
          id={`title-${resource?.id ?? "new"}`}
          name="title"
          defaultValue={resource?.title ?? ""}
          required
        />
      </div>

      <div className="field">
        <label htmlFor={`content-${resource?.id ?? "new"}`}>Content</label>
        <textarea
          id={`content-${resource?.id ?? "new"}`}
          name="content"
          defaultValue={resource?.content ?? ""}
          required
        />
      </div>

      <div className="field-grid">
        <div className="field">
          <label htmlFor={`link-${resource?.id ?? "new"}`}>Image / External Link</label>
          <input
            id={`link-${resource?.id ?? "new"}`}
            name="link_url"
            type="url"
            defaultValue={resource?.link_url ?? ""}
            placeholder="https://..."
          />
        </div>

        <div className="field">
          <label htmlFor={`published-${resource?.id ?? "new"}`}>Published</label>
          <select
            id={`published-${resource?.id ?? "new"}`}
            name="is_published"
            defaultValue={String(resource?.is_published ?? true)}
          >
            <option value="true">Published</option>
            <option value="false">Draft</option>
          </select>
        </div>
      </div>

      {state.status !== "idle" ? (
        <div className={`message ${state.status === "success" ? "message-success" : "message-error"}`}>
          {state.message}
        </div>
      ) : null}

      <FormSubmitButton
        label={resource ? "Update Resource" : "Create Resource"}
        pendingLabel={resource ? "Updating..." : "Creating..."}
      />
    </form>
  );
}
