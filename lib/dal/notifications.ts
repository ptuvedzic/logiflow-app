import "server-only";

import type { NotificationListInput } from "@/features/notifications/notification-schema";
import { notificationIdSchema } from "@/features/notifications/notification-schema";
import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryError } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export const NOTIFICATIONS_PER_PAGE = 10;

type NotificationType = Database["public"]["Enums"]["notification_type"];
export type NotificationError =
  | AuthBoundaryError
  | { category: "validation" | "not_found"; message: string }
  | { category: "infrastructure"; message: string };
type Result<T> = { ok: true; data: T } | { ok: false; error: NotificationError };

export type OperationsNotification = Readonly<{
  id: string;
  type: NotificationType;
  title: string;
  message: string;
  createdAt: string;
  readAt: string | null;
  entityHref: string | null;
}>;

export type DriverNotification = OperationsNotification;

export type NotificationListResult = Readonly<{
  notifications: readonly OperationsNotification[];
  totalCount: number;
  totalPages: number;
}>;

export type DriverNotificationListResult = Readonly<{
  notifications: readonly DriverNotification[];
  totalCount: number;
  totalPages: number;
}>;

async function requireOperations(client: Awaited<ReturnType<typeof createClient>>) {
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok: false as const, error: { category: "inactive_profile" as const, message: "Account is inactive." as const } };
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher") {
    return { ok: false as const, error: { category: "forbidden" as const, message: "Access denied." as const } };
  }
  return { ok: true as const, data: profile.data };
}

async function requireDriver(client: Awaited<ReturnType<typeof createClient>>) {
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok: false as const, error: { category: "inactive_profile" as const, message: "Account is inactive." as const } };
  if (profile.data.role !== "driver") {
    return { ok: false as const, error: { category: "forbidden" as const, message: "Access denied." as const } };
  }
  return { ok: true as const, data: profile.data };
}

function infrastructure<T>(message: string): Result<T> {
  return { ok: false, error: { category: "infrastructure", message } };
}

export async function listOperationsNotifications(
  input: NotificationListInput,
  pageSize = NOTIFICATIONS_PER_PAGE,
): Promise<Result<NotificationListResult>> {
  const client = await createClient();
  const profile = await requireOperations(client);
  if (!profile.ok) return profile;

  let query = client.from("notifications").select(
    "id, notification_type, title, message, shipment_id, created_at, read_at",
    { count: "exact" },
  );
  if (input.status === "unread") query = query.is("read_at", null);
  if (input.status === "read") query = query.not("read_at", "is", null);
  const start = (input.page - 1) * pageSize;
  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .range(start, start + pageSize - 1);
  if (error || data === null) return infrastructure("Unable to load notifications.");

  const totalCount = count ?? 0;
  return {
    ok: true,
    data: {
      notifications: data.map((row) => ({
        id: row.id,
        type: row.notification_type,
        title: row.title,
        message: row.message,
        createdAt: row.created_at,
        readAt: row.read_at,
        entityHref: row.shipment_id === null ? null : "/operations/shipments",
      })),
      totalCount,
      totalPages: Math.ceil(totalCount / pageSize),
    },
  };
}

export async function getOperationsUnreadNotificationCount(): Promise<Result<number>> {
  const client = await createClient();
  const profile = await requireOperations(client);
  if (!profile.ok) return profile;
  const { count, error } = await client
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .is("read_at", null);
  return error ? infrastructure("Unable to load notifications.") : { ok: true, data: count ?? 0 };
}

export async function acknowledgeOperationsNotification(notificationId: string): Promise<Result<Readonly<{ notificationId: string; readAt: string }>>> {
  const parsed = notificationIdSchema.safeParse(notificationId);
  if (!parsed.success) return { ok: false, error: { category: "validation", message: "Notification unavailable." } };
  const client = await createClient();
  const profile = await requireOperations(client);
  if (!profile.ok) return profile;
  const { data, error } = await client.rpc("acknowledge_notification", { notification_id: parsed.data });
  if (error) return infrastructure("Unable to acknowledge notification.");
  if (data === null) return { ok: false, error: { category: "not_found", message: "Notification unavailable." } };
  return { ok: true, data: { notificationId: parsed.data, readAt: data } };
}

function driverEntityHref(type: NotificationType, shipmentId: string | null): string | null {
  if (type === "new_dispatcher_message") return "/driver/messages";
  if (type === "status_approval_requested" || shipmentId === null) return null;
  if (
    type === "shipment_assigned"
    || type === "status_approved"
    || type === "status_rejected"
    || type === "shipment_cancelled"
  ) {
    return "/driver/shipments";
  }
  return null;
}

export async function listDriverNotifications(
  input: NotificationListInput,
  pageSize = NOTIFICATIONS_PER_PAGE,
): Promise<Result<DriverNotificationListResult>> {
  const client = await createClient();
  const profile = await requireDriver(client);
  if (!profile.ok) return profile;

  let query = client.from("notifications").select(
    "id, notification_type, title, message, shipment_id, created_at, read_at",
    { count: "exact" },
  );
  if (input.status === "unread") query = query.is("read_at", null);
  if (input.status === "read") query = query.not("read_at", "is", null);
  const start = (input.page - 1) * pageSize;
  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .order("id", { ascending: false })
    .range(start, start + pageSize - 1);
  if (error || data === null) return infrastructure("Unable to load notifications.");

  const totalCount = count ?? 0;
  return {
    ok: true,
    data: {
      notifications: data.map((row) => ({
        id: row.id,
        type: row.notification_type,
        title: row.title,
        message: row.message,
        createdAt: row.created_at,
        readAt: row.read_at,
        entityHref: driverEntityHref(row.notification_type, row.shipment_id),
      })),
      totalCount,
      totalPages: Math.ceil(totalCount / pageSize),
    },
  };
}

export async function getDriverUnreadNotificationCount(): Promise<Result<number>> {
  const client = await createClient();
  const profile = await requireDriver(client);
  if (!profile.ok) return profile;
  const { count, error } = await client
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .is("read_at", null);
  return error ? infrastructure("Unable to load notifications.") : { ok: true, data: count ?? 0 };
}

export async function acknowledgeDriverNotification(notificationId: string): Promise<Result<Readonly<{ notificationId: string; readAt: string }>>> {
  const parsed = notificationIdSchema.safeParse(notificationId);
  if (!parsed.success) return { ok: false, error: { category: "validation", message: "Notification unavailable." } };
  const client = await createClient();
  const profile = await requireDriver(client);
  if (!profile.ok) return profile;
  const { data, error } = await client.rpc("acknowledge_notification", { notification_id: parsed.data });
  if (error) return infrastructure("Unable to acknowledge notification.");
  if (data === null) return { ok: false, error: { category: "not_found", message: "Notification unavailable." } };
  return { ok: true, data: { notificationId: parsed.data, readAt: data } };
}
