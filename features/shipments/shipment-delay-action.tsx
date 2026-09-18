"use client";
import { useActionState, useState } from "react";
import { setShipmentDelayedAction, type ShipmentActionState } from "@/app/(operations)/operations/shipments/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
const initialState: ShipmentActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
export function ShipmentDelayAction({ shipmentId, trackingNumber, delayed, updatedAt }: Readonly<{shipmentId:string;trackingNumber:string;delayed:boolean;updatedAt:string}>) {
  const [open,setOpen]=useState(false);
  const [state,action,pending]=useActionState(async (previousState: ShipmentActionState, formData: FormData) => {
    const nextState = await setShipmentDelayedAction(previousState, formData);
    if (nextState.status === "success") setOpen(false);
    return nextState;
  },initialState);
  const verb=delayed?"Clear delay":"Mark delayed";
  return <Dialog open={open} onOpenChange={setOpen}><DialogTrigger asChild><Button type="button" variant="outline">{verb}</Button></DialogTrigger><DialogContent><DialogTitle>{verb}</DialogTitle><DialogDescription>{delayed?`Clear the delayed condition for ${trackingNumber}?`:`Mark ${trackingNumber} as delayed and notify its Driver?`}</DialogDescription><form action={action} className="space-y-4"><input type="hidden" name="shipmentId" value={shipmentId}/><input type="hidden" name="delayed" value={String(!delayed)}/><input type="hidden" name="expectedUpdatedAt" value={updatedAt}/>{state.message?<p role="alert" className="text-body text-danger">{state.message}{state.status==="infrastructure"&&state.correlationId?` Reference: ${state.correlationId}`:""}</p>:null}<DialogFooter><DialogClose asChild><Button type="button" variant="outline" disabled={pending}>Cancel</Button></DialogClose><Button type="submit" loading={pending} disabled={pending}>{verb}</Button></DialogFooter></form></DialogContent></Dialog>;
}
