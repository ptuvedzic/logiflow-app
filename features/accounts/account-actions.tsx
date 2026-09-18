"use client";

import { useActionState, useState } from "react";
import { Ellipsis, KeyRound, Power, RotateCcw } from "lucide-react";

import {
  changeManagedAccountLifecycleAction,
  resetManagedAccountPasswordAction,
  type AccountActionState,
} from "@/app/(operations)/operations/accounts/actions";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Input } from "@/components/ui/input";
import type { ManagedAccount } from "@/lib/dal/accounts";

const INITIAL_STATE: AccountActionState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  correlationId: null,
};

type OpenDialog = "password" | "deactivate" | "reactivate" | null;

export function AccountActions({ account }: Readonly<{ account: ManagedAccount }>) {
  const [version, setVersion] = useState(0);

  return (
    <AccountActionsInstance
      key={version}
      account={account}
      onFinished={() => setVersion((current) => current + 1)}
    />
  );
}

function AccountActionsInstance({
  account,
  onFinished,
}: Readonly<{ account: ManagedAccount; onFinished: () => void }>) {
  const [openDialog, setOpenDialog] = useState<OpenDialog>(null);
  const [passwordState, passwordAction, passwordPending] = useActionState(
    resetManagedAccountPasswordAction,
    INITIAL_STATE,
  );
  const [lifecycleState, lifecycleAction, lifecyclePending] = useActionState(
    changeManagedAccountLifecycleAction,
    INITIAL_STATE,
  );

  const newPasswordError = passwordState.fieldErrors.newPassword?.[0];
  const confirmPasswordError = passwordState.fieldErrors.confirmPassword?.[0];
  const lifecycleOperation =
    openDialog === "deactivate" || openDialog === "reactivate"
      ? openDialog
      : account.status === "active"
        ? "deactivate"
        : "reactivate";

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            aria-label={`Actions for ${account.fullName}`}
            variant="ghost"
            size="medium"
            className="min-w-10 px-0"
            focusSurface="card"
          >
            <Ellipsis aria-hidden="true" size={20} strokeWidth={1.75} />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent>
          {account.status === "active" ? (
            <>
              <DropdownMenuItem icon={KeyRound} onSelect={() => setOpenDialog("password")}>
                Reset password
              </DropdownMenuItem>
              <DropdownMenuItem icon={Power} variant="destructive" onSelect={() => setOpenDialog("deactivate")}>
                Deactivate
              </DropdownMenuItem>
            </>
          ) : (
            <DropdownMenuItem icon={RotateCcw} onSelect={() => setOpenDialog("reactivate")}>
              Reactivate
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      <Dialog open={openDialog === "password"} onOpenChange={(open) => setOpenDialog(open ? "password" : null)}>
        <DialogContent>
          <form action={passwordAction} className="flex flex-col gap-4" noValidate>
            <DialogHeader>
              <DialogTitle>Reset password</DialogTitle>
              <DialogDescription>Set a new password for {account.fullName}. Supabase applies the configured password policy.</DialogDescription>
            </DialogHeader>
            {passwordState.status === "success" ? (
              <p role="status" aria-live="polite" className="text-small text-success">Password reset.</p>
            ) : <>
            <input type="hidden" name="username" value={account.username} />
            <div className="flex flex-col gap-2">
              <label className="text-label text-foreground" htmlFor={`new-password-${account.username}`}>New password</label>
              <Input id={`new-password-${account.username}`} name="newPassword" type="password" autoComplete="new-password" required disabled={passwordPending} invalid={Boolean(newPasswordError)} aria-describedby={newPasswordError ? `new-password-error-${account.username}` : undefined} focusSurface="card" />
              {newPasswordError ? <p id={`new-password-error-${account.username}`} className="text-small text-danger">{newPasswordError}</p> : null}
            </div>
            <div className="flex flex-col gap-2">
              <label className="text-label text-foreground" htmlFor={`confirm-password-${account.username}`}>Confirm new password</label>
              <Input id={`confirm-password-${account.username}`} name="confirmPassword" type="password" autoComplete="new-password" required disabled={passwordPending} invalid={Boolean(confirmPasswordError)} aria-describedby={confirmPasswordError ? `confirm-password-error-${account.username}` : undefined} focusSurface="card" />
              {confirmPasswordError ? <p id={`confirm-password-error-${account.username}`} className="text-small text-danger">{confirmPasswordError}</p> : null}
            </div>
            {passwordState.message && passwordState.status !== "validation" && passwordState.status !== "weak_password" ? (
              <p role="alert" className="text-small text-danger">{passwordState.message}{passwordState.status === "infrastructure" && passwordState.correlationId ? ` Reference: ${passwordState.correlationId}` : ""}</p>
            ) : null}
            </>}
            <DialogFooter>
              <DialogClose asChild><Button variant="outline" disabled={passwordPending} focusSurface="card" onClick={passwordState.status === "success" ? onFinished : undefined}>{passwordState.status === "success" ? "Close" : "Cancel"}</Button></DialogClose>
              {passwordState.status !== "success" ? <Button type="submit" loading={passwordPending} disabled={passwordPending} focusSurface="card">Reset password</Button> : null}
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>

      <Dialog open={openDialog === "deactivate" || openDialog === "reactivate"} onOpenChange={(open) => setOpenDialog(open ? lifecycleOperation : null)}>
        <DialogContent>
          <form action={lifecycleAction} className="flex flex-col gap-4">
            <DialogHeader>
              <DialogTitle>{lifecycleOperation === "deactivate" ? "Deactivate account" : "Reactivate account"}</DialogTitle>
              <DialogDescription>
                {lifecycleOperation === "deactivate"
                  ? `Deactivate ${account.fullName}? They will no longer be able to access LogiFlow.`
                  : `Reactivate ${account.fullName}? They can authenticate normally with their current password.`}
              </DialogDescription>
            </DialogHeader>
            {lifecycleState.status === "success" ? (
              <p role="status" aria-live="polite" className="text-small text-success">{lifecycleState.message}</p>
            ) : <>
            <input type="hidden" name="username" value={account.username} />
            <input type="hidden" name="operation" value={lifecycleOperation} />
            {lifecycleState.message ? (
              <p role="alert" className="text-small text-danger">{lifecycleState.message}{lifecycleState.status === "infrastructure" && lifecycleState.correlationId ? ` Reference: ${lifecycleState.correlationId}` : ""}</p>
            ) : null}
            </>}
            <DialogFooter>
              <DialogClose asChild><Button variant="outline" disabled={lifecyclePending} focusSurface="card" onClick={lifecycleState.status === "success" ? onFinished : undefined}>{lifecycleState.status === "success" ? "Close" : "Cancel"}</Button></DialogClose>
              {lifecycleState.status !== "success" ? <Button type="submit" variant={lifecycleOperation === "deactivate" ? "destructive" : "primary"} loading={lifecyclePending} disabled={lifecyclePending} focusSurface="card">
                {lifecycleOperation === "deactivate" ? "Deactivate" : "Reactivate"}
              </Button> : null}
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
