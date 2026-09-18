"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createMaintenanceRecordAction, editMaintenanceRecordAction, type MaintenanceActionState } from "@/app/(operations)/operations/maintenance/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import type { MaintenanceRecord, MaintenanceVehicleOption } from "@/lib/dal/maintenance";

const INITIAL: MaintenanceActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
const DESTINATIONS = { unauthenticated: "/login", inactive_profile: "/account-inactive", missing_profile: "/account-error", forbidden: "/forbidden" } as const;

function Field({ name, label, type = "text", value, required, min, step, error, pending }: Readonly<{ name: string; label: string; type?: string; value: string | number; required?: boolean; min?: number; step?: number; error?: string; pending: boolean }>) {
  const id = `maintenance-${name}`; return <div className="flex flex-col gap-2"><label htmlFor={id} className="text-label text-foreground">{label}</label><Input id={id} name={name} type={type} defaultValue={value} required={required} min={min} step={step} disabled={pending} invalid={Boolean(error)} aria-describedby={error ? `${id}-error` : undefined} className="min-h-11 md:min-h-10" focusSurface="card" />{error ? <p id={`${id}-error`} className="text-small text-danger">{error}</p> : null}</div>;
}

export function MaintenanceForm({ vehicles = [], record }: Readonly<{ vehicles?: readonly MaintenanceVehicleOption[]; record?: MaintenanceRecord }>) {
  const router = useRouter(); const [state, action, pending] = useActionState(record ? editMaintenanceRecordAction : createMaintenanceRecordAction, INITIAL);
  useEffect(() => { if (state.status in DESTINATIONS) router.replace(DESTINATIONS[state.status as keyof typeof DESTINATIONS]); }, [router, state.status]);
  const error = (name: string) => state.fieldErrors[name]?.[0];
  return <form action={action} className="flex flex-col gap-4" noValidate>
    {record ? <><input type="hidden" name="maintenanceRecordId" value={record.id} /><input type="hidden" name="expectedUpdatedAt" value={record.updatedAt} /><div className="flex flex-col gap-2"><span className="text-label text-foreground">Vehicle</span><p className="min-h-10 rounded-control border border-input bg-background-app px-[14px] py-2 text-body text-secondary">{record.vehicleRegistration}</p></div></> : <div className="flex flex-col gap-2"><label htmlFor="maintenance-vehicleId" className="text-label text-foreground">Vehicle</label><Select id="maintenance-vehicleId" name="vehicleId" required disabled={pending} invalid={Boolean(error("vehicleId"))} defaultValue="" className="min-h-11 md:min-h-10" focusSurface="card"><option value="" disabled>Select a Vehicle</option>{vehicles.map((vehicle) => <option key={vehicle.id} value={vehicle.id}>{vehicle.registration}</option>)}</Select>{error("vehicleId") ? <p className="text-small text-danger">{error("vehicleId")}</p> : null}</div>}
    <div className="grid gap-4 md:grid-cols-2">
      <Field name="serviceType" label="Service type" value={record?.serviceType ?? ""} required error={error("serviceType")} pending={pending} />
      <Field name="serviceDate" label="Service date" type="date" value={record?.serviceDate ?? ""} required error={error("serviceDate")} pending={pending} />
      <Field name="mileageAtService" label="Mileage at service (km)" type="number" value={record?.mileageAtService ?? ""} required min={0} step={1} error={error("mileageAtService")} pending={pending} />
      <Field name="workshop" label="Workshop" value={record?.workshop ?? ""} error={error("workshop")} pending={pending} />
      <Field name="cost" label="Cost (EUR)" type="number" value={record?.cost ?? ""} min={0} step={0.01} error={error("cost")} pending={pending} />
      <Field name="nextServiceDate" label="Next service date" type="date" value={record?.nextServiceDate ?? ""} error={error("nextServiceDate")} pending={pending} />
      <Field name="nextServiceMileage" label="Next service mileage (km)" type="number" value={record?.nextServiceMileage ?? ""} min={0} step={1} error={error("nextServiceMileage")} pending={pending} />
    </div>
    <div className="flex flex-col gap-2"><label htmlFor="maintenance-notes" className="text-label text-foreground">Notes</label><Textarea id="maintenance-notes" name="notes" defaultValue={record?.notes ?? ""} disabled={pending} invalid={Boolean(error("notes"))} aria-describedby={error("notes") ? "maintenance-notes-error" : undefined} focusSurface="card" />{error("notes") ? <p id="maintenance-notes-error" className="text-small text-danger">{error("notes")}</p> : null}</div>
    {state.status !== "validation" && state.message ? <p role="alert" className="text-small text-danger">{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}
    <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending} focusSurface="card" onClick={() => router.push("/operations/maintenance")}>Cancel</Button><Button type="submit" className="min-h-11 w-full sm:w-auto" loading={pending} disabled={pending} focusSurface="card">{record ? "Save changes" : "Create maintenance record"}</Button></div>
  </form>;
}
