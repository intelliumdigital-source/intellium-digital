import type { Route } from "next";
import Link from "next/link";
import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "@/lib/utils";

type ButtonVariant = "primary" | "secondary" | "ghost";

export function buttonStyles(variant: ButtonVariant = "primary") {
  const base =
    "inline-flex items-center justify-center gap-2 rounded-2xl px-4 py-3 text-sm font-semibold transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60 focus-visible:ring-offset-2 focus-visible:ring-offset-ink";

  const variants: Record<ButtonVariant, string> = {
    primary: "bg-gradient-to-r from-cyan via-blue to-violet text-slate-950 shadow-neon hover:brightness-110",
    secondary: "border border-white/10 bg-white/5 text-white hover:bg-white/10",
    ghost: "border border-cyan/20 bg-cyan/10 text-cyan hover:border-cyan/40 hover:bg-cyan/15"
  };

  return cn(base, variants[variant]);
}

export function ButtonLink({
  href,
  children,
  variant = "primary",
  className = ""
}: {
  href: Route;
  children: ReactNode;
  variant?: ButtonVariant;
  className?: string;
}) {
  return (
    <Link className={cn(buttonStyles(variant), className)} href={href}>
      {children}
    </Link>
  );
}

export function Button({
  children,
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode;
  variant?: ButtonVariant;
  className?: string;
}) {
  return (
    <button className={cn(buttonStyles(variant), className)} {...props}>
      {children}
    </button>
  );
}
