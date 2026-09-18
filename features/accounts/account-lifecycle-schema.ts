import { z } from "zod";

const managedUsernameSchema = z
  .string({ error: "Account unavailable." })
  .trim()
  .min(1, "Account unavailable.")
  .max(200, "Account unavailable.");

export const accountListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""),
  role: z.enum(["all", "dispatcher", "driver"]).catch("all"),
  status: z.enum(["all", "active", "inactive"]).catch("all"),
  page: z.coerce.number().int().positive().catch(1),
});

export const accountLifecycleSchema = z.object({
  username: managedUsernameSchema,
  operation: z.enum(["deactivate", "reactivate"]),
}).strict();

export const administrativePasswordResetSchema = z
  .object({
    username: managedUsernameSchema,
    newPassword: z.string({ error: "Enter a new password." }).min(1, "Enter a new password."),
    confirmPassword: z.string({ error: "Confirm the new password." }).min(1, "Confirm the new password."),
  })
  .strict()
  .refine((input) => input.newPassword === input.confirmPassword, {
    path: ["confirmPassword"],
    message: "Passwords do not match.",
  });

export type AccountLifecycleInput = Readonly<z.infer<typeof accountLifecycleSchema>>;
export type AdministrativePasswordResetInput = Readonly<z.infer<typeof administrativePasswordResetSchema>>;
