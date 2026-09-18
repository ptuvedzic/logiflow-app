import { z } from "zod";

import type { Database } from "@/types/database.generated";

export const ACTIVITY_ACTIONS = [
  "driver_created", "driver_status_changed", "client_created", "client_updated",
  "client_archived", "client_reactivated", "vehicle_created", "vehicle_updated",
  "vehicle_status_changed", "vehicle_archived", "shipment_created", "shipment_updated",
  "shipment_assigned", "shipment_status_changed", "shipment_delayed", "shipment_cancelled",
  "status_request_created", "status_request_approved", "status_request_rejected",
  "document_uploaded", "document_archived", "document_restored", "maintenance_record_created",
  "maintenance_record_updated", "expense_created", "expense_updated", "alert_created",
  "alert_resolved", "tracking_started", "tracking_stopped",
] as const satisfies readonly Database["public"]["Enums"]["activity_action_type"][];

export const ACTIVITY_ENTITY_TYPES = [
  "shipment", "status_request", "vehicle", "driver", "client", "document", "maintenance", "expense",
] as const;

const optionalDate = z.string().trim().refine((value) => value === "" || z.iso.date().safeParse(value).success).catch("");

export const activityListQuerySchema = z.object({
  actor: z.enum(["all", "system", "user"]).catch("all"),
  action: z.enum(["all", ...ACTIVITY_ACTIONS]).catch("all"),
  entity: z.enum(["all", ...ACTIVITY_ENTITY_TYPES]).catch("all"),
  from: optionalDate,
  to: optionalDate,
  page: z.coerce.number().int().min(1).catch(1),
}).transform((value) => value.from && value.to && value.from > value.to ? { ...value, from: "", to: "" } : value);

export type ActivityListInput = z.infer<typeof activityListQuerySchema>;
