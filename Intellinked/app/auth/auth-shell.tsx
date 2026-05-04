"use client";

import { useActionState } from "react";
import { useFormStatus } from "react-dom";
import { ArrowRight } from "lucide-react";

import {
  INITIAL_AUTH_ACTION_STATE,
  signInAction,
  signUpAction,
  type AuthActionState,
} from "@/app/actions/auth";

function AuthSubmitButton({
  label,
  loadingLabel,
  disabled,
}: {
  label: string;
  loadingLabel: string;
  disabled?: boolean;
}) {
  const { pending } = useFormStatus();

  return (
    <button
      type="submit"
      disabled={disabled || pending}
      className="inline-flex w-full items-center justify-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-3 text-sm font-semibold text-cyan hover:bg-cyan/18 hover:text-white disabled:cursor-not-allowed disabled:opacity-60"
    >
      {pending ? loadingLabel : label}
      <ArrowRight className="h-4 w-4" />
    </button>
  );
}

function AuthMessage({ state }: { state: AuthActionState }) {
  if (state.errorMessage) {
    return (
      <p className="rounded-2xl border border-danger/30 bg-danger/10 px-4 py-3 text-sm text-danger">
        {state.errorMessage}
      </p>
    );
  }

  if (state.successMessage) {
    return (
      <p className="rounded-2xl border border-success/30 bg-success/10 px-4 py-3 text-sm text-success">
        {state.successMessage}
      </p>
    );
  }

  return null;
}

export function AuthShell({ isConfigured }: { isConfigured: boolean }) {
  const [loginState, loginAction] = useActionState(
    signInAction,
    INITIAL_AUTH_ACTION_STATE,
  );
  const [signupState, signupAction] = useActionState(
    signUpAction,
    INITIAL_AUTH_ACTION_STATE,
  );

  return (
    <div className="grid gap-4 sm:grid-cols-2">
      <section className="premium-card-soft rounded-[28px] p-5">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
          Login
        </p>
        <form action={loginAction} className="mt-5 space-y-4">
          <label className="block text-sm text-muted-strong">
            Email
            <input
              name="email"
              type="email"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="name@business.ph"
              autoComplete="email"
            />
          </label>
          <label className="block text-sm text-muted-strong">
            Password
            <input
              name="password"
              type="password"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="********"
              autoComplete="current-password"
            />
          </label>
          <AuthMessage state={loginState} />
          <AuthSubmitButton
            label="Continue to home"
            loadingLabel="Signing in..."
            disabled={!isConfigured}
          />
        </form>
      </section>

      <section className="premium-card-soft rounded-[28px] p-5">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-purple">
          Register
        </p>
        <form action={signupAction} className="mt-5 space-y-4">
          <label className="block text-sm text-muted-strong">
            Full name or business
            <input
              name="display_name"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="Your name or brand"
              autoComplete="name"
            />
          </label>
          <label className="block text-sm text-muted-strong">
            Role type
            <select
              name="account_type"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              defaultValue="Professional"
            >
              <option value="Professional" className="bg-slate-950">
                Professional
              </option>
              <option value="Business" className="bg-slate-950">
                Business
              </option>
              <option value="Freelancer" className="bg-slate-950">
                Freelancer
              </option>
              <option value="Customer" className="bg-slate-950">
                Customer
              </option>
            </select>
          </label>
          <label className="block text-sm text-muted-strong">
            Email
            <input
              name="email"
              type="email"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="name@business.ph"
              autoComplete="email"
            />
          </label>
          <label className="block text-sm text-muted-strong">
            Password
            <input
              name="password"
              type="password"
              className="input-shell mt-2 w-full rounded-2xl px-4 py-3 text-white outline-none"
              placeholder="At least 8 characters"
              autoComplete="new-password"
            />
          </label>
          <AuthMessage state={signupState} />
          <AuthSubmitButton
            label="Create account"
            loadingLabel="Creating account..."
            disabled={!isConfigured}
          />
        </form>
      </section>
    </div>
  );
}
