import type { Route } from "next";

export const routes = {
  home: "/" as Route,
  login: "/login" as Route,
  dashboard: "/dashboard" as Route,
  leads: "/dashboard/leads" as Route,
  clients: "/dashboard/clients" as Route,
  followUps: "/dashboard/follow-ups" as Route,
  pipeline: "/dashboard/pipeline" as Route,
  quotations: "/dashboard/quotations" as Route,
  reports: "/dashboard/reports" as Route,
  settings: "/dashboard/settings" as Route
};

export const dashboardNav = [
  { href: routes.dashboard, label: "Dashboard" },
  { href: routes.leads, label: "Leads" },
  { href: routes.clients, label: "Clients" },
  { href: routes.followUps, label: "Follow-ups" },
  { href: routes.pipeline, label: "Sales Pipeline" },
  { href: routes.quotations, label: "Quotations" },
  { href: routes.reports, label: "Reports" },
  { href: routes.settings, label: "Settings" }
] as const;
