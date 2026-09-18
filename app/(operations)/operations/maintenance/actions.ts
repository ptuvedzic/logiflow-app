"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { maintenanceCreateSchema, maintenanceEditSchema } from "@/features/maintenance/maintenance-schema";
import { requireRole } from "@/lib/dal/auth";
import { createMaintenanceRecord, updateMaintenanceRecord } from "@/lib/dal/maintenance";

export type MaintenanceActionState = Readonly<{
  status: "idle" | "validation" | "not_found" | "conflict" | "business_rule" | "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure";
  message: string | null; fieldErrors: Readonly<Record<string, string[] | undefined>>; correlationId: string | null;
}>;
const EMPTY_ERRORS = Object.freeze({});
const failure = (status: MaintenanceActionState["status"], message: string, correlationId: string): MaintenanceActionState => ({ status, message, fieldErrors: EMPTY_ERRORS, correlationId });
function values(formData: FormData) { return { serviceType: formData.get("serviceType"), serviceDate: formData.get("serviceDate"), mileageAtService: formData.get("mileageAtService"), workshop: formData.get("workshop"), cost: formData.get("cost"), notes: formData.get("notes"), nextServiceDate: formData.get("nextServiceDate"), nextServiceMileage: formData.get("nextServiceMileage") }; }
function logFailure(operation: string, actorProfileId: string, recordId: string | null, correlationId: string) { console.error({ operation, category: "infrastructure", actorProfileId, maintenanceRecordId: recordId, correlationId }); }

export async function createMaintenanceRecordAction(_state: MaintenanceActionState, formData: FormData): Promise<MaintenanceActionState> {
  const correlationId = randomUUID(); const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = maintenanceCreateSchema.safeParse({ vehicleId: formData.get("vehicleId"), ...values(formData) });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted fields.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await createMaintenanceRecord(parsed.data);
  if (!result.ok) { if (result.error.category === "infrastructure") logFailure("maintenance.create", actor.data.id, null, correlationId); return failure(result.error.category, result.error.message, correlationId); }
  revalidatePath("/operations/maintenance"); revalidatePath("/operations/vehicles"); revalidatePath("/operations/activity"); redirect("/operations/maintenance");
}

export async function editMaintenanceRecordAction(_state: MaintenanceActionState, formData: FormData): Promise<MaintenanceActionState> {
  const correlationId = randomUUID(); const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = maintenanceEditSchema.safeParse({ maintenanceRecordId: formData.get("maintenanceRecordId"), expectedUpdatedAt: formData.get("expectedUpdatedAt"), ...values(formData) });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted fields.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await updateMaintenanceRecord(parsed.data);
  if (!result.ok) { if (result.error.category === "infrastructure") logFailure("maintenance.edit", actor.data.id, parsed.data.maintenanceRecordId, correlationId); return failure(result.error.category, result.error.message, correlationId); }
  revalidatePath("/operations/maintenance");
  if (result.data === "updated") { revalidatePath("/operations/vehicles"); revalidatePath("/operations/activity"); }
  redirect("/operations/maintenance");
}
