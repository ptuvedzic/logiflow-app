import { z } from "zod";

const optionalText = z.string().trim().transform((value) => value === "" ? null : value);
const dateField = (message: string) => z.string().trim().refine((value) => z.iso.date().safeParse(value).success, message);
const optionalDate = z.string().trim().refine((value) => value === "" || z.iso.date().safeParse(value).success, "Enter a valid date.").transform((value) => value === "" ? null : value);
const mileage = (message: string) => z.coerce.number({ error: message }).int("Mileage must be a whole number.").min(0, "Mileage cannot be negative.");
const optionalMileage = z.preprocess((value) => value === "" || value === null ? undefined : value, z.coerce.number().int("Mileage must be a whole number.").min(0, "Mileage cannot be negative.").optional()).transform((value) => value ?? null);
const optionalCost = z.preprocess(
  (value) => value === "" || value === null ? undefined : value,
  z.string().regex(/^\d{1,10}(?:\.\d{1,2})?$/, "Enter a non-negative EUR amount with up to two decimal places.").optional(),
).transform((value) => value === undefined ? null : Number(value));

const businessFields = z.object({
  serviceType: z.string({ error: "Enter the service type." }).trim().min(1, "Enter the service type."),
  serviceDate: dateField("Enter a valid service date."),
  mileageAtService: mileage("Enter mileage."),
  workshop: optionalText,
  cost: optionalCost,
  notes: optionalText,
  nextServiceDate: optionalDate,
  nextServiceMileage: optionalMileage,
}).superRefine((value, context) => {
  if (value.nextServiceDate !== null && value.nextServiceDate <= value.serviceDate) {
    context.addIssue({ code: "custom", path: ["nextServiceDate"], message: "Next service date must be after the service date." });
  }
  if (value.nextServiceMileage !== null && value.nextServiceMileage <= value.mileageAtService) {
    context.addIssue({ code: "custom", path: ["nextServiceMileage"], message: "Next service mileage must be greater than mileage at service." });
  }
});

export const maintenanceCreateSchema = z.object({ vehicleId: z.uuid({ error: "Select a Vehicle." }) }).and(businessFields);
export const maintenanceEditSchema = z.object({
  maintenanceRecordId: z.uuid({ error: "Maintenance record unavailable." }),
  expectedUpdatedAt: z.iso.datetime({ error: "Maintenance record unavailable." }),
}).and(businessFields);
export const maintenanceTargetSchema = z.object({ maintenanceRecordId: z.uuid({ error: "Maintenance record unavailable." }) }).strict();

const queryDate = z.string().trim().refine((value) => value === "" || z.iso.date().safeParse(value).success).catch("");
export const maintenanceListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  vehicle: z.union([z.literal("all"), z.uuid()]).catch("all"),
  from: queryDate,
  to: queryDate,
  page: z.coerce.number().int().positive().catch(1),
}).transform((value) => value.from && value.to && value.from > value.to ? { ...value, from: "", to: "" } : value);

export type MaintenanceCreateInput = Readonly<z.infer<typeof maintenanceCreateSchema>>;
export type MaintenanceEditInput = Readonly<z.infer<typeof maintenanceEditSchema>>;
export type MaintenanceListInput = Readonly<z.infer<typeof maintenanceListQuerySchema>>;
