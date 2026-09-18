import { z } from "zod";

export const accountProvisioningSchema = z
  .object({
    fullName: z
      .string({ error: "Enter the full name." })
      .trim()
      .min(1, "Enter the full name."),
    username: z
      .string({ error: "Enter a username." })
      .trim()
      .min(1, "Enter a username."),
    initialPassword: z
      .string({ error: "Enter an initial password." })
      .min(1, "Enter an initial password."),
    role: z.enum(["dispatcher", "driver"], {
      error: "Select Dispatcher or Driver.",
    }),
  })
  .strict();

export type AccountProvisioningInput = Readonly<
  z.infer<typeof accountProvisioningSchema>
>;
