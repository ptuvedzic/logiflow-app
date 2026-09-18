"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createVehicleAction, editVehicleAction, type VehicleActionState } from "@/app/(operations)/operations/vehicles/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { VehicleRecord } from "@/lib/dal/vehicles";

const INITIAL_STATE: VehicleActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
const DESTINATIONS = { unauthenticated: "/login", inactive_profile: "/account-inactive", missing_profile: "/account-error", forbidden: "/forbidden" } as const;

export function VehicleForm({ vehicle }: Readonly<{ vehicle?: VehicleRecord }>) {
  const router = useRouter();
  const [state, action, pending] = useActionState(vehicle ? editVehicleAction : createVehicleAction, INITIAL_STATE);
  useEffect(() => { if (state.status in DESTINATIONS) router.replace(DESTINATIONS[state.status as keyof typeof DESTINATIONS]); }, [router, state.status]);
  const fields = [
    ["registration", "Registration", vehicle?.registration ?? "", true, "text", 32],
    ["make", "Make", vehicle?.make ?? "", true, "text", undefined],
    ["model", "Model", vehicle?.model ?? "", true, "text", undefined],
    ["vehicleType", "Vehicle type", vehicle?.vehicleType ?? "", true, "text", undefined],
    ["vin", "VIN", vehicle?.vin ?? "", false, "text", 64],
    ["fuelType", "Fuel type", vehicle?.fuelType ?? "", false, "text", undefined],
    ["firstRegistrationDate", "First registration date", vehicle?.firstRegistrationDate ?? "", false, "date", undefined],
  ] as const;
  return <form action={action} className="flex flex-col gap-4" noValidate>
    {vehicle ? <><input type="hidden" name="vehicleId" value={vehicle.id} /><input type="hidden" name="expectedUpdatedAt" value={vehicle.updatedAt} /></> : null}
    <div className="grid gap-4 md:grid-cols-2">{fields.map(([name, label, value, required, type, maxLength]) => { const error = state.fieldErrors[name]?.[0]; return <div key={name} className="flex flex-col gap-2"><label htmlFor={`vehicle-${name}`} className="text-label text-foreground">{label}</label><Input id={`vehicle-${name}`} name={name} defaultValue={value} required={required} type={type} maxLength={maxLength} disabled={pending} invalid={Boolean(error)} aria-describedby={error ? `vehicle-${name}-error` : undefined} className="min-h-11 md:min-h-10" focusSurface="card" />{error ? <p id={`vehicle-${name}-error`} className="text-small text-danger">{error}</p> : null}</div>; })}
      {!vehicle ? <div className="flex flex-col gap-2"><label htmlFor="vehicle-mileage" className="text-label text-foreground">Mileage (km)</label><Input id="vehicle-mileage" name="mileage" type="number" min={0} step={1} defaultValue={0} required disabled={pending} invalid={Boolean(state.fieldErrors.mileage?.[0])} className="min-h-11 md:min-h-10" focusSurface="card" />{state.fieldErrors.mileage?.[0] ? <p className="text-small text-danger">{state.fieldErrors.mileage[0]}</p> : null}</div> : null}
    </div>
    {state.status !== "validation" && state.message ? <p role="alert" className="text-small text-danger">{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}
    <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending} focusSurface="card" onClick={() => router.push("/operations/vehicles")}>Cancel</Button><Button type="submit" className="min-h-11 w-full sm:w-auto" loading={pending} disabled={pending} focusSurface="card">{vehicle ? "Save changes" : "Create vehicle"}</Button></div>
  </form>;
}
