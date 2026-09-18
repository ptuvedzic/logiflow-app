import type { ReactNode } from "react";

import { OperationsShellNavigation } from "@/app/(operations)/operations/operations-shell-navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { requireRole } from "@/lib/dal/auth";
import { getOperationsUnreadNotificationCount } from "@/lib/dal/notifications";
import type { NotificationError } from "@/lib/dal/notifications";

function handleNotificationBoundaryFailure(error: NotificationError): never {
  if (error.category === "unauthenticated") {
    handleAuthBoundaryFailure({ category: "unauthenticated", message: "Authentication required." });
  }
  if (error.category === "inactive_profile") {
    handleAuthBoundaryFailure({ category: "inactive_profile", message: "Account is inactive." });
  }
  if (error.category === "missing_profile") {
    handleAuthBoundaryFailure({ category: "missing_profile", message: "Account profile unavailable." });
  }
  if (error.category === "forbidden") {
    handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
  }
  throw new Error("Unable to load notifications.");
}

export default async function OperationsLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  const result = await requireRole("admin", "dispatcher");

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  if (result.data.role !== "admin" && result.data.role !== "dispatcher") {
    handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
  }

  const unreadResult = await getOperationsUnreadNotificationCount();

  if (!unreadResult.ok) {
    handleNotificationBoundaryFailure(unreadResult.error);
  }

  return (
    <OperationsShellNavigation fullName={result.data.fullName} role={result.data.role} unreadNotificationCount={unreadResult.data}>
      {children}
    </OperationsShellNavigation>
  );
}
