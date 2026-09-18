"use client";

import { startTransition, useActionState, useState } from "react";
import { approveShipmentStatusRequestAction, rejectShipmentStatusRequestAction } from "@/app/(operations)/operations/shipments/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import type { ShipmentActionState } from "@/features/shipments/shipment-schema";

const INITIAL_STATE:ShipmentActionState={status:"idle",message:null,fieldErrors:{},correlationId:null};

export function ShipmentStatusRequestActions({requestId,trackingNumber}:Readonly<{requestId:string;trackingNumber:string}>){
  const [rejectOpen,setRejectOpen]=useState(false);
  const [approveState,approveAction,approving]=useActionState(approveShipmentStatusRequestAction,INITIAL_STATE);
  const [rejectState,rejectAction,rejecting]=useActionState(rejectShipmentStatusRequestAction,INITIAL_STATE);
  function approve(){const data=new FormData();data.set("requestId",requestId);startTransition(()=>approveAction(data));}
  return <div className="flex min-w-max items-center justify-end gap-2">
    <Button variant="outline" className="min-h-11 md:min-h-10" disabled={approving||rejecting} loading={approving} onClick={approve} focusSurface="card">Approve</Button>
    <Button variant="destructive" className="min-h-11 md:min-h-10" disabled={approving||rejecting} onClick={()=>setRejectOpen(true)} focusSurface="card">Reject</Button>
    {approveState.message?<span role={approveState.status==="success"?"status":"alert"} aria-live="polite" className={approveState.status==="success"?"text-caption text-success":"text-caption text-danger"}>{approveState.message}</span>:null}
    <Dialog open={rejectOpen} onOpenChange={setRejectOpen}><DialogContent><form action={rejectAction} className="flex flex-col gap-4"><DialogHeader><DialogTitle>Reject status request?</DialogTitle><DialogDescription>Reject the pending status request for {trackingNumber}. A reason is optional.</DialogDescription></DialogHeader><input type="hidden" name="requestId" value={requestId}/><div className="flex flex-col gap-2"><label htmlFor={`rejection-${requestId}`} className="text-label text-foreground">Reason (optional)</label><Textarea id={`rejection-${requestId}`} name="rejectionReason" maxLength={500} disabled={rejecting} invalid={Boolean(rejectState.fieldErrors.rejectionReason?.[0])} aria-describedby={rejectState.fieldErrors.rejectionReason?.[0]?`rejection-${requestId}-error`:undefined} focusSurface="card"/>{rejectState.fieldErrors.rejectionReason?.[0]?<p id={`rejection-${requestId}-error`} className="text-small text-danger">{rejectState.fieldErrors.rejectionReason[0]}</p>:null}</div>{rejectState.message?<p role={rejectState.status==="success"?"status":"alert"} aria-live="polite" className={rejectState.status==="success"?"text-small text-success":"text-small text-danger"}>{rejectState.message}{rejectState.status==="infrastructure"&&rejectState.correlationId?` Reference: ${rejectState.correlationId}`:""}</p>:null}<DialogFooter><DialogClose asChild><Button type="button" variant="outline" disabled={rejecting} focusSurface="card">{rejectState.status==="success"?"Close":"Cancel"}</Button></DialogClose>{rejectState.status!=="success"?<Button type="submit" variant="destructive" loading={rejecting} disabled={rejecting} focusSurface="card">Reject request</Button>:null}</DialogFooter></form></DialogContent></Dialog>
  </div>;
}
