"use client";

import { startTransition, useActionState, useState } from "react";
import { useRouter } from "next/navigation";
import { Archive, CircleCheck, CircleOff, Ellipsis, Gauge, Pencil, RotateCcw, Wrench } from "lucide-react";
import { changeVehicleStatusAction, updateVehicleMileageAction, type VehicleActionState } from "@/app/(operations)/operations/vehicles/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import type { VehicleOperation } from "@/features/vehicles/vehicle-schema";
import type { VehicleListItem, VehicleRecord } from "@/lib/dal/vehicles";

const INITIAL_STATE: VehicleActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };

export function VehicleActions({ vehicle }: Readonly<{ vehicle: VehicleListItem }>) {
  const router = useRouter();
  const [confirmation, setConfirmation] = useState<"archive" | "reactivate" | null>(null);
  const [state, dispatch, pending] = useActionState(changeVehicleStatusAction, INITIAL_STATE);
  function submit(operation: VehicleOperation) { const data = new FormData(); data.set("vehicleId", vehicle.id); data.set("operation", operation); startTransition(() => dispatch(data)); }
  return <div className="flex items-center justify-end gap-2">
    {state.message && confirmation === null ? <span role={state.status === "success" ? "status" : "alert"} className={state.status === "success" ? "text-caption text-success" : "text-caption text-danger"}>{state.message}</span> : null}
    <DropdownMenu><DropdownMenuTrigger asChild><Button aria-label={`Actions for ${vehicle.registration}`} variant="ghost" className="min-h-11 min-w-11 px-0 md:min-h-10 md:min-w-10" disabled={pending} focusSurface="card"><Ellipsis aria-hidden="true" size={20} strokeWidth={1.75} /></Button></DropdownMenuTrigger><DropdownMenuContent>
      <DropdownMenuItem icon={Pencil} onSelect={() => router.push(`/operations/vehicles/${vehicle.id}/edit`)}>Edit</DropdownMenuItem>
      <DropdownMenuItem icon={Gauge} onSelect={() => router.push(`/operations/vehicles/${vehicle.id}/edit#mileage`)}>Update mileage</DropdownMenuItem>
      {vehicle.status === "available" ? <><DropdownMenuItem icon={Wrench} onSelect={() => submit("mark_maintenance")}>Mark maintenance</DropdownMenuItem><DropdownMenuItem icon={CircleOff} onSelect={() => submit("mark_out_of_service")}>Mark out of service</DropdownMenuItem><DropdownMenuItem icon={Archive} variant="destructive" onSelect={() => setConfirmation("archive")}>Archive</DropdownMenuItem></> : null}
      {vehicle.status === "maintenance" ? <><DropdownMenuItem icon={CircleCheck} onSelect={() => submit("mark_available")}>Mark available</DropdownMenuItem><DropdownMenuItem icon={CircleOff} onSelect={() => submit("mark_out_of_service")}>Mark out of service</DropdownMenuItem><DropdownMenuItem icon={Archive} variant="destructive" onSelect={() => setConfirmation("archive")}>Archive</DropdownMenuItem></> : null}
      {vehicle.status === "out_of_service" ? <><DropdownMenuItem icon={CircleCheck} onSelect={() => submit("mark_available")}>Mark available</DropdownMenuItem><DropdownMenuItem icon={Archive} variant="destructive" onSelect={() => setConfirmation("archive")}>Archive</DropdownMenuItem></> : null}
      {vehicle.status === "archived" ? <DropdownMenuItem icon={RotateCcw} onSelect={() => setConfirmation("reactivate")}>Reactivate</DropdownMenuItem> : null}
    </DropdownMenuContent></DropdownMenu>
    <Dialog open={confirmation !== null} onOpenChange={(open) => { if (!open) setConfirmation(null); }}><DialogContent><form action={dispatch} className="flex flex-col gap-4"><DialogHeader><DialogTitle>{confirmation === "archive" ? "Archive vehicle?" : "Reactivate vehicle?"}</DialogTitle><DialogDescription>{confirmation === "archive" ? "The Vehicle will be unavailable for future assignments. Its history remains retained." : "The Vehicle will become available for future assignments."}</DialogDescription></DialogHeader><input type="hidden" name="vehicleId" value={vehicle.id} /><input type="hidden" name="operation" value={confirmation ?? "reactivate"} />{state.message ? <p role={state.status === "success" ? "status" : "alert"} className={state.status === "success" ? "text-small text-success" : "text-small text-danger"}>{state.message}</p> : null}<DialogFooter><DialogClose asChild><Button variant="outline" disabled={pending} focusSurface="card">{state.status === "success" ? "Close" : "Cancel"}</Button></DialogClose>{state.status !== "success" ? <Button type="submit" variant={confirmation === "archive" ? "destructive" : "primary"} loading={pending} disabled={pending} focusSurface="card">{confirmation === "archive" ? "Archive vehicle" : "Reactivate vehicle"}</Button> : null}</DialogFooter></form></DialogContent></Dialog>
  </div>;
}

export function VehicleMileageForm({ vehicle }: Readonly<{ vehicle: VehicleRecord }>) {
  const [state, action, pending] = useActionState(updateVehicleMileageAction, INITIAL_STATE);
  const error = state.fieldErrors.mileage?.[0];
  return <form action={action} className="flex flex-col gap-4" noValidate><input type="hidden" name="vehicleId" value={vehicle.id} /><input type="hidden" name="expectedUpdatedAt" value={vehicle.updatedAt} /><div className="flex max-w-sm flex-col gap-2"><label htmlFor="vehicle-mileage-update" className="text-label text-foreground">Mileage (km)</label><Input id="vehicle-mileage-update" name="mileage" type="number" min={vehicle.mileage} step={1} defaultValue={vehicle.mileage} required disabled={pending} invalid={Boolean(error)} aria-describedby={error ? "vehicle-mileage-update-error" : undefined} className="min-h-11 md:min-h-10" focusSurface="card" />{error ? <p id="vehicle-mileage-update-error" className="text-small text-danger">{error}</p> : null}</div>{state.message ? <p role={state.status === "success" ? "status" : "alert"} className={state.status === "success" ? "text-small text-success" : "text-small text-danger"}>{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}<Button type="submit" className="min-h-11 w-full sm:w-fit" loading={pending} disabled={pending} focusSurface="card">Update mileage</Button></form>;
}
