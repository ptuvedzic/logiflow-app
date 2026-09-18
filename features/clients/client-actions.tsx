"use client";

import { useActionState, useState } from "react";
import { useRouter } from "next/navigation";
import { Archive, Ellipsis, Pencil, RotateCcw } from "lucide-react";

import { changeClientLifecycleAction, type ClientActionState } from "@/app/(operations)/operations/clients/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import type { ClientListItem } from "@/lib/dal/clients";

const INITIAL_STATE: ClientActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };
type Lifecycle = "archive" | "reactivate";

export function ClientActions({ client }: Readonly<{ client: ClientListItem }>) {
  const [version, setVersion] = useState(0);
  return <ClientActionsInstance key={version} client={client} onFinished={() => setVersion((value) => value + 1)} />;
}

function ClientActionsInstance({ client, onFinished }: Readonly<{ client: ClientListItem; onFinished: () => void }>) {
  const router = useRouter();
  const [operation, setOperation] = useState<Lifecycle | null>(null);
  const [state, action, pending] = useActionState(changeClientLifecycleAction, INITIAL_STATE);
  const effectiveOperation = operation ?? (client.status === "active" ? "archive" : "reactivate");
  return <>
    <DropdownMenu><DropdownMenuTrigger asChild><Button aria-label={`Actions for ${client.companyName}`} variant="ghost" className="min-h-11 min-w-11 px-0 md:min-h-10 md:min-w-10" focusSurface="card"><Ellipsis aria-hidden="true" size={20} strokeWidth={1.75} /></Button></DropdownMenuTrigger><DropdownMenuContent>
      <DropdownMenuItem icon={Pencil} onSelect={() => router.push(`/operations/clients/${client.id}/edit`)}>Edit</DropdownMenuItem>
      {client.status === "active" ? <DropdownMenuItem icon={Archive} variant="destructive" onSelect={() => setOperation("archive")}>Archive</DropdownMenuItem> : <DropdownMenuItem icon={RotateCcw} onSelect={() => setOperation("reactivate")}>Reactivate</DropdownMenuItem>}
    </DropdownMenuContent></DropdownMenu>
    <Dialog open={operation !== null} onOpenChange={(open) => setOperation(open ? effectiveOperation : null)}><DialogContent><form action={action} className="flex flex-col gap-4"><DialogHeader><DialogTitle>{effectiveOperation === "archive" ? "Archive client?" : "Reactivate client?"}</DialogTitle><DialogDescription>{effectiveOperation === "archive" ? "This client will be unavailable for new shipments. Historical records will remain available." : "This client will become eligible for future shipments."}</DialogDescription></DialogHeader>
      {state.status === "success" ? <p role="status" aria-live="polite" className="text-small text-success">{state.message}</p> : <><input type="hidden" name="clientId" value={client.id} /><input type="hidden" name="operation" value={effectiveOperation} />{state.message ? <p role="alert" aria-live="assertive" className="text-small text-danger">{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}</>}
      <DialogFooter><DialogClose asChild><Button variant="outline" disabled={pending} focusSurface="card" onClick={state.status === "success" ? onFinished : undefined}>{state.status === "success" ? "Close" : "Cancel"}</Button></DialogClose>{state.status !== "success" ? <Button type="submit" variant={effectiveOperation === "archive" ? "destructive" : "primary"} loading={pending} disabled={pending} focusSurface="card">{effectiveOperation === "archive" ? "Archive client" : "Reactivate client"}</Button> : null}</DialogFooter>
    </form></DialogContent></Dialog>
  </>;
}
