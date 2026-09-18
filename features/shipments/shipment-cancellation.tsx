"use client";

import { useActionState, useState } from "react";
import { cancelShipmentAction, type ShipmentActionState } from "@/app/(operations)/operations/shipments/actions";
import { Button } from "@/components/ui/button";
import { Dialog,DialogClose,DialogContent,DialogDescription,DialogFooter,DialogHeader,DialogTitle,DialogTrigger } from "@/components/ui/dialog";

const INITIAL_STATE:ShipmentActionState={status:"idle",message:null,fieldErrors:{},correlationId:null};

export function ShipmentCancellation({shipmentId,trackingNumber}:Readonly<{shipmentId:string;trackingNumber:string}>) {
  const [open,setOpen]=useState(false); const [state,action,pending]=useActionState(cancelShipmentAction,INITIAL_STATE);
  return <Dialog open={open&&state.status!=="success"} onOpenChange={(next)=>{if(!pending)setOpen(next);}}><DialogTrigger asChild><Button variant="outline" className="min-h-11 text-danger md:min-h-10" focusSurface="card">Cancel</Button></DialogTrigger><DialogContent><form action={action} className="flex flex-col gap-4"><DialogHeader><DialogTitle>Cancel shipment?</DialogTitle><DialogDescription>Shipment {trackingNumber} will be cancelled. This action cannot be reversed.</DialogDescription></DialogHeader><input type="hidden" name="shipmentId" value={shipmentId}/>{state.message&&state.status!=="success"?<p role="alert" aria-live="polite" className="text-small text-danger">{state.message}{state.status==="infrastructure"&&state.correlationId?` Reference: ${state.correlationId}`:""}</p>:null}<DialogFooter><DialogClose asChild><Button type="button" variant="outline" disabled={pending} focusSurface="card">Keep shipment</Button></DialogClose><Button type="submit" variant="destructive" loading={pending} disabled={pending} className="min-h-11" focusSurface="card">Cancel shipment</Button></DialogFooter></form></DialogContent></Dialog>;
}
