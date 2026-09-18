"use client";

import { startTransition, useActionState, useState } from "react";
import { useRouter } from "next/navigation";
import { Archive, CircleCheck, CirclePause, Ellipsis, Pencil, RotateCcw } from "lucide-react";

import { changeDriverStatusAction, type DriverActionState } from "@/app/(operations)/operations/drivers/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import type { DriverOperation } from "@/features/drivers/driver-schema";
import type { DriverListItem } from "@/lib/dal/drivers";

const INITIAL_STATE: DriverActionState = { status: "idle", message: null, fieldErrors: {}, correlationId: null };

export function DriverActions({ driver }: Readonly<{ driver: DriverListItem }>) {
  const [version, setVersion] = useState(0);
  return <DriverActionsInstance key={version} driver={driver} onFinished={() => setVersion((value) => value + 1)} />;
}

function DriverActionsInstance({ driver, onFinished }: Readonly<{ driver: DriverListItem; onFinished: () => void }>) {
  const router = useRouter();
  const [confirmation, setConfirmation] = useState<"archive" | "reactivate" | null>(null);
  const [state, dispatch, pending] = useActionState(changeDriverStatusAction, INITIAL_STATE);
  function submit(operation: DriverOperation) { const data = new FormData(); data.set("driverId", driver.id); data.set("operation", operation); startTransition(() => dispatch(data)); }
  const canEdit = driver.accountActive && driver.status !== "inactive";
  return <div className="flex items-center justify-end gap-2">
    {state.message && confirmation === null ? <span className={state.status === "success" ? "text-caption text-success" : "text-caption text-danger"} role={state.status === "success" ? "status" : "alert"} aria-live={state.status === "success" ? "polite" : "assertive"}>{state.message}</span> : null}
    <DropdownMenu><DropdownMenuTrigger asChild><Button aria-label={`Actions for ${driver.fullName}`} variant="ghost" className="min-h-11 min-w-11 px-0 md:min-h-10 md:min-w-10" disabled={pending} focusSurface="card"><Ellipsis aria-hidden="true" size={20} strokeWidth={1.75} /></Button></DropdownMenuTrigger><DropdownMenuContent>
      {canEdit ? <DropdownMenuItem icon={Pencil} onSelect={() => router.push(`/operations/drivers/${driver.id}/edit`)}>Edit phone</DropdownMenuItem> : null}
      {driver.accountActive && driver.status === "available" ? <DropdownMenuItem icon={CirclePause} onSelect={() => submit("mark_off_duty")}>Mark off duty</DropdownMenuItem> : null}
      {driver.accountActive && driver.status === "off_duty" ? <DropdownMenuItem icon={CircleCheck} onSelect={() => submit("mark_available")}>Mark available</DropdownMenuItem> : null}
      {driver.accountActive && (driver.status === "available" || driver.status === "off_duty") ? <DropdownMenuItem icon={Archive} variant="destructive" onSelect={() => setConfirmation("archive")}>Archive driver</DropdownMenuItem> : null}
      {driver.accountActive && driver.status === "archived" ? <DropdownMenuItem icon={RotateCcw} onSelect={() => setConfirmation("reactivate")}>Reactivate driver</DropdownMenuItem> : null}
    </DropdownMenuContent></DropdownMenu>
    <Dialog open={confirmation !== null} onOpenChange={(open) => { if (!open) setConfirmation(null); }}><DialogContent><form action={dispatch} className="flex flex-col gap-4"><DialogHeader><DialogTitle>{confirmation === "archive" ? "Archive driver?" : "Reactivate driver?"}</DialogTitle><DialogDescription>{confirmation === "archive" ? "This Driver will be unavailable for future assignments. Their account and history will remain active." : "This Driver will become available for future assignments."}</DialogDescription></DialogHeader>
      <input type="hidden" name="driverId" value={driver.id} /><input type="hidden" name="operation" value={confirmation ?? "reactivate"} />
      {state.message ? <p role={state.status === "success" ? "status" : "alert"} aria-live={state.status === "success" ? "polite" : "assertive"} className={state.status === "success" ? "text-small text-success" : "text-small text-danger"}>{state.message}{state.status === "infrastructure" && state.correlationId ? ` Reference: ${state.correlationId}` : ""}</p> : null}
      <DialogFooter><DialogClose asChild><Button variant="outline" disabled={pending} focusSurface="card" onClick={state.status === "success" ? onFinished : undefined}>{state.status === "success" ? "Close" : "Cancel"}</Button></DialogClose>{state.status !== "success" ? <Button type="submit" variant={confirmation === "archive" ? "destructive" : "primary"} loading={pending} disabled={pending} focusSurface="card">{confirmation === "archive" ? "Archive driver" : "Reactivate driver"}</Button> : null}</DialogFooter>
    </form></DialogContent></Dialog>
  </div>;
}
