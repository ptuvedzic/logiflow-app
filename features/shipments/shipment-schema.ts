import { z } from "zod";

const shipmentStatuses = ["pending", "assigned", "loading", "in_transit", "delivered", "cancelled"] as const;
export const requestedShipmentStatuses = ["loading", "in_transit", "delivered"] as const;
export const shipmentStatusLabels = {
  pending: "Pending",
  assigned: "Assigned",
  loading: "Loading",
  in_transit: "In transit",
  delivered: "Delivered",
  cancelled: "Cancelled",
} as const;
export const shipmentListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  status: z.enum(["all", ...shipmentStatuses]).catch("all"),
  delayed: z.enum(["all", "delayed"]).catch("all"),
  page: z.coerce.number().int().positive().catch(1),
});
export const shipmentCreateSchema = z.object({
  clientId: z.string().uuid("Select a Client."),
  pickupAddress: z.string().trim().min(1, "Pickup address is required."),
  deliveryAddress: z.string().trim().min(1, "Delivery address is required."),
  pickupAt: z.coerce.date({ error: "Pickup date and time are required." }),
  expectedDeliveryAt: z.coerce.date({ error: "Expected delivery date and time are required." }),
  cargoType: z.string().trim().min(1, "Cargo type is required."),
  price: z.coerce.number().nonnegative("Price cannot be negative."),
}).refine((value) => value.expectedDeliveryAt >= value.pickupAt, { path: ["expectedDeliveryAt"], message: "Expected delivery cannot be before pickup." });
const shipmentEditFieldsSchema = z.object({
  shipmentId: z.string().uuid(),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  pickupAddress: z.string().trim().min(1, "Pickup address is required."),
  deliveryAddress: z.string().trim().min(1, "Delivery address is required."),
  pickupAt: z.coerce.date({ error: "Pickup date and time are required." }),
  expectedDeliveryAt: z.coerce.date({ error: "Expected delivery date and time are required." }),
  cargoType: z.string().trim().min(1, "Cargo type is required."),
});
export const dispatcherShipmentEditSchema = shipmentEditFieldsSchema.refine(
  (value) => value.expectedDeliveryAt >= value.pickupAt,
  { path: ["expectedDeliveryAt"], message: "Expected delivery cannot be before pickup." },
);
export const adminShipmentEditSchema = shipmentEditFieldsSchema.extend({
  price: z.coerce.number().nonnegative("Price cannot be negative."),
}).refine(
  (value) => value.expectedDeliveryAt >= value.pickupAt,
  { path: ["expectedDeliveryAt"], message: "Expected delivery cannot be before pickup." },
);
export const shipmentTargetSchema = z.object({ shipmentId: z.string().uuid() });
export const shipmentDelaySchema = z.object({
  shipmentId: z.string().uuid(),
  delayed: z.enum(["true", "false"]).transform((value) => value === "true"),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
});
export const shipmentAssignmentSchema = z.object({
  shipmentId: z.string().uuid(), driverId: z.string().uuid("Select a Driver."), vehicleId: z.string().uuid("Select a Vehicle."),
});
export const shipmentStatusRequestSchema = z.object({
  requestedStatus: z.enum(requestedShipmentStatuses),
});
export const shipmentStatusResolutionSchema = z.object({
  requestId: z.string().uuid(),
});
export const shipmentStatusRejectionSchema = shipmentStatusResolutionSchema.extend({
  rejectionReason: z.string().trim().max(500, "Reason must be 500 characters or fewer.").transform((value) => value || null),
});
export type ShipmentActionStatus = "idle" | "success" | "validation" | "not_found" | "conflict" | "business_rule" | "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure";
export type ShipmentActionState = Readonly<{ status: ShipmentActionStatus; message: string | null; fieldErrors: Readonly<Record<string, string[] | undefined>>; correlationId: string | null }>;
export type ShipmentListInput = z.infer<typeof shipmentListQuerySchema>;
export type ShipmentCreateInput = z.infer<typeof shipmentCreateSchema>;
export type ShipmentEditInput = z.infer<typeof dispatcherShipmentEditSchema> & { price?: number };
export type ShipmentDelayInput = z.infer<typeof shipmentDelaySchema>;
export type ShipmentAssignmentInput = z.infer<typeof shipmentAssignmentSchema>;
export type ShipmentRequestedStatus = (typeof requestedShipmentStatuses)[number];
