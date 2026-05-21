export const leadStatuses = [
  "Submitted",
  "Under Review",
  "Qualified",
  "Duplicate",
  "Contacted",
  "Interested",
  "Handoff",
  "Proposal Sent",
  "Closed Won",
  "Closed Lost",
  "Commission Pending",
  "Commission Paid"
 ] as const;

export const reviewStatuses = [
  "pending",
  "approved",
  "rejected"
 ] as const;

export const commissionStatuses = [
  "Pending",
  "Paid",
  "Rejected"
 ] as const;
