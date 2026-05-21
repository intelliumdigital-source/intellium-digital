export type UserRole = "admin" | "researcher";

export type LeadStatus =
  | "Submitted"
  | "Under Review"
  | "Qualified"
  | "Duplicate"
  | "Contacted"
  | "Interested"
  | "Handoff"
  | "Proposal Sent"
  | "Closed Won"
  | "Closed Lost"
  | "Commission Pending"
  | "Commission Paid";

export type ReviewStatus = "pending" | "approved" | "rejected";

export type CommissionStatus = "Pending" | "Paid" | "Rejected";

export type ResourceCategory =
  | "start_here"
  | "daily_workflow"
  | "target_niches"
  | "scripts"
  | "niche_scripts"
  | "objection_replies"
  | "pricing"
  | "qualification"
  | "scoring"
  | "commission"
  | "handoff"
  | "images"
  | "daily_report"
  | "dos_donts"
  | "faq";

export interface Profile {
  id: string;
  email: string;
  full_name: string | null;
  role: UserRole;
  created_at: string;
  updated_at: string;
}

export interface Lead {
  id: string;
  researcher_id: string;
  business_name: string;
  business_type: string;
  location: string;
  business_link: string | null;
  owner_contact_name: string | null;
  has_website: boolean;
  problem_found: string;
  recommended_service: string;
  lead_score: number;
  message_sent: boolean;
  reply_status: string | null;
  interested: boolean;
  budget_mentioned: string | null;
  screenshot_path: string | null;
  notes: string | null;
  status: LeadStatus;
  review_status: ReviewStatus;
  submitted_at: string;
  updated_at: string;
  normalized_business_name: string;
  normalized_business_link: string | null;
}

export interface Commission {
  id: string;
  lead_id: string;
  researcher_id: string;
  package_name: string;
  project_amount: number | null;
  commission_amount: number | null;
  status: CommissionStatus;
  paid_date: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface ResourceItem {
  id: string;
  category: ResourceCategory;
  title: string;
  content: string;
  link_url: string | null;
  order_index: number;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

export interface Announcement {
  id: string;
  title: string;
  content: string;
  is_pinned: boolean;
  is_published: boolean;
  published_at: string | null;
  created_at: string;
  updated_at: string;
}
