import type { Client, FollowUpItem, Lead, LeadStatus, PipelineStage, Quote, Task } from "@/lib/types";

export const statusOrder: LeadStatus[] = ["New", "Contacted", "Follow-up", "Quoted", "Won", "Lost"];

export const leads: Lead[] = [
  {
    id: "LD-1001",
    fullName: "Mikaela Santos",
    businessName: "Santos Events Co.",
    phone: "+63 917 812 3401",
    email: "mikaela@santosevents.ph",
    facebook: "facebook.com/santoseventsph",
    source: "Facebook Inquiry",
    service: "CRM Setup + Lead Nurturing",
    budget: "₱35,000 - ₱50,000",
    notes: "Needs cleaner lead follow-up before Q3 wedding season.",
    nextFollowUp: "May 06, 2026",
    status: "Follow-up",
    value: 48000
  },
  {
    id: "LD-1002",
    fullName: "Paolo Fernandez",
    businessName: "Northbrew Cafe",
    phone: "+63 998 411 9221",
    email: "paolo@northbrew.cafe",
    facebook: "facebook.com/northbrewcafe",
    source: "Website Form",
    service: "Sales Pipeline Tracking",
    budget: "₱20,000 - ₱35,000",
    notes: "Wants visibility across branches and franchising leads.",
    nextFollowUp: "May 05, 2026",
    status: "Contacted",
    value: 32000
  },
  {
    id: "LD-1003",
    fullName: "Ariane Dela Cruz",
    businessName: "Dela Cruz Realty Group",
    phone: "+63 917 602 5318",
    email: "ariane@dcrg.ph",
    facebook: "facebook.com/dcrgrealty",
    source: "Referral",
    service: "Quotation Workflow",
    budget: "₱55,000 - ₱80,000",
    notes: "Team of 9 agents; proposal requested with onboarding support.",
    nextFollowUp: "May 04, 2026",
    status: "Quoted",
    value: 76000
  },
  {
    id: "LD-1004",
    fullName: "Jomar Velasco",
    businessName: "Velasco Auto Supply",
    phone: "+63 920 144 6831",
    email: "jomar@velascoauto.ph",
    facebook: "facebook.com/velascoautosupply",
    source: "Cold Outreach",
    service: "Lead Database Cleanup",
    budget: "₱15,000 - ₱25,000",
    notes: "Interested if SMS reminders can be included later.",
    nextFollowUp: "May 08, 2026",
    status: "New",
    value: 18000
  },
  {
    id: "LD-1005",
    fullName: "Rhea Manuel",
    businessName: "Bloom Skin Studio",
    phone: "+63 975 243 7754",
    email: "rhea@bloomskin.ph",
    facebook: "facebook.com/bloomskinstudio",
    source: "Instagram DM",
    service: "Client Follow-up Automation",
    budget: "₱45,000 - ₱65,000",
    notes: "Needs repeat-visit reminders and sales tracking by branch.",
    nextFollowUp: "May 07, 2026",
    status: "Won",
    value: 62000
  },
  {
    id: "LD-1006",
    fullName: "Cedric Ong",
    businessName: "Harbor Freight Movers",
    phone: "+63 917 500 2819",
    email: "cedric@harbormovers.ph",
    facebook: "facebook.com/harbormoversph",
    source: "Google Search",
    service: "Lead Qualification Workflow",
    budget: "₱25,000 - ₱40,000",
    notes: "Disqualified due to internal system migration delay.",
    nextFollowUp: "May 15, 2026",
    status: "Lost",
    value: 28000
  },
  {
    id: "LD-1007",
    fullName: "Katrina Aquino",
    businessName: "AquaPure Water Refilling",
    phone: "+63 917 884 7610",
    email: "katrina@aquapure.ph",
    facebook: "facebook.com/aquapurewaterph",
    source: "Facebook Ad",
    service: "Lead-to-Client Tracking",
    budget: "₱18,000 - ₱30,000",
    notes: "Comparing two providers, decision expected this week.",
    nextFollowUp: "May 04, 2026",
    status: "Follow-up",
    value: 24000
  },
  {
    id: "LD-1008",
    fullName: "Bryan Reyes",
    businessName: "Reyes Construction Services",
    phone: "+63 932 115 4308",
    email: "bryan@reyesconstruct.ph",
    facebook: "facebook.com/reyesconstructionservices",
    source: "Partner Referral",
    service: "CRM Dashboard Setup",
    budget: "₱60,000 - ₱90,000",
    notes: "Owner wants a premium dashboard for project sales visibility.",
    nextFollowUp: "May 09, 2026",
    status: "Quoted",
    value: 88000
  }
];

export const clients: Client[] = [
  {
    id: "CL-201",
    businessName: "Bloom Skin Studio",
    contactPerson: "Rhea Manuel",
    servicePlan: "Growth CRM Retainer",
    monthlyValue: 22000,
    health: "Healthy",
    renewalDate: "July 21, 2026"
  },
  {
    id: "CL-202",
    businessName: "PrimeNest Realty",
    contactPerson: "Lance Tiu",
    servicePlan: "Pipeline Pro",
    monthlyValue: 28000,
    health: "Expansion",
    renewalDate: "August 14, 2026"
  },
  {
    id: "CL-203",
    businessName: "Northbrew Cafe",
    contactPerson: "Paolo Fernandez",
    servicePlan: "Starter CRM",
    monthlyValue: 14500,
    health: "Watchlist",
    renewalDate: "June 30, 2026"
  },
  {
    id: "CL-204",
    businessName: "Astera Dental Hub",
    contactPerson: "Doc Lyra Chua",
    servicePlan: "Follow-up Engine",
    monthlyValue: 18500,
    health: "Healthy",
    renewalDate: "September 11, 2026"
  }
];

export const followUps: FollowUpItem[] = [
  {
    id: "FU-01",
    leadName: "Ariane Dela Cruz",
    company: "Dela Cruz Realty Group",
    channel: "Proposal Call",
    due: "10:00 AM",
    owner: "Miguel",
    priority: "High"
  },
  {
    id: "FU-02",
    leadName: "Katrina Aquino",
    company: "AquaPure Water Refilling",
    channel: "Facebook Messenger",
    due: "1:30 PM",
    owner: "Jessa",
    priority: "Medium"
  },
  {
    id: "FU-03",
    leadName: "Paolo Fernandez",
    company: "Northbrew Cafe",
    channel: "Discovery Call",
    due: "3:00 PM",
    owner: "Miguel",
    priority: "High"
  },
  {
    id: "FU-04",
    leadName: "Jomar Velasco",
    company: "Velasco Auto Supply",
    channel: "SMS Reminder",
    due: "4:30 PM",
    owner: "Carla",
    priority: "Low"
  }
];

export const quotations: Quote[] = [
  {
    id: "QT-310",
    client: "Dela Cruz Realty Group",
    packageName: "CRM + Quotation Workflow",
    amount: 76000,
    status: "Sent",
    validUntil: "May 18, 2026"
  },
  {
    id: "QT-311",
    client: "Reyes Construction Services",
    packageName: "Executive Dashboard Build",
    amount: 88000,
    status: "Negotiation",
    validUntil: "May 22, 2026"
  },
  {
    id: "QT-312",
    client: "Bloom Skin Studio",
    packageName: "Retention Automation Bundle",
    amount: 62000,
    status: "Approved",
    validUntil: "May 30, 2026"
  },
  {
    id: "QT-313",
    client: "Northbrew Cafe",
    packageName: "Branch Sales Tracking",
    amount: 32000,
    status: "Draft",
    validUntil: "May 16, 2026"
  }
];

export const pipelineStages: PipelineStage[] = [
  {
    name: "New",
    total: 2,
    leads: [
      { id: "LD-1004", company: "Velasco Auto Supply", contact: "Jomar Velasco", amount: 18000, source: "Cold Outreach" },
      { id: "LD-1009", company: "Casa Verde Bistro", contact: "Tina Ching", amount: 26000, source: "Facebook Ad" }
    ]
  },
  {
    name: "Contacted",
    total: 2,
    leads: [
      { id: "LD-1002", company: "Northbrew Cafe", contact: "Paolo Fernandez", amount: 32000, source: "Website Form" },
      { id: "LD-1010", company: "Rizal Printing Hub", contact: "Jethro Sy", amount: 21000, source: "Referral" }
    ]
  },
  {
    name: "Follow-up",
    total: 2,
    leads: [
      { id: "LD-1001", company: "Santos Events Co.", contact: "Mikaela Santos", amount: 48000, source: "Facebook Inquiry" },
      { id: "LD-1007", company: "AquaPure Water Refilling", contact: "Katrina Aquino", amount: 24000, source: "Facebook Ad" }
    ]
  },
  {
    name: "Quoted",
    total: 2,
    leads: [
      { id: "LD-1003", company: "Dela Cruz Realty Group", contact: "Ariane Dela Cruz", amount: 76000, source: "Referral" },
      { id: "LD-1008", company: "Reyes Construction Services", contact: "Bryan Reyes", amount: 88000, source: "Partner Referral" }
    ]
  },
  {
    name: "Won",
    total: 1,
    leads: [{ id: "LD-1005", company: "Bloom Skin Studio", contact: "Rhea Manuel", amount: 62000, source: "Instagram DM" }]
  }
];

export const tasks: Task[] = [
  { id: "TS-01", title: "Send revised quotation to Reyes Construction", due: "Today", owner: "Miguel", status: "In Progress" },
  { id: "TS-02", title: "Review new Facebook inquiries", due: "Today", owner: "Jessa", status: "Open" },
  { id: "TS-03", title: "Clean old duplicate lead entries", due: "Tomorrow", owner: "Carla", status: "Open" },
  { id: "TS-04", title: "Finalize monthly sales report", due: "Friday", owner: "Miguel", status: "Done" }
];

export const monthlyPerformance = [
  { month: "Jan", leads: 38, won: 7, revenue: 140000 },
  { month: "Feb", leads: 44, won: 8, revenue: 168000 },
  { month: "Mar", leads: 52, won: 11, revenue: 214000 },
  { month: "Apr", leads: 61, won: 13, revenue: 246000 },
  { month: "May", leads: 58, won: 12, revenue: 232000 }
];

export const sourceMix = [
  { source: "Facebook", count: 22 },
  { source: "Referral", count: 14 },
  { source: "Website", count: 11 },
  { source: "Cold Outreach", count: 8 }
];

export const dashboardStats = {
  totalLeads: leads.length,
  newLeads: leads.filter((lead) => lead.status === "New").length,
  followUpsToday: followUps.length,
  wonDeals: leads.filter((lead) => lead.status === "Won").length,
  estimatedRevenue: leads
    .filter((lead) => lead.status !== "Lost")
    .reduce((sum, lead) => sum + lead.value, 0)
};
