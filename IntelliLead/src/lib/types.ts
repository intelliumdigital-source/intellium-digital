export type LeadStatus = "New" | "Contacted" | "Follow-up" | "Quoted" | "Won" | "Lost";

export type Lead = {
  id: string;
  fullName: string;
  businessName: string;
  phone: string;
  email: string;
  facebook: string;
  source: string;
  service: string;
  budget: string;
  notes: string;
  nextFollowUp: string;
  status: LeadStatus;
  value: number;
};

export type Client = {
  id: string;
  businessName: string;
  contactPerson: string;
  servicePlan: string;
  monthlyValue: number;
  health: "Healthy" | "Watchlist" | "Expansion";
  renewalDate: string;
};

export type FollowUpItem = {
  id: string;
  leadName: string;
  company: string;
  channel: string;
  due: string;
  owner: string;
  priority: "High" | "Medium" | "Low";
};

export type Quote = {
  id: string;
  client: string;
  packageName: string;
  amount: number;
  status: "Draft" | "Sent" | "Negotiation" | "Approved";
  validUntil: string;
};

export type PipelineStage = {
  name: string;
  total: number;
  leads: Array<{
    id: string;
    company: string;
    contact: string;
    amount: number;
    source: string;
  }>;
};

export type Task = {
  id: string;
  title: string;
  due: string;
  owner: string;
  status: "Open" | "In Progress" | "Done";
};
