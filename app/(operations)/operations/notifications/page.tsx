import { Bell } from "lucide-react";
import { redirect } from "next/navigation";

import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { NotificationList } from "@/features/notifications/notification-list";
import { notificationListQuerySchema, type NotificationListInput } from "@/features/notifications/notification-schema";
import { listOperationsNotifications } from "@/lib/dal/notifications";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
const first = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] : value;
function url(filters: NotificationListInput) { const params = new URLSearchParams(); if (filters.status !== "all") params.set("status", filters.status); if (filters.page > 1) params.set("page", String(filters.page)); const query = params.toString(); return query ? `/operations/notifications?${query}` : "/operations/notifications"; }
function fail(category: string): never { if (category === "unauthenticated") redirect("/login"); if (category === "inactive_profile") redirect("/account-inactive"); if (category === "missing_profile") redirect("/account-error"); if (category === "forbidden") redirect("/forbidden"); throw new Error("Unable to load notifications."); }

export default async function OperationsNotificationsPage({ searchParams }: Props) {
  const query = await searchParams;
  const filters = notificationListQuerySchema.parse({ status: first(query.status), page: first(query.page) });
  const result = await listOperationsNotifications(filters);
  if (!result.ok) fail(result.error.category);
  const lastPage = Math.max(result.data.totalPages, 1);
  if (filters.page > lastPage) redirect(url({ ...filters, page: lastPage }));
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Notifications" description="Review operational updates addressed to you." />{result.data.totalCount === 0 && filters.status === "all" ? <EmptyState icon={Bell} title="No notifications" description="Operational notifications addressed to you will appear here." /> : <NotificationList notifications={result.data.notifications} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} />}</div>;
}
