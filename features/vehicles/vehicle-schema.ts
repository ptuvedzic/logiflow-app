import { z } from "zod";

export const VEHICLE_STATUSES = ["available", "in_use", "maintenance", "out_of_service", "archived"] as const;
export const VEHICLE_OPERATIONS = ["mark_maintenance", "mark_available", "mark_out_of_service", "archive", "reactivate"] as const;

const requiredText = (label: string) => z.string({ error: `Enter the ${label}.` }).trim().min(1, `Enter the ${label}.`);
const optionalText = z.string().trim().transform((value) => value === "" ? null : value);
const optionalDate = z.string().trim().refine((value) => value === "" || z.iso.date().safeParse(value).success, "Enter a valid date.").transform((value) => value === "" ? null : value);

export const vehicleFormSchema = z.object({
  registration: requiredText("registration").max(32, "Registration must be 32 characters or fewer."),
  make: requiredText("make"),
  model: requiredText("model"),
  vehicleType: requiredText("vehicle type"),
  vin: optionalText.refine((value) => value === null || value.length <= 64, "VIN must be 64 characters or fewer."),
  fuelType: optionalText,
  firstRegistrationDate: optionalDate,
}).strict();

export const vehicleCreateSchema = vehicleFormSchema.extend({
  mileage: z.coerce.number({ error: "Enter mileage." }).int("Mileage must be a whole number.").min(0, "Mileage cannot be negative."),
}).strict();

export const vehicleEditSchema = vehicleFormSchema.extend({
  vehicleId: z.uuid({ error: "Vehicle unavailable." }),
  expectedUpdatedAt: z.iso.datetime({ error: "Vehicle unavailable." }),
}).strict();

export const vehicleMileageSchema = z.object({
  vehicleId: z.uuid({ error: "Vehicle unavailable." }),
  expectedUpdatedAt: z.iso.datetime({ error: "Vehicle unavailable." }),
  mileage: z.coerce.number({ error: "Enter mileage." }).int("Mileage must be a whole number.").min(0, "Mileage cannot be negative."),
}).strict();

export const vehicleLifecycleSchema = z.object({
  vehicleId: z.uuid({ error: "Vehicle unavailable." }),
  operation: z.enum(VEHICLE_OPERATIONS),
}).strict();

export const vehicleTargetSchema = z.object({ vehicleId: z.uuid({ error: "Vehicle unavailable." }) }).strict();
export const vehicleListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  status: z.enum(["all", ...VEHICLE_STATUSES]).catch("all"),
  type: z.string().trim().max(100).catch("all").transform((value) => value === "" ? "all" : value),
  page: z.coerce.number().int().positive().catch(1),
});

export type VehicleStatus = typeof VEHICLE_STATUSES[number];
export type VehicleOperation = typeof VEHICLE_OPERATIONS[number];
export type VehicleFormInput = Readonly<z.infer<typeof vehicleFormSchema>>;
export type VehicleCreateInput = Readonly<z.infer<typeof vehicleCreateSchema>>;
export type VehicleEditInput = Readonly<z.infer<typeof vehicleEditSchema>>;
export type VehicleMileageInput = Readonly<z.infer<typeof vehicleMileageSchema>>;
export type VehicleLifecycleInput = Readonly<z.infer<typeof vehicleLifecycleSchema>>;
