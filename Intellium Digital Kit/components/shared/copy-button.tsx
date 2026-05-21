"use client";

import { useState, useTransition } from "react";

export function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);
  const [isPending, startTransition] = useTransition();

  return (
    <button
      type="button"
      className="button-secondary"
      disabled={isPending}
      onClick={() =>
        startTransition(async () => {
          await navigator.clipboard.writeText(value);
          setCopied(true);
          window.setTimeout(() => setCopied(false), 1400);
        })
      }
    >
      {copied ? "Copied" : "Copy"}
    </button>
  );
}
