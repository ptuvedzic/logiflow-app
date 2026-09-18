import { z } from "zod";

const optionalText = z.string().trim().transform((value) => value === "" ? null : value);
const optionalEmail = z.string().trim().refine(
  (value) => value === "" || z.email().safeParse(value).success,
  "Enter a valid email address.",
).transform((value) => value === "" ? null : value);

export const clientFormSchema = z.object({
  companyName: z.string({ error: "Enter the company name." }).trim().min(1, "Enter the company name."),
  contactPerson: optionalText,
  phone: optionalText,
  email: optionalEmail,
  address: optionalText,
  notes: optionalText,
}).strict();

export const clientListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  status: z.enum(["all", "active", "archived"]).catch("all"),
  page: z.coerce.number().int().positive().catch(1),
});

export const clientTargetSchema = z.object({
  clientId: z.uuid({ error: "Client unavailable." }),
}).strict();

export const clientEditSchema = clientFormSchema.extend({
  clientId: z.uuid({ error: "Client unavailable." }),
  expectedUpdatedAt: z.iso.datetime({ error: "Client unavailable." }),
}).strict();

export const clientLifecycleSchema = z.object({
  clientId: z.uuid({ error: "Client unavailable." }),
  operation: z.enum(["archive", "reactivate"]),
}).strict();

export type ClientFormInput = Readonly<z.infer<typeof clientFormSchema>>;
export type ClientEditInput = Readonly<z.infer<typeof clientEditSchema>>;
export type ClientLifecycleInput = Readonly<z.infer<typeof clientLifecycleSchema>>;
