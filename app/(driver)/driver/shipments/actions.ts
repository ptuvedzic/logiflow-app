"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { shipmentStatusRequestSchema } from "@/features/shipments/shipment-schema";
import type { ShipmentActionState } from "@/features/shipments/shipment-schema";
import { requireRole } from "@/lib/dal/auth";
import { createShipmentStatusRequest } from "@/lib/dal/shipments";

const EMPTY_ERRORS=Object.freeze({});
function failure(status:ShipmentActionState["status"],message:string,correlationId:string):ShipmentActionState{return {status,message,fieldErrors:EMPTY_ERRORS,correlationId};}

export async function createShipmentStatusRequestAction(_state:ShipmentActionState,formData:FormData):Promise<ShipmentActionState>{
  const correlationId=randomUUID();
  const actor=await requireRole("driver");
  if(!actor.ok)return failure(actor.error.category,actor.error.message,correlationId);
  const parsed=shipmentStatusRequestSchema.safeParse({requestedStatus:formData.get("requestedStatus")});
  if(!parsed.success)return failure("validation","Shipment status action unavailable.",correlationId);
  const result=await createShipmentStatusRequest(parsed.data.requestedStatus);
  if(!result.ok){
    if(result.error.category==="infrastructure")console.error({operation:"shipments.status_request.create",category:"infrastructure",actorProfileId:actor.data.id,correlationId});
    return failure(result.error.category,result.error.message,correlationId);
  }
  revalidatePath("/driver/shipments");
  revalidatePath("/operations/shipments");
  return {status:"success",message:"Shipment status request sent.",fieldErrors:EMPTY_ERRORS,correlationId};
}
