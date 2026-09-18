"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { vehicleCreateSchema, vehicleEditSchema, vehicleLifecycleSchema, vehicleMileageSchema } from "@/features/vehicles/vehicle-schema";
import { requireRole } from "@/lib/dal/auth";
import { changeVehicleOperationalStatus, createVehicleRecord, updateVehicleMasterData, updateVehicleMileage } from "@/lib/dal/vehicles";

export type VehicleActionState = Readonly<{
  status: "idle" | "success" | "validation" | "not_found" | "conflict" | "business_rule" | "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure";
  message: string | null;
  fieldErrors: Readonly<Record<string, string[] | undefined>>;
  correlationId: string | null;
}>;

const EMPTY_ERRORS = Object.freeze({});
function failure(status: VehicleActionState["status"], message: string, correlationId: string): VehicleActionState { return { status, message, fieldErrors: EMPTY_ERRORS, correlationId }; }
function logFailure(operation: string, actorProfileId: string, vehicleId: string | null, correlationId: string) { console.error({ operation, category: "infrastructure", actorProfileId, vehicleId, correlationId }); }

export async function createVehicleAction(_state: VehicleActionState, formData: FormData): Promise<VehicleActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = vehicleCreateSchema.safeParse({ registration: formData.get("registration"), make: formData.get("make"), model: formData.get("model"), vehicleType: formData.get("vehicleType"), vin: formData.get("vin"), mileage: formData.get("mileage"), fuelType: formData.get("fuelType"), firstRegistrationDate: formData.get("firstRegistrationDate") });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted fields.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await createVehicleRecord(parsed.data);
  if (!result.ok) { if (result.error.category === "infrastructure") logFailure("vehicles.create", actor.data.id, null, correlationId); return failure(result.error.category, result.error.message, correlationId); }
  revalidatePath("/operations/vehicles");
  redirect("/operations/vehicles");
}

export async function editVehicleAction(_state: VehicleActionState, formData: FormData): Promise<VehicleActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = vehicleEditSchema.safeParse({ vehicleId: formData.get("vehicleId"), expectedUpdatedAt: formData.get("expectedUpdatedAt"), registration: formData.get("registration"), make: formData.get("make"), model: formData.get("model"), vehicleType: formData.get("vehicleType"), vin: formData.get("vin"), fuelType: formData.get("fuelType"), firstRegistrationDate: formData.get("firstRegistrationDate") });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted fields.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await updateVehicleMasterData(parsed.data);
  if (!result.ok) { if (result.error.category === "infrastructure") logFailure("vehicles.edit", actor.data.id, parsed.data.vehicleId, correlationId); return failure(result.error.category, result.error.message, correlationId); }
  revalidatePath("/operations/vehicles");
  redirect("/operations/vehicles");
}

export async function updateVehicleMileageAction(_state: VehicleActionState, formData: FormData): Promise<VehicleActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = vehicleMileageSchema.safeParse({ vehicleId: formData.get("vehicleId"), expectedUpdatedAt: formData.get("expectedUpdatedAt"), mileage: formData.get("mileage") });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted field.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await updateVehicleMileage(parsed.data);
  if (!result.ok) { if (result.error.category === "infrastructure") logFailure("vehicles.update_mileage", actor.data.id, parsed.data.vehicleId, correlationId); return failure(result.error.category, result.error.message, correlationId); }
  revalidatePath("/operations/vehicles");
  return { status: "success", message: result.data === "noop" ? "Mileage is already up to date." : "Mileage updated.", fieldErrors: EMPTY_ERRORS, correlationId };
}

export async function changeVehicleStatusAction(_state: VehicleActionState, formData: FormData): Promise<VehicleActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);
  const parsed = vehicleLifecycleSchema.safeParse({ vehicleId: formData.get("vehicleId"), operation: formData.get("operation") });
  if (!parsed.success) return failure("validation", "Vehicle action unavailable.", correlationId);
  const result = await changeVehicleOperationalStatus(parsed.data);
  if (!result.ok) { if (result.error.category === "infrastructure") logFailure(`vehicles.${parsed.data.operation}`, actor.data.id, parsed.data.vehicleId, correlationId); return failure(result.error.category, result.error.message, correlationId); }
  revalidatePath("/operations/vehicles");
  const labels = { mark_maintenance: "Vehicle marked for maintenance.", mark_available: "Vehicle marked available.", mark_out_of_service: "Vehicle marked out of service.", archive: "Vehicle archived.", reactivate: "Vehicle reactivated." } as const;
  return { status: "success", message: labels[parsed.data.operation], fieldErrors: EMPTY_ERRORS, correlationId };
}
