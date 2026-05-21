"use client";

import { useActionState } from "react";

import { signInAction } from "@/app/actions";
import { FormSubmitButton } from "@/components/shared/form-submit-button";
import { initialActionState } from "@/lib/action-state";

export function SignInForm() {
  const [state, formAction] = useActionState(signInAction, initialActionState);

  return (
    <form action={formAction} className="stack">
      <div className="field">
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" placeholder="you@intelliumdigital.com" required />
      </div>

      <div className="field">
        <label htmlFor="password">Password</label>
        <input id="password" name="password" type="password" placeholder="Enter your password" required />
      </div>

      <FormSubmitButton label="Access Portal" pendingLabel="Signing in..." />

      {state.status === "error" ? (
        <div className="message message-error">{state.message}</div>
      ) : null}
    </form>
  );
}
