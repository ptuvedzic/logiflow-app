import { z } from "zod";

export const MESSAGE_BODY_MAX_LENGTH = 500;

export const messageSendSchema = z.object({
  driverId: z.string().uuid("Select an eligible Driver."),
  shipmentId: z
    .union([z.string().uuid("Select an eligible Shipment."), z.literal("")])
    .transform((value) => value || null),
  body: z
    .string()
    .trim()
    .min(1, "Message is required.")
    .max(MESSAGE_BODY_MAX_LENGTH, "Message must be 500 characters or fewer."),
});

export type MessageSendInput = z.infer<typeof messageSendSchema>;
export type MessageActionStatus =
  | "idle"
  | "success"
  | "validation"
  | "not_found"
  | "business_rule"
  | "rate_limited"
  | "unauthenticated"
  | "missing_profile"
  | "inactive_profile"
  | "forbidden"
  | "infrastructure";

export type MessageActionState = Readonly<{
  status: MessageActionStatus;
  message: string | null;
  fieldErrors: Readonly<Record<string, string[] | undefined>>;
  correlationId: string | null;
}>;
