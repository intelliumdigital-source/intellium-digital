"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { requireAuthenticatedProfile, requireRole } from "@/lib/auth";
import type { ActionState } from "@/lib/action-state";
import { commissionStatuses, leadStatuses, reviewStatuses } from "@/lib/data/statuses";
import { findDuplicateLead } from "@/lib/leads";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { CommissionStatus, LeadStatus, ResourceCategory, ReviewStatus } from "@/lib/types";
import { normalizeText, normalizeUrl } from "@/lib/utils";

const maxProofUploadSizeBytes = 8 * 1024 * 1024;
const allowedProofMimeTypes = {
  "application/pdf": "pdf",
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp"
} as const;

const leadStatusSchema = z.enum(leadStatuses);
const reviewStatusSchema = z.enum(reviewStatuses);
const commissionStatusSchema = z.enum(commissionStatuses);

const leadSubmissionSchema = z.object({
  businessName: z.string().min(2, "Business name is required."),
  businessType: z.string().min(2, "Business type is required."),
  location: z.string().min(2, "Location is required."),
  businessLink: z
    .string()
    .url("Business link must be a valid HTTP or HTTPS URL.")
    .optional(),
  ownerContactName: z.string().trim().optional(),
  hasWebsite: z.enum(["yes", "no"]),
  problemFound: z.string().min(8, "Describe the problem found."),
  recommendedService: z.string().min(2, "Recommended service is required."),
  leadScore: z.coerce.number().min(0).max(100),
  messageSent: z.enum(["yes", "no"]),
  replyStatus: z.string().trim().optional(),
  interested: z.enum(["yes", "no"]),
  budgetMentioned: z.string().trim().optional(),
  notes: z.string().trim().optional()
});

const leadUpdateSchema = z.object({
  leadId: z.string().uuid("Invalid lead ID."),
  status: leadStatusSchema,
  reviewStatus: reviewStatusSchema
});

const commissionUpdateSchema = z.object({
  leadId: z.string().uuid("Invalid lead ID."),
  commissionId: z.string().uuid().optional().or(z.literal("")),
  packageName: z.string().trim().min(1, "Package name is required."),
  projectAmount: z.union([z.literal(""), z.coerce.number().finite().min(0)]),
  commissionAmount: z.union([z.literal(""), z.coerce.number().finite().min(0)]),
  status: commissionStatusSchema,
  paidDate: z.string().trim().optional(),
  notes: z.string().trim().optional()
});

const resourceSchema = z.object({
  id: z.string().uuid().optional().or(z.literal("")),
  category: z.enum([
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
  ] satisfies [ResourceCategory, ...ResourceCategory[]]),
  title: z.string().min(2, "Title is required."),
  content: z.string().min(5, "Content is required."),
  linkUrl: z.string().url("Use a valid URL.").optional().or(z.literal("")),
  orderIndex: z.coerce.number().min(0).default(0),
  isPublished: z.enum(["true", "false"]).default("true")
});

const announcementSchema = z.object({
  id: z.string().uuid().optional().or(z.literal("")),
  title: z.string().min(2, "Title is required."),
  content: z.string().min(5, "Content is required."),
  isPinned: z.enum(["true", "false"]).default("false"),
  isPublished: z.enum(["true", "false"]).default("true")
});

function normalizeOptionalHttpUrl(value: FormDataEntryValue | null) {
  const rawValue = String(value ?? "").trim();

  if (!rawValue) {
    return undefined;
  }

  const withProtocol = /^https?:\/\//i.test(rawValue)
    ? rawValue
    : `https://${rawValue}`;
  const parsedUrl = new URL(withProtocol);

  if (!["http:", "https:"].includes(parsedUrl.protocol)) {
    throw new Error("Business link must use HTTP or HTTPS.");
  }

  return parsedUrl.toString();
}

export async function signInAction(
  _prevState: ActionState,
  formData: FormData
) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const supabase = await createServerSupabaseClient();

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (error) {
    return {
      status: "error" as const,
      message: error.message
    };
  }

  const session = await requireAuthenticatedProfile();

  if (!session.configured || !session.profile) {
    redirect("/login");
  }

  redirect(session.profile.role === "admin" ? "/admin" : "/dashboard");
}

export async function signOutAction() {
  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export async function submitLeadAction(
  _prevState: ActionState,
  formData: FormData
) {
  const session = await requireRole(["researcher"]);

  if (!session.configured || !session.profile) {
    return {
      status: "error" as const,
      message: "Supabase is not configured."
    };
  }

  let businessLink: string | undefined;

  try {
    businessLink = normalizeOptionalHttpUrl(formData.get("business_link"));
  } catch (error) {
    return {
      status: "error" as const,
      message:
        error instanceof Error
          ? error.message
          : "Business link must be a valid HTTP or HTTPS URL."
    };
  }

  const parsed = leadSubmissionSchema.safeParse({
    businessName: formData.get("business_name"),
    businessType: formData.get("business_type"),
    location: formData.get("location"),
    businessLink,
    ownerContactName: formData.get("owner_contact_name"),
    hasWebsite: formData.get("has_website"),
    problemFound: formData.get("problem_found"),
    recommendedService: formData.get("recommended_service"),
    leadScore: formData.get("lead_score"),
    messageSent: formData.get("message_sent"),
    replyStatus: formData.get("reply_status"),
    interested: formData.get("interested"),
    budgetMentioned: formData.get("budget_mentioned"),
    notes: formData.get("notes")
  });

  if (!parsed.success) {
    return {
      status: "error" as const,
      message: parsed.error.issues[0]?.message ?? "Invalid form values."
    };
  }

  const proofFile = formData.get("screenshot") as File | null;

  if (!proofFile || proofFile.size === 0) {
    return {
      status: "error" as const,
      message: "Screenshot or proof upload is required."
    };
  }

  const allowedExtension =
    allowedProofMimeTypes[proofFile.type as keyof typeof allowedProofMimeTypes];

  if (!allowedExtension) {
    return {
      status: "error" as const,
      message: "Proof upload must be a PDF, JPG, PNG, or WEBP file."
    };
  }

  if (proofFile.size > maxProofUploadSizeBytes) {
    return {
      status: "error" as const,
      message: "Proof upload must be 8 MB or smaller."
    };
  }

  const duplicateCheck = await findDuplicateLead({
    businessName: parsed.data.businessName,
    businessLink: parsed.data.businessLink
  });

  if (duplicateCheck.hasDuplicate) {
    return {
      status: "error" as const,
      message:
        "Duplicate lead detected from the same business name or link. Review existing entries before submitting."
    };
  }

  const supabase = await createServerSupabaseClient();
  const timestamp = Date.now();
  const safeBaseName = normalizeText(parsed.data.businessName)
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  const filePath = `${session.profile.id}/${timestamp}-${safeBaseName}.${allowedExtension}`;

  const { error: uploadError } = await supabase.storage
    .from("lead-proofs")
    .upload(filePath, proofFile, {
      cacheControl: "3600",
      upsert: false
    });

  if (uploadError) {
    return {
      status: "error" as const,
      message: uploadError.message
    };
  }

  const { error } = await supabase.from("leads").insert({
    researcher_id: session.profile.id,
    business_name: parsed.data.businessName,
    business_type: parsed.data.businessType,
    location: parsed.data.location,
    business_link: parsed.data.businessLink || null,
    owner_contact_name: parsed.data.ownerContactName || null,
    has_website: parsed.data.hasWebsite === "yes",
    problem_found: parsed.data.problemFound,
    recommended_service: parsed.data.recommendedService,
    lead_score: parsed.data.leadScore,
    message_sent: parsed.data.messageSent === "yes",
    reply_status: parsed.data.replyStatus || null,
    interested: parsed.data.interested === "yes",
    budget_mentioned: parsed.data.budgetMentioned || null,
    screenshot_path: filePath,
    notes: parsed.data.notes || null,
    status: "Submitted" satisfies LeadStatus,
    review_status: "pending" satisfies ReviewStatus,
    normalized_business_name: normalizeText(parsed.data.businessName),
    normalized_business_link: parsed.data.businessLink
      ? normalizeUrl(parsed.data.businessLink)
      : null
  });

  if (error) {
    return {
      status: "error" as const,
      message: error.message
    };
  }

  revalidatePath("/dashboard");
  revalidatePath("/my-leads");
  revalidatePath("/admin");

  return {
    status: "success" as const,
    message: "Lead submitted successfully."
  };
}

export async function updateLeadAction(formData: FormData) {
  const session = await requireRole(["admin"]);

  if (!session.configured || !session.profile) {
    return;
  }

  const parsed = leadUpdateSchema.safeParse({
    leadId: formData.get("lead_id"),
    status: formData.get("status"),
    reviewStatus: formData.get("review_status")
  });

  if (!parsed.success) {
    return;
  }

  const supabase = await createServerSupabaseClient();
  await supabase
    .from("leads")
    .update({
      status: parsed.data.status,
      review_status: parsed.data.reviewStatus
    })
    .eq("id", parsed.data.leadId);

  revalidatePath("/admin");
  revalidatePath("/my-leads");
  revalidatePath("/dashboard");
}

export async function saveCommissionAction(formData: FormData) {
  const session = await requireRole(["admin"]);

  if (!session.configured || !session.profile) {
    return;
  }

  const parsed = commissionUpdateSchema.safeParse({
    leadId: formData.get("lead_id"),
    commissionId: formData.get("commission_id"),
    packageName: formData.get("package_name"),
    projectAmount: formData.get("project_amount"),
    commissionAmount: formData.get("commission_amount"),
    status: formData.get("status"),
    paidDate: formData.get("paid_date"),
    notes: formData.get("notes")
  });

  if (!parsed.success) {
    return;
  }

  const paidDate = parsed.data.paidDate?.trim() ?? "";
  const normalizedPaidDate =
    parsed.data.status === "Paid"
      ? paidDate || new Date().toISOString().slice(0, 10)
      : paidDate || null;

  const supabase = await createServerSupabaseClient();
  const { data: lead } = await supabase
    .from("leads")
    .select("researcher_id")
    .eq("id", parsed.data.leadId)
    .single();

  if (!lead) {
    return;
  }

  const payload = {
    lead_id: parsed.data.leadId,
    researcher_id: lead.researcher_id,
    package_name: parsed.data.packageName,
    project_amount:
      parsed.data.projectAmount === "" ? null : parsed.data.projectAmount,
    commission_amount:
      parsed.data.commissionAmount === "" ? null : parsed.data.commissionAmount,
    status: parsed.data.status,
    paid_date: normalizedPaidDate,
    notes: parsed.data.notes || null
  };

  if (parsed.data.commissionId) {
    await supabase
      .from("commissions")
      .update(payload)
      .eq("id", parsed.data.commissionId);
  } else {
    await supabase.from("commissions").insert(payload);
  }

  const leadStatus =
    parsed.data.status === "Paid"
      ? ("Commission Paid" satisfies LeadStatus)
      : parsed.data.status === "Pending"
        ? ("Commission Pending" satisfies LeadStatus)
        : ("Closed Lost" satisfies LeadStatus);

  await supabase
    .from("leads")
    .update({ status: leadStatus })
    .eq("id", parsed.data.leadId);

  revalidatePath("/admin");
  revalidatePath("/commissions");
  revalidatePath("/my-leads");
}

export async function saveResourceAction(
  _prevState: ActionState,
  formData: FormData
) {
  const session = await requireRole(["admin"]);

  if (!session.configured || !session.profile) {
    return {
      status: "error" as const,
      message: "Supabase is not configured."
    };
  }

  const parsed = resourceSchema.safeParse({
    id: formData.get("id"),
    category: formData.get("category"),
    title: formData.get("title"),
    content: formData.get("content"),
    linkUrl: formData.get("link_url"),
    orderIndex: formData.get("order_index"),
    isPublished: formData.get("is_published")
  });

  if (!parsed.success) {
    return {
      status: "error" as const,
      message: parsed.error.issues[0]?.message ?? "Invalid resource."
    };
  }

  const supabase = await createServerSupabaseClient();
  const payload = {
    category: parsed.data.category,
    title: parsed.data.title,
    content: parsed.data.content,
    link_url: parsed.data.linkUrl || null,
    order_index: parsed.data.orderIndex,
    is_published: parsed.data.isPublished === "true"
  };

  if (parsed.data.id) {
    await supabase.from("resource_items").update(payload).eq("id", parsed.data.id);
  } else {
    await supabase.from("resource_items").insert(payload);
  }

  revalidatePath("/outreach-kit");
  revalidatePath("/admin/resources");

  return {
    status: "success" as const,
    message: "Resource saved."
  };
}

export async function saveAnnouncementAction(
  _prevState: ActionState,
  formData: FormData
) {
  const session = await requireRole(["admin"]);

  if (!session.configured || !session.profile) {
    return {
      status: "error" as const,
      message: "Supabase is not configured."
    };
  }

  const parsed = announcementSchema.safeParse({
    id: formData.get("id"),
    title: formData.get("title"),
    content: formData.get("content"),
    isPinned: formData.get("is_pinned"),
    isPublished: formData.get("is_published")
  });

  if (!parsed.success) {
    return {
      status: "error" as const,
      message: parsed.error.issues[0]?.message ?? "Invalid announcement."
    };
  }

  const supabase = await createServerSupabaseClient();
  const payload = {
    title: parsed.data.title,
    content: parsed.data.content,
    is_pinned: parsed.data.isPinned === "true",
    is_published: parsed.data.isPublished === "true",
    published_at: parsed.data.isPublished === "true" ? new Date().toISOString() : null
  };

  if (parsed.data.id) {
    await supabase.from("announcements").update(payload).eq("id", parsed.data.id);
  } else {
    await supabase.from("announcements").insert(payload);
  }

  revalidatePath("/announcements");
  revalidatePath("/admin");
  revalidatePath("/admin/resources");

  return {
    status: "success" as const,
    message: "Announcement saved."
  };
}
