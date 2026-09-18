"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { driverOperationSchema, driverPhoneEditSchema } from "@/features/drivers/driver-schema";
import { requireRole } from "@/lib/dal/auth";
import { changeDriverOperationalStatus, updateDriverPhone } from "@/lib/dal/drivers";

export type DriverActionState = Readonly<{
  status: "idle" | "success" | "validation" | "not_found" | "conflict" | "business_rule" | "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure";
  message: string | null;
  fieldErrors: Readonly<Record<string, string[] | undefined>>;
  correlationId: string | null;
}>;

const EMPTY_ERRORS = Object.freeze({});
function failure(status: DriverActionState["status"], message: string, correlationId: string): DriverActionState { return { status, message, fieldErrors: EMPTY_ERRORS, correlationId }; }
function logFailure(operation: string, actorProfileId: string, driverId: string, correlationId: string) { console.error({ operation, category: "infrastructure", actorProfileId, driverId, correlationId }); }

export async function editDriverPhoneAction(_state: DriverActionState, formData: FormData): Promise<DriverActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = driverPhoneEditSchema.safeParse({ driverId: formData.get("driverId"), expectedUpdatedAt: formData.get("expectedUpdatedAt"), phone: formData.get("phone") });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted field.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await updateDriverPhone(parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure("drivers.edit_phone", actor.data.id, parsed.data.driverId, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }
  revalidatePath("/operations/drivers");
  redirect("/operations/drivers");
}

export async function changeDriverStatusAction(_state: DriverActionState, formData: FormData): Promise<DriverActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = driverOperationSchema.safeParse({ driverId: formData.get("driverId"), operation: formData.get("operation") });
  if (!parsed.success) return failure("validation", "Driver action unavailable.", correlationId);
  const result = await changeDriverOperationalStatus(parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure(`drivers.${parsed.data.operation}`, actor.data.id, parsed.data.driverId, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }
  revalidatePath("/operations/drivers");
  const labels = { mark_off_duty: "Driver marked off duty.", mark_available: "Driver marked available.", archive: "Driver archived.", reactivate: "Driver reactivated." } as const;
  return { status: "success", message: labels[parsed.data.operation], fieldErrors: EMPTY_ERRORS, correlationId };
}
