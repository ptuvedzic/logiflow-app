import { Bell } from "lucide-react";
import { redirect } from "next/navigation";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { DriverNotificationList } from "@/features/notifications/driver-notification-list";
import { notificationListQuerySchema, type NotificationListInput } from "@/features/notifications/notification-schema";
import { listDriverNotifications } from "@/lib/dal/notifications";
import type { NotificationError } from "@/lib/dal/notifications";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;

const first = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] : value;

function url(filters: NotificationListInput) {
  const params = new URLSearchParams();
  if (filters.status !== "all") params.set("status", filters.status);
  if (filters.page > 1) params.set("page", String(filters.page));
  const query = params.toString();
  return query ? `/driver/notifications?${query}` : "/driver/notifications";
}

function handleNotificationBoundaryFailure(error: NotificationError): never {
  switch (error.category) {
    case "unauthenticated":
    case "inactive_profile":
    case "missing_profile":
    case "forbidden":
      handleAuthBoundaryFailure(error);
    case "validation":
    case "not_found":
    case "infrastructure":
      throw new Error("Unable to load notifications.");
  }
}

export default async function DriverNotificationsPage({ searchParams }: Props) {
  const query = await searchParams;
  const filters = notificationListQuerySchema.parse({ status: first(query.status), page: first(query.page) });
  const result = await listDriverNotifications(filters);

  if (!result.ok) {
    handleNotificationBoundaryFailure(result.error);
  }

  const lastPage = Math.max(result.data.totalPages, 1);
  if (filters.page > lastPage) redirect(url({ ...filters, page: lastPage }));

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="Notifications" description="Review updates addressed to you." />
      {result.data.totalCount === 0 && filters.status === "all" ? (
        <EmptyState icon={Bell} title="No notifications" description="Notifications addressed to you will appear here." />
      ) : (
        <DriverNotificationList
          notifications={result.data.notifications}
          filters={filters}
          totalCount={result.data.totalCount}
          totalPages={result.data.totalPages}
        />
      )}
    </div>
  );
}
