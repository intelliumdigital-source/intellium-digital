"use client";

import { useActionState } from "react";

import { saveAnnouncementAction } from "@/app/actions";
import { FormSubmitButton } from "@/components/shared/form-submit-button";
import { initialActionState } from "@/lib/action-state";
import { Announcement } from "@/lib/types";

export function AnnouncementForm({
  announcement
}: {
  announcement?: Announcement | null;
}) {
  const [state, formAction] = useActionState(
    saveAnnouncementAction,
    initialActionState
  );

  return (
    <form action={formAction} className="card stack">
      <input type="hidden" name="id" defaultValue={announcement?.id ?? ""} />

      <div className="field">
        <label htmlFor={`announcement-title-${announcement?.id ?? "new"}`}>Title</label>
        <input
          id={`announcement-title-${announcement?.id ?? "new"}`}
          name="title"
          defaultValue={announcement?.title ?? ""}
          required
        />
      </div>

      <div className="field">
        <label htmlFor={`announcement-content-${announcement?.id ?? "new"}`}>Content</label>
        <textarea
          id={`announcement-content-${announcement?.id ?? "new"}`}
          name="content"
          defaultValue={announcement?.content ?? ""}
          required
        />
      </div>

      <div className="field-grid">
        <div className="field">
          <label htmlFor={`announcement-pinned-${announcement?.id ?? "new"}`}>Pinned</label>
          <select
            id={`announcement-pinned-${announcement?.id ?? "new"}`}
            name="is_pinned"
            defaultValue={String(announcement?.is_pinned ?? false)}
          >
            <option value="false">No</option>
            <option value="true">Yes</option>
          </select>
        </div>

        <div className="field">
          <label htmlFor={`announcement-published-${announcement?.id ?? "new"}`}>Published</label>
          <select
            id={`announcement-published-${announcement?.id ?? "new"}`}
            name="is_published"
            defaultValue={String(announcement?.is_published ?? true)}
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
        label={announcement ? "Update Announcement" : "Post Announcement"}
        pendingLabel={announcement ? "Updating..." : "Posting..."}
      />
    </form>
  );
}
