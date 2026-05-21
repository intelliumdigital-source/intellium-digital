import { CommissionStatus, LeadStatus, ReviewStatus } from "@/lib/types";

export type StatusTone = "success" | "warning" | "danger" | "info" | "neutral";

export function cn(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export function normalizeText(value: string) {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

export function normalizeUrl(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/^www\./, "")
    .replace(/\/$/, "");
}

export function formatDate(value: string | null) {
  if (!value) {
    return "Not set";
  }

  return new Intl.DateTimeFormat("en-PH", {
    dateStyle: "medium"
  }).format(new Date(value));
}

export function formatCurrency(value: number | null) {
  if (value === null || Number.isNaN(value)) {
    return "Not set";
  }

  return new Intl.NumberFormat("en-PH", {
    style: "currency",
    currency: "PHP",
    maximumFractionDigits: 0
  }).format(value);
}

export function getLeadStatusTone(status: LeadStatus) {
  const tones: Record<LeadStatus, StatusTone> = {
    Submitted: "neutral",
    "Under Review": "warning",
    Qualified: "success",
    Duplicate: "danger",
    Contacted: "neutral",
    Interested: "info",
    Handoff: "info",
    "Proposal Sent": "info",
    "Closed Won": "success",
    "Closed Lost": "danger",
    "Commission Pending": "warning",
    "Commission Paid": "success"
  };

  return tones[status];
}

export function getReviewTone(status: ReviewStatus) {
  const tones: Record<ReviewStatus, StatusTone> = {
    pending: "warning",
    approved: "success",
    rejected: "danger"
  };

  return tones[status];
}

export function getCommissionTone(status: CommissionStatus) {
  const tones: Record<CommissionStatus, StatusTone> = {
    Pending: "warning",
    Paid: "success",
    Rejected: "danger"
  };

  return tones[status];
}
