import { z } from "zod";

export const NOTIFICATION_STATUSES = ["all", "unread", "read"] as const;

export const notificationListQuerySchema = z.object({
  status: z.enum(NOTIFICATION_STATUSES).catch("all"),
  page: z.coerce.number().int().min(1).catch(1),
});

export const notificationIdSchema = z.uuid();

export type NotificationListInput = z.infer<typeof notificationListQuerySchema>;
