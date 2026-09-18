import { z } from "zod";

export const driverStatuses = ["available", "assigned", "off_duty", "inactive", "archived"] as const;
export const driverOperations = ["mark_off_duty", "mark_available", "archive", "reactivate"] as const;

export const driverListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  status: z.enum(["all", ...driverStatuses]).catch("all"),
  account: z.enum(["all", "active", "inactive"]).catch("all"),
  page: z.coerce.number().int().positive().catch(1),
});

export const driverTargetSchema = z.object({ driverId: z.uuid({ error: "Driver unavailable." }) }).strict();

export const driverPhoneEditSchema = z.object({
  driverId: z.uuid({ error: "Driver unavailable." }),
  expectedUpdatedAt: z.iso.datetime({ error: "Driver unavailable." }),
  phone: z.string().trim().max(32, "Phone must be 32 characters or fewer.").transform((value) => value === "" ? null : value),
}).strict();

export const driverOperationSchema = z.object({
  driverId: z.uuid({ error: "Driver unavailable." }),
  operation: z.enum(driverOperations),
}).strict();

export type DriverStatus = typeof driverStatuses[number];
export type DriverOperation = typeof driverOperations[number];
export type DriverPhoneEditInput = Readonly<z.infer<typeof driverPhoneEditSchema>>;
export type DriverOperationInput = Readonly<z.infer<typeof driverOperationSchema>>;
