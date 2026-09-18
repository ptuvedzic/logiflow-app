"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { assignShipmentAction, type ShipmentActionState } from "@/app/(operations)/operations/shipments/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Select } from "@/components/ui/select";
import type { ShipmentCandidateData } from "@/lib/dal/shipments";

const INITIAL_STATE: ShipmentActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };

export function ShipmentAssignment({ shipmentId, candidates }: Readonly<{ shipmentId: string; candidates: ShipmentCandidateData }>) {
  const [open, setOpen] = useState(false);
  const [state, action, pending] = useActionState(assignShipmentAction, INITIAL_STATE);
  const router = useRouter();
  useEffect(() => { if (state.status === "success") router.refresh(); }, [state.status, router]);
  const driverError = state.fieldErrors.driverId?.[0];
  const vehicleError = state.fieldErrors.vehicleId?.[0];
  return <Dialog open={open} onOpenChange={setOpen}><DialogTrigger asChild><Button variant="outline" className="min-h-11 md:min-h-10" focusSurface="card">Assign</Button></DialogTrigger><DialogContent><form action={action} className="flex flex-col gap-4">
    <DialogHeader><DialogTitle>Assign shipment</DialogTitle><DialogDescription>Select an eligible Driver and Vehicle.</DialogDescription></DialogHeader><input type="hidden" name="shipmentId" value={shipmentId} />
    <div className="flex flex-col gap-2"><label htmlFor={`driver-${shipmentId}`} className="text-label">Driver</label><Select id={`driver-${shipmentId}`} name="driverId" required disabled={pending} invalid={Boolean(driverError)} aria-describedby={driverError ? `driver-${shipmentId}-error` : undefined} className="min-h-11" focusSurface="card"><option value="">Select Driver</option>{candidates.drivers.map((driver) => <option key={driver.id} value={driver.id}>{driver.displayName}</option>)}</Select>{driverError ? <p id={`driver-${shipmentId}-error`} className="text-small text-danger">{driverError}</p> : null}</div>
    <div className="flex flex-col gap-2"><label htmlFor={`vehicle-${shipmentId}`} className="text-label">Vehicle</label><Select id={`vehicle-${shipmentId}`} name="vehicleId" required disabled={pending} invalid={Boolean(vehicleError)} aria-describedby={vehicleError ? `vehicle-${shipmentId}-error` : undefined} className="min-h-11" focusSurface="card"><option value="">Select Vehicle</option>{candidates.vehicles.map((vehicle) => <option key={vehicle.id} value={vehicle.id}>{vehicle.registration} - {vehicle.make} {vehicle.model}</option>)}</Select>{vehicleError ? <p id={`vehicle-${shipmentId}-error`} className="text-small text-danger">{vehicleError}</p> : null}</div>
    {state.message ? <p role={state.status === "success" ? "status" : "alert"} aria-live="polite" className={state.status === "success" ? "text-small text-success" : "text-small text-danger"}>{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}
    <DialogFooter><Button type="button" variant="outline" disabled={pending} onClick={() => setOpen(false)} focusSurface="card">{state.status === "success" ? "Close" : "Cancel"}</Button>{state.status !== "success" ? <Button type="submit" loading={pending} disabled={pending || candidates.drivers.length === 0 || candidates.vehicles.length === 0} focusSurface="card">Assign shipment</Button> : null}</DialogFooter>
  </form></DialogContent></Dialog>;
}
