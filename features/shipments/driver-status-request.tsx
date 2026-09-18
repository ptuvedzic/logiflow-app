"use client";

import { useActionState, useState } from "react";
import { createShipmentStatusRequestAction } from "@/app/(driver)/driver/shipments/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { StatusBadge } from "@/components/ui/status-badge";
import { shipmentStatusLabels } from "@/features/shipments/shipment-schema";
import type { ShipmentActionState } from "@/features/shipments/shipment-schema";
import type { CurrentDriverShipment } from "@/lib/dal/shipments";

const INITIAL_STATE:ShipmentActionState={status:"idle",message:null,fieldErrors:{},correlationId:null};
const nextAction={assigned:{status:"loading",label:"Start Loading"},loading:{status:"in_transit",label:"Start Trip"},in_transit:{status:"delivered",label:"Complete Delivery"}} as const;

export function DriverStatusRequest({shipment}:Readonly<{shipment:CurrentDriverShipment}>){
  const [open,setOpen]=useState(false);
  const [state,action,pending]=useActionState(createShipmentStatusRequestAction,INITIAL_STATE);
  const pendingRequest=shipment.statusRequest?.state==="pending"?shipment.statusRequest:null;
  const next=shipment.status in nextAction?nextAction[shipment.status as keyof typeof nextAction]:null;
  return <div className="flex flex-col gap-3 border-t border-border pt-4">
    {shipment.statusRequest?<div className="flex flex-wrap items-center gap-2"><StatusBadge domain="status_request" status={shipment.statusRequest.state}/><p className="text-small text-secondary">{pendingRequest?`${shipmentStatusLabels[pendingRequest.requestedStatus]} requested.`:`${shipmentStatusLabels[shipment.statusRequest.requestedStatus]} request ${shipment.statusRequest.state}.`}</p></div>:null}
    {!pendingRequest&&next?<Dialog open={open} onOpenChange={setOpen}><DialogTrigger asChild><Button className="min-h-11 w-full sm:w-fit" focusSurface="card">{next.label}</Button></DialogTrigger><DialogContent><form action={action} className="flex flex-col gap-4"><DialogHeader><DialogTitle>{next.label}?</DialogTitle><DialogDescription>Request that Operations change this Shipment to {shipmentStatusLabels[next.status]}. The official status changes only after approval.</DialogDescription></DialogHeader><input type="hidden" name="requestedStatus" value={next.status}/>{state.message?<p role={state.status==="success"?"status":"alert"} aria-live="polite" className={state.status==="success"?"text-small text-success":"text-small text-danger"}>{state.message}{state.status==="infrastructure"&&state.correlationId?` Reference: ${state.correlationId}`:""}</p>:null}<DialogFooter><DialogClose asChild><Button type="button" variant="outline" disabled={pending} focusSurface="card">{state.status==="success"?"Close":"Cancel"}</Button></DialogClose>{state.status!=="success"?<Button type="submit" loading={pending} disabled={pending} focusSurface="card">Send request</Button>:null}</DialogFooter></form></DialogContent></Dialog>:null}
    {state.message&&!open?<p role={state.status==="success"?"status":"alert"} aria-live="polite" className={state.status==="success"?"text-small text-success":"text-small text-danger"}>{state.message}</p>:null}
  </div>;
}
