import type { ReactNode } from "react";

import { DriverShellNavigation } from "@/app/(driver)/driver/driver-shell-navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { requireRole } from "@/lib/dal/auth";
import { getDriverUnreadNotificationCount } from "@/lib/dal/notifications";
import type { NotificationError } from "@/lib/dal/notifications";

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

export default async function DriverLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  const result = await requireRole("driver");

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  const unreadResult = await getDriverUnreadNotificationCount();

  if (!unreadResult.ok) {
    handleNotificationBoundaryFailure(unreadResult.error);
  }

  return (
    <DriverShellNavigation unreadNotificationCount={unreadResult.data}>
      {children}
    </DriverShellNavigation>
  );
}
