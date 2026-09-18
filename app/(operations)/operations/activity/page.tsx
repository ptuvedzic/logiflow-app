import { redirect } from "next/navigation";

import { PageHeader } from "@/components/ui/page-header";
import { ActivityList } from "@/features/activity/activity-list";
import { activityListQuerySchema, type ActivityListInput } from "@/features/activity/activity-schema";
import { requireRole } from "@/lib/dal/auth";
import { listActivity } from "@/lib/dal/activity";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
const first = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] : value;
function url(filters: ActivityListInput) { const p = new URLSearchParams(); if (filters.actor !== "all") p.set("actor", filters.actor); if (filters.action !== "all") p.set("action", filters.action); if (filters.entity !== "all") p.set("entity", filters.entity); if (filters.from) p.set("from", filters.from); if (filters.to) p.set("to", filters.to); if (filters.page > 1) p.set("page", String(filters.page)); const q = p.toString(); return q ? `/operations/activity?${q}` : "/operations/activity"; }
function fail(error: { category: string }): never { if (error.category === "unauthenticated") redirect("/login"); if (error.category === "inactive_profile") redirect("/account-inactive"); if (error.category === "missing_profile") redirect("/account-error"); if (error.category === "forbidden") redirect("/forbidden"); throw new Error("Unable to load activity."); }
export default async function ActivityPage({ searchParams }: Props) { const query = await searchParams; const filters = activityListQuerySchema.parse({ actor: first(query.actor), action: first(query.action), entity: first(query.entity), from: first(query.from), to: first(query.to), page: first(query.page) }); const [result, actor] = await Promise.all([listActivity(filters), requireRole("admin", "dispatcher")]); if (!result.ok) fail(result.error); if (!actor.ok) fail(actor.error); const last = Math.max(result.data.totalPages, 1); if (filters.page > last) redirect(url({ ...filters, page: last })); return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Activity" description="Review immutable operational activity history." /><ActivityList activities={result.data.activities} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} isDispatcher={actor.data.role === "dispatcher"} /></div>; }
