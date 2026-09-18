"use client";

import { useActionState, useEffect } from "react";
import { useRouter } from "next/navigation";

import { createClientAction, editClientAction, type ClientActionState } from "@/app/(operations)/operations/clients/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import type { ClientRecord } from "@/lib/dal/clients";

const INITIAL_STATE: ClientActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
const DESTINATIONS = { unauthenticated: "/login", inactive_profile: "/account-inactive", missing_profile: "/account-error", forbidden: "/forbidden" } as const;

export function ClientForm({ client }: Readonly<{ client?: ClientRecord }>) {
  const router = useRouter();
  const [state, action, pending] = useActionState(client ? editClientAction : createClientAction, INITIAL_STATE);
  useEffect(() => { if (state.status in DESTINATIONS) router.replace(DESTINATIONS[state.status as keyof typeof DESTINATIONS]); }, [router, state.status]);
  const fields = [
    ["companyName", "Company name", client?.companyName ?? "", true, "text"],
    ["contactPerson", "Contact person", client?.contactPerson ?? "", false, "text"],
    ["phone", "Phone", client?.phone ?? "", false, "tel"],
    ["email", "Email", client?.email ?? "", false, "email"],
  ] as const;
  const generalMessage = state.status === "validation" ? null : state.message;
  return (
    <form action={action} className="flex flex-col gap-4" noValidate>
      {client ? <><input type="hidden" name="clientId" value={client.id} /><input type="hidden" name="expectedUpdatedAt" value={client.updatedAt} /></> : null}
      <div className="grid gap-4 md:grid-cols-2">
        {fields.map(([name, label, value, required, type]) => {
          const error = state.fieldErrors[name]?.[0];
          return <div key={name} className="flex flex-col gap-2"><label className="text-label text-foreground" htmlFor={`client-${name}`}>{label}</label><Input id={`client-${name}`} name={name} type={type} defaultValue={value} required={required} disabled={pending} invalid={Boolean(error)} aria-describedby={error ? `client-${name}-error` : undefined} className="min-h-11 md:min-h-10" focusSurface="card" />{error ? <p id={`client-${name}-error`} className="text-small text-danger">{error}</p> : null}</div>;
        })}
        <div className="flex flex-col gap-2 md:col-span-2"><label className="text-label text-foreground" htmlFor="client-address">Address</label><Input id="client-address" name="address" defaultValue={client?.address ?? ""} disabled={pending} className="min-h-11 md:min-h-10" focusSurface="card" /></div>
        <div className="flex flex-col gap-2 md:col-span-2"><label className="text-label text-foreground" htmlFor="client-notes">Notes</label><Textarea id="client-notes" name="notes" defaultValue={client?.notes ?? ""} disabled={pending} focusSurface="card" /></div>
      </div>
      {generalMessage ? <div><p role="alert" aria-live="polite" className="text-small text-danger">{generalMessage}</p>{state.status === "infrastructure" && state.correlationId ? <p className="text-caption text-muted">Reference: {state.correlationId}</p> : null}</div> : null}
      <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" className="min-h-11 w-full sm:w-auto" disabled={pending} focusSurface="card" onClick={() => router.push("/operations/clients")}>Cancel</Button><Button type="submit" className="min-h-11 w-full sm:w-auto" loading={pending} disabled={pending} focusSurface="card">{client ? "Save changes" : "Create client"}</Button></div>
    </form>
  );
}
