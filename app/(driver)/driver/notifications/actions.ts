"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";

import { requireRole } from "@/lib/dal/auth";
import { acknowledgeDriverNotification } from "@/lib/dal/notifications";

export type AcknowledgeDriverNotificationActionState =
  | { status: "success"; message: null; correlationId: string; data: Readonly<{ notificationId: string; readAt: string }> }
  | { status: "validation" | "not_found" | "unauthenticated" | "inactive_profile" | "missing_profile" | "forbidden" | "infrastructure"; message: string; correlationId: string; data: null };

export async function acknowledgeDriverNotificationAction(notificationId: string): Promise<AcknowledgeDriverNotificationActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("driver");
  if (!actor.ok) return { status: actor.error.category, message: actor.error.message, correlationId, data: null };

  const result = await acknowledgeDriverNotification(notificationId);
  if (!result.ok) {
    if (result.error.category === "infrastructure") {
      console.error({
        operation: "driver.notifications.acknowledge",
        category: "infrastructure",
        actorProfileId: actor.data.id,
        correlationId,
      });
    }
    return { status: result.error.category, message: result.error.message, correlationId, data: null };
  }

  revalidatePath("/driver/notifications");
  revalidatePath("/driver", "layout");
  return { status: "success", message: null, correlationId, data: result.data };
}
