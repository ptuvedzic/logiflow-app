"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { editDriverPhoneAction, type DriverActionState } from "@/app/(operations)/operations/drivers/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { StatusBadge } from "@/components/ui/status-badge";
import type { DriverRecord } from "@/lib/dal/drivers";

const INITIAL_STATE: DriverActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
const DESTINATIONS = { unauthenticated: "/login", inactive_profile: "/account-inactive", missing_profile: "/account-error", forbidden: "/forbidden" } as const;

export function DriverForm({ driver }: Readonly<{ driver: DriverRecord }>) {
  const router = useRouter();
  const [state, action, pending] = useActionState(editDriverPhoneAction, INITIAL_STATE);
  useEffect(() => { if (state.status in DESTINATIONS) router.replace(DESTINATIONS[state.status as keyof typeof DESTINATIONS]); }, [router, state.status]);
  const error = state.fieldErrors.phone?.[0];
  const generalMessage = state.status === "validation" ? null : state.message;
  return <form action={action} className="flex flex-col gap-4" noValidate>
    <input type="hidden" name="driverId" value={driver.id} /><input type="hidden" name="expectedUpdatedAt" value={driver.updatedAt} />
    <dl className="grid gap-4 md:grid-cols-2"><div><dt className="text-caption text-muted">Full name</dt><dd className="text-body-medium text-foreground">{driver.fullName}</dd></div><div><dt className="text-caption text-muted">Username</dt><dd className="text-body-medium text-foreground">{driver.username}</dd></div><div><dt className="text-caption text-muted">Account status</dt><dd className="mt-1"><StatusBadge domain="account" status={driver.accountActive ? "active" : "inactive"} /></dd></div><div><dt className="text-caption text-muted">Driver status</dt><dd className="mt-1"><StatusBadge domain="driver" status={driver.status} /></dd></div></dl>
    <div className="flex max-w-md flex-col gap-2"><label className="text-label text-foreground" htmlFor="driver-phone">Phone</label><Input id="driver-phone" name="phone" type="tel" defaultValue={driver.phone ?? ""} maxLength={32} disabled={pending} invalid={Boolean(error)} aria-describedby={error ? "driver-phone-error" : "driver-phone-help"} className="min-h-11 md:min-h-10" focusSurface="card" /><p id="driver-phone-help" className="text-caption text-muted">Optional, up to 32 characters.</p>{error ? <p id="driver-phone-error" className="text-small text-danger">{error}</p> : null}</div>
    {generalMessage ? <div><p role="alert" aria-live="assertive" className="text-small text-danger">{generalMessage}</p>{state.status === "infrastructure" && state.correlationId ? <p className="text-caption text-muted">Reference: {state.correlationId}</p> : null}</div> : null}
    <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending} focusSurface="card" onClick={() => router.push("/operations/drivers")}>Cancel</Button><Button type="submit" className="min-h-11 w-full sm:w-auto" loading={pending} disabled={pending} focusSurface="card">Save changes</Button></div>
  </form>;
}
