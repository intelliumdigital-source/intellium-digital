"use client";

import { useFormStatus } from "react-dom";

export function FormSubmitButton({
  label,
  pendingLabel,
  variant = "primary"
}: {
  label: string;
  pendingLabel: string;
  variant?: "primary" | "secondary" | "danger" | "ghost";
}) {
  const { pending } = useFormStatus();

  const className =
    variant === "secondary"
      ? "button-secondary"
      : variant === "danger"
        ? "button-danger"
        : variant === "ghost"
          ? "button-ghost"
          : "button";

  return (
    <button type="submit" className={className} disabled={pending}>
      {pending ? pendingLabel : label}
    </button>
  );
}
