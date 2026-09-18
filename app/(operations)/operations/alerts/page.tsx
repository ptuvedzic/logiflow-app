import { redirect } from "next/navigation";

import { PageHeader } from "@/components/ui/page-header";
import { AlertList } from "@/features/alerts/alert-list";
import { alertListQuerySchema, type AlertListInput } from "@/features/alerts/alert-schema";
import { listAlerts } from "@/lib/dal/alerts";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
const first = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] : value;
function url(filters: AlertListInput) { const p = new URLSearchParams(); if (filters.search) p.set("search", filters.search); if (filters.state !== "active") p.set("state", filters.state); if (filters.severity !== "all") p.set("severity", filters.severity); if (filters.type !== "all") p.set("type", filters.type); if (filters.entity !== "all") p.set("entity", filters.entity); if (filters.page > 1) p.set("page", String(filters.page)); const q = p.toString(); return q ? `/operations/alerts?${q}` : "/operations/alerts"; }
function fail(error: { category: string }): never { if (error.category === "unauthenticated") redirect("/login"); if (error.category === "inactive_profile") redirect("/account-inactive"); if (error.category === "missing_profile") redirect("/account-error"); if (error.category === "forbidden") redirect("/forbidden"); throw new Error("Unable to load alerts."); }
export default async function AlertsPage({ searchParams }: Props) { const query = await searchParams; const filters = alertListQuerySchema.parse({ search: first(query.search), state: first(query.state), severity: first(query.severity), type: first(query.type), entity: first(query.entity), page: first(query.page) }); const result = await listAlerts(filters); if (!result.ok) fail(result.error); const last = Math.max(result.data.totalPages, 1); if (filters.page > last) redirect(url({ ...filters, page: last })); return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Alerts" description="Review active operational conditions and resolved alert history." /><AlertList alerts={result.data.alerts} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} /></div>; }
