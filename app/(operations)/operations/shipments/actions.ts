"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { adminShipmentEditSchema, dispatcherShipmentEditSchema, shipmentAssignmentSchema, shipmentCreateSchema, shipmentDelaySchema, shipmentStatusRejectionSchema, shipmentStatusResolutionSchema, shipmentTargetSchema } from "@/features/shipments/shipment-schema";
import type { ShipmentActionState } from "@/features/shipments/shipment-schema";
import { requireRole } from "@/lib/dal/auth";
import { approveShipmentStatusRequest, assignPendingShipment, cancelShipment, createPendingShipment, rejectShipmentStatusRequest, setShipmentDelayed, updateShipmentDetails } from "@/lib/dal/shipments";

export type { ShipmentActionState } from "@/features/shipments/shipment-schema";
const EMPTY_ERRORS = Object.freeze({});
function failure(status: ShipmentActionState["status"], message: string, correlationId: string): ShipmentActionState { return { status, message, fieldErrors: EMPTY_ERRORS, correlationId }; }
async function authorize(correlationId: string) { const result=await requireRole("admin","dispatcher"); return result.ok?result:failure(result.error.category,result.error.message,correlationId); }
function logInfrastructureFailure(operation:string,actorProfileId:string,correlationId:string){console.error({operation,category:"infrastructure",actorProfileId,correlationId});}

export async function createShipmentAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  const parsed=shipmentCreateSchema.safeParse({clientId:formData.get("clientId"),pickupAddress:formData.get("pickupAddress"),deliveryAddress:formData.get("deliveryAddress"),pickupAt:formData.get("pickupAt"),expectedDeliveryAt:formData.get("expectedDeliveryAt"),cargoType:formData.get("cargoType"),price:formData.get("price")});
  if(!parsed.success) return {status:"validation",message:"Check the highlighted fields.",fieldErrors:z.flattenError(parsed.error).fieldErrors,correlationId};
  const result=await createPendingShipment(parsed.data); if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.create",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments"); redirect("/operations/shipments");
}
export async function assignShipmentAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  const parsed=shipmentAssignmentSchema.safeParse({shipmentId:formData.get("shipmentId"),driverId:formData.get("driverId"),vehicleId:formData.get("vehicleId")});
  if(!parsed.success) return {status:"validation",message:"Select an eligible Driver and Vehicle.",fieldErrors:z.flattenError(parsed.error).fieldErrors,correlationId};
  const result=await assignPendingShipment(parsed.data); if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.assign",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments"); return {status:"success",message:"Shipment assigned.",fieldErrors:EMPTY_ERRORS,correlationId};
}

export async function approveShipmentStatusRequestAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  const parsed=shipmentStatusResolutionSchema.safeParse({requestId:formData.get("requestId")});
  if(!parsed.success)return failure("validation","Status request unavailable.",correlationId);
  const result=await approveShipmentStatusRequest(parsed.data.requestId);
  if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.status_request.approve",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments"); revalidatePath("/driver/shipments");
  return {status:"success",message:"Shipment status approved.",fieldErrors:EMPTY_ERRORS,correlationId};
}

export async function rejectShipmentStatusRequestAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  const parsed=shipmentStatusRejectionSchema.safeParse({requestId:formData.get("requestId"),rejectionReason:formData.get("rejectionReason")});
  if(!parsed.success)return {status:"validation",message:"Check the rejection reason.",fieldErrors:z.flattenError(parsed.error).fieldErrors,correlationId};
  const result=await rejectShipmentStatusRequest(parsed.data.requestId,parsed.data.rejectionReason);
  if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.status_request.reject",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments"); revalidatePath("/driver/shipments");
  return {status:"success",message:"Shipment status request rejected.",fieldErrors:EMPTY_ERRORS,correlationId};
}

export async function editShipmentAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  if(actor.data.role==="dispatcher" && formData.has("price")) return failure("forbidden","Dispatchers cannot edit Shipment price.",correlationId);
  const values={shipmentId:formData.get("shipmentId"),expectedUpdatedAt:formData.get("expectedUpdatedAt"),pickupAddress:formData.get("pickupAddress"),deliveryAddress:formData.get("deliveryAddress"),pickupAt:formData.get("pickupAt"),expectedDeliveryAt:formData.get("expectedDeliveryAt"),cargoType:formData.get("cargoType"),price:formData.get("price")};
  const parsed=actor.data.role==="admin"?adminShipmentEditSchema.safeParse(values):dispatcherShipmentEditSchema.safeParse(values);
  if(!parsed.success)return {status:"validation",message:"Check the highlighted fields.",fieldErrors:z.flattenError(parsed.error).fieldErrors,correlationId};
  const result=await updateShipmentDetails(parsed.data);
  if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.edit",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments"); redirect("/operations/shipments");
}

export async function cancelShipmentAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  const parsed=shipmentTargetSchema.safeParse({shipmentId:formData.get("shipmentId")});
  if(!parsed.success)return failure("validation","Shipment unavailable.",correlationId);
  const result=await cancelShipment(parsed.data.shipmentId);
  if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.cancel",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments"); revalidatePath("/driver/shipments");
  return {status:"success",message:"Shipment cancelled.",fieldErrors:EMPTY_ERRORS,correlationId};
}
export async function setShipmentDelayedAction(_state: ShipmentActionState, formData: FormData): Promise<ShipmentActionState> {
  const correlationId=randomUUID(); const actor=await authorize(correlationId); if (!("ok" in actor)) return actor;
  const parsed=shipmentDelaySchema.safeParse({shipmentId:formData.get("shipmentId"),delayed:formData.get("delayed"),expectedUpdatedAt:formData.get("expectedUpdatedAt")});
  if(!parsed.success)return failure("validation","Shipment delay action is invalid.",correlationId);
  const result=await setShipmentDelayed(parsed.data); if(!result.ok){if(result.error.category==="infrastructure")logInfrastructureFailure("shipments.delay.set",actor.data.id,correlationId);return failure(result.error.category,result.error.message,correlationId);}
  revalidatePath("/operations/shipments");revalidatePath("/operations/alerts");revalidatePath("/operations/activity");revalidatePath("/driver/shipments");revalidatePath("/driver/notifications");revalidatePath("/driver","layout");
  return {status:"success",message:result.data.delayed?"Shipment marked delayed.":"Shipment delay cleared.",fieldErrors:EMPTY_ERRORS,correlationId};
}
