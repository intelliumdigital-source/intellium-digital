"use client";

import { useActionState, useEffect, useState } from "react";

import { submitLeadAction } from "@/app/actions";
import { FormSubmitButton } from "@/components/shared/form-submit-button";
import { initialActionState } from "@/lib/action-state";
import { recommendedServices, targetClients } from "@/lib/data/outreach-kit";

type DuplicateState = {
  loading: boolean;
  message: string;
  hasDuplicate: boolean;
};

const initialDuplicateState: DuplicateState = {
  loading: false,
  message: "",
  hasDuplicate: false
};

export function SubmitLeadForm() {
  const [state, formAction] = useActionState(submitLeadAction, initialActionState);
  const [businessName, setBusinessName] = useState("");
  const [businessLink, setBusinessLink] = useState("");
  const [duplicateState, setDuplicateState] = useState(initialDuplicateState);

  useEffect(() => {
    const shouldCheck = businessName.trim().length >= 2 || businessLink.trim().length >= 4;

    if (!shouldCheck) {
      setDuplicateState(initialDuplicateState);
      return;
    }

    const timeout = window.setTimeout(async () => {
      setDuplicateState((current) => ({ ...current, loading: true }));

      const params = new URLSearchParams();
      if (businessName.trim()) {
        params.set("businessName", businessName);
      }
      if (businessLink.trim()) {
        params.set("businessLink", businessLink);
      }

      const response = await fetch(`/api/leads/check-duplicate?${params.toString()}`);
      const payload = (await response.json()) as {
        hasDuplicate: boolean;
        message: string;
      };

      setDuplicateState({
        loading: false,
        hasDuplicate: payload.hasDuplicate,
        message: payload.message
      });
    }, 450);

    return () => window.clearTimeout(timeout);
  }, [businessLink, businessName]);

  return (
    <form action={formAction} className="stack">
      <div className="field-grid">
        <div className="field">
          <label htmlFor="business_name">
            Business Name <span className="required">*</span>
          </label>
          <input
            id="business_name"
            name="business_name"
            required
            placeholder="Luna Skin Studio"
            onChange={(event) => setBusinessName(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="business_type">
            Business Type <span className="required">*</span>
          </label>
          <input
            id="business_type"
            name="business_type"
            list="target-client-types"
            required
            placeholder="Salon"
          />
          <datalist id="target-client-types">
            {targetClients.map((clientType) => (
              <option key={clientType} value={clientType} />
            ))}
          </datalist>
        </div>

        <div className="field">
          <label htmlFor="location">
            Location <span className="required">*</span>
          </label>
          <input id="location" name="location" required placeholder="Quezon City" />
        </div>

        <div className="field">
          <label htmlFor="business_link">Business Link</label>
          <input
            id="business_link"
            name="business_link"
            placeholder="https://facebook.com/example-business"
            onChange={(event) => setBusinessLink(event.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="owner_contact_name">Owner / Contact Name</label>
          <input id="owner_contact_name" name="owner_contact_name" placeholder="Maria Santos" />
        </div>

        <div className="field">
          <label htmlFor="has_website">
            Does the business have a website? <span className="required">*</span>
          </label>
          <select id="has_website" name="has_website" defaultValue="no" required>
            <option value="no">No</option>
            <option value="yes">Yes</option>
          </select>
        </div>

        <div className="field">
          <label htmlFor="recommended_service">
            Recommended Service <span className="required">*</span>
          </label>
          <select id="recommended_service" name="recommended_service" defaultValue="" required>
            <option value="" disabled>
              Select a service
            </option>
            {recommendedServices.map((service) => (
              <option key={service} value={service}>
                {service}
              </option>
            ))}
          </select>
        </div>

        <div className="field">
          <label htmlFor="lead_score">
            Lead Score <span className="required">*</span>
          </label>
          <input id="lead_score" name="lead_score" type="number" min={0} max={100} required placeholder="80" />
        </div>

        <div className="field">
          <label htmlFor="message_sent">
            Message Sent? <span className="required">*</span>
          </label>
          <select id="message_sent" name="message_sent" defaultValue="yes" required>
            <option value="yes">Yes</option>
            <option value="no">No</option>
          </select>
        </div>

        <div className="field">
          <label htmlFor="reply_status">Reply Status</label>
          <input id="reply_status" name="reply_status" placeholder="No reply yet" />
        </div>

        <div className="field">
          <label htmlFor="interested">
            Interested? <span className="required">*</span>
          </label>
          <select id="interested" name="interested" defaultValue="no" required>
            <option value="no">No</option>
            <option value="yes">Yes</option>
          </select>
        </div>

        <div className="field">
          <label htmlFor="budget_mentioned">Budget Mentioned</label>
          <input id="budget_mentioned" name="budget_mentioned" placeholder="PHP 10,000" />
        </div>

        <div className="field">
          <label htmlFor="screenshot">
            Screenshot / Proof Upload <span className="required">*</span>
          </label>
          <input id="screenshot" name="screenshot" type="file" accept="image/*,.pdf" required />
          <span className="helper-text">Accepted: images or PDF proof. Required for commission validation.</span>
        </div>
      </div>

      <div className="field">
        <label htmlFor="problem_found">
          Problem Found <span className="required">*</span>
        </label>
        <textarea
          id="problem_found"
          name="problem_found"
          required
          placeholder="No website, outdated branding, low trust signals, no payment setup..."
        />
      </div>

      <div className="field">
        <label htmlFor="notes">Notes</label>
        <textarea
          id="notes"
          name="notes"
          placeholder="Add context, objections, timing, or follow-up details."
        />
      </div>

      {duplicateState.loading ? (
        <div className="message message-warning">Checking for duplicate leads...</div>
      ) : null}

      {!duplicateState.loading && duplicateState.message ? (
        <div
          className={`message ${duplicateState.hasDuplicate ? "message-error" : "message-success"}`}
        >
          {duplicateState.message}
        </div>
      ) : null}

      {state.status !== "idle" ? (
        <div className={`message ${state.status === "success" ? "message-success" : "message-error"}`}>
          {state.message}
        </div>
      ) : null}

      <div className="inline-actions">
        <FormSubmitButton
          label="Submit Lead"
          pendingLabel="Submitting..."
          variant="primary"
        />
        <span className="helper-text">
          Duplicate detection runs against business name and business link.
        </span>
      </div>
    </form>
  );
}
