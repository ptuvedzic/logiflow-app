import { z } from "zod";

export const ALERT_TYPES = [
  "shipment_delayed",
  "document_expiring",
  "document_expired",
  "maintenance_due_date",
  "maintenance_due_mileage",
  "stale_vehicle_location",
] as const;
export const ALERT_SEVERITIES = ["info", "warning", "critical"] as const;
export const ALERT_STATES = ["active", "resolved"] as const;
export const ALERT_ENTITY_TYPES = ["shipment", "vehicle", "driver", "document"] as const;

export const alertListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  state: z.enum(["all", ...ALERT_STATES]).catch("active"),
  severity: z.enum(["all", ...ALERT_SEVERITIES]).catch("all"),
  type: z.enum(["all", ...ALERT_TYPES]).catch("all"),
  entity: z.enum(["all", ...ALERT_ENTITY_TYPES]).catch("all"),
  page: z.coerce.number().int().min(1).catch(1),
});

export type AlertListInput = z.infer<typeof alertListQuerySchema>;
