"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { editShipmentAction, type ShipmentActionState } from "@/app/(operations)/operations/shipments/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { ShipmentEditRecord } from "@/lib/dal/shipments";

const INITIAL_STATE: ShipmentActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
const DESTINATIONS = { unauthenticated: "/login", inactive_profile: "/account-inactive", missing_profile: "/account-error", forbidden: "/forbidden" } as const;

function localDateTime(value:string) {
  const date=new Date(value);
  return new Date(date.getTime()-date.getTimezoneOffset()*60_000).toISOString().slice(0,16);
}

export function ShipmentEditForm({shipment,role}:Readonly<{shipment:ShipmentEditRecord;role:"admin"|"dispatcher"}>) {
  const router=useRouter();
  const [state,action,pending]=useActionState(editShipmentAction,INITIAL_STATE);
  useEffect(()=>{if(state.status in DESTINATIONS)router.replace(DESTINATIONS[state.status as keyof typeof DESTINATIONS]);},[router,state.status]);
  const fields=[
    ["pickupAddress","Pickup address","text",shipment.pickupAddress],
    ["deliveryAddress","Delivery address","text",shipment.deliveryAddress],
    ["pickupAt","Pickup date and time","datetime-local",localDateTime(shipment.pickupAt)],
    ["expectedDeliveryAt","Expected delivery date and time","datetime-local",localDateTime(shipment.expectedDeliveryAt)],
    ["cargoType","Cargo type","text",shipment.cargoType],
  ] as const;
  return <form action={action} className="flex flex-col gap-4" noValidate>
    <input type="hidden" name="shipmentId" value={shipment.id}/><input type="hidden" name="expectedUpdatedAt" value={shipment.updatedAt}/>
    <div className="grid gap-4 md:grid-cols-2">{fields.map(([name,label,type,value])=>{const error=state.fieldErrors[name]?.[0];return <div key={name} className="flex flex-col gap-2"><label htmlFor={`shipment-${name}`} className="text-label text-foreground">{label}</label><Input id={`shipment-${name}`} name={name} type={type} defaultValue={value} required disabled={pending} invalid={Boolean(error)} aria-describedby={error?`shipment-${name}-error`:undefined} className="min-h-11 md:min-h-10" focusSurface="card"/>{error?<p id={`shipment-${name}-error`} className="text-small text-danger">{error}</p>:null}</div>;})}
      {role==="admin"?<div className="flex flex-col gap-2"><label htmlFor="shipment-price" className="text-label text-foreground">Price</label><Input id="shipment-price" name="price" type="number" min={0} step="0.01" defaultValue={shipment.price} required disabled={pending} invalid={Boolean(state.fieldErrors.price?.[0])} aria-describedby={state.fieldErrors.price?.[0]?"shipment-price-error":undefined} className="min-h-11 md:min-h-10" focusSurface="card"/>{state.fieldErrors.price?.[0]?<p id="shipment-price-error" className="text-small text-danger">{state.fieldErrors.price[0]}</p>:null}</div>:null}
    </div>
    {state.status!=="validation"&&state.message?<p role="alert" aria-live="polite" className="text-small text-danger">{state.message}{state.status==="infrastructure"&&state.correlationId?` Reference: ${state.correlationId}`:""}</p>:null}
    <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending} focusSurface="card" onClick={()=>router.push("/operations/shipments")}>Cancel</Button><Button type="submit" className="min-h-11 w-full sm:w-auto" loading={pending} disabled={pending} focusSurface="card">Save changes</Button></div>
  </form>;
}
