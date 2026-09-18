"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { createShipmentAction, type ShipmentActionState } from "@/app/(operations)/operations/shipments/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const INITIAL_STATE: ShipmentActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
const DESTINATIONS = { unauthenticated: "/login", inactive_profile: "/account-inactive", missing_profile: "/account-error", forbidden: "/forbidden" } as const;

export function ShipmentForm({ clients }: Readonly<{ clients: readonly { id: string; companyName: string }[] }>) {
  const [state, action, pending] = useActionState(createShipmentAction, INITIAL_STATE);
  const router = useRouter();
  useEffect(() => { if (state.status in DESTINATIONS) router.replace(DESTINATIONS[state.status as keyof typeof DESTINATIONS]); }, [state.status, router]);
  const clientError = state.fieldErrors.clientId?.[0];
  const fields = [["pickupAddress", "Pickup address", "text"], ["deliveryAddress", "Delivery address", "text"], ["pickupAt", "Pickup date and time", "datetime-local"], ["expectedDeliveryAt", "Expected delivery date and time", "datetime-local"], ["cargoType", "Cargo type", "text"], ["price", "Price", "number"]] as const;
  return <form action={action} className="flex flex-col gap-4" noValidate>
    <div className="flex flex-col gap-2"><label htmlFor="shipment-client" className="text-label">Client</label><Select id="shipment-client" name="clientId" required disabled={pending} invalid={Boolean(clientError)} aria-describedby={clientError ? "shipment-client-error" : undefined} className="min-h-11" focusSurface="card"><option value="">Select Client</option>{clients.map((client) => <option key={client.id} value={client.id}>{client.companyName}</option>)}</Select>{clientError ? <p id="shipment-client-error" className="text-small text-danger">{clientError}</p> : null}</div>
    <div className="grid gap-4 md:grid-cols-2">{fields.map(([name, label, type]) => { const error = state.fieldErrors[name]?.[0]; return <div key={name} className="flex flex-col gap-2"><label htmlFor={`shipment-${name}`} className="text-label">{label}</label><Input id={`shipment-${name}`} name={name} type={type} required min={name === "price" ? 0 : undefined} step={name === "price" ? "0.01" : undefined} disabled={pending} invalid={Boolean(error)} aria-describedby={error ? `shipment-${name}-error` : undefined} className="min-h-11" focusSurface="card" />{error ? <p id={`shipment-${name}-error`} className="text-small text-danger">{error}</p> : null}</div>; })}</div>
    {state.message && state.status !== "validation" ? <p role="alert" aria-live="polite" className="text-small text-danger">{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}
    <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" onClick={() => router.push("/operations/shipments")} disabled={pending} focusSurface="card">Cancel</Button><Button type="submit" loading={pending} disabled={pending} focusSurface="card">Create shipment</Button></div>
  </form>;
}
