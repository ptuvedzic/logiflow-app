"use client";

import { useActionState, useState } from "react";
import { LogOut } from "lucide-react";

import {
  logoutAction,
  type LogoutActionState,
} from "@/app/(auth)/logout/actions";
import { Button, type ButtonProps } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

const INITIAL_STATE: LogoutActionState = {
  status: "idle",
  message: null,
  correlationId: null,
};

export type LogoutControlProps = {
  className?: string;
  focusSurface?: ButtonProps["focusSurface"];
};

export function LogoutControl({
  className,
  focusSurface = "card",
}: LogoutControlProps) {
  const [open, setOpen] = useState(false);
  const [state, formAction, pending] = useActionState(
    logoutAction,
    INITIAL_STATE,
  );

  function handleOpenChange(nextOpen: boolean) {
    if (!pending) {
      setOpen(nextOpen);
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogTrigger asChild>
        <Button
          className={className}
          focusSurface={focusSurface}
          leftIcon={LogOut}
          variant="ghost"
        >
          Log out
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form action={formAction} className="flex flex-col gap-4">
          <DialogHeader>
            <DialogTitle>Log out?</DialogTitle>
            <DialogDescription>
              You will need to sign in again to continue.
            </DialogDescription>
          </DialogHeader>

          {state.status === "infrastructure" ? (
            <p role="alert" aria-live="polite" className="text-small text-danger">
              {state.message}
            </p>
          ) : null}

          <DialogFooter>
            <DialogClose asChild>
              <Button
                type="button"
                disabled={pending}
                focusSurface="card"
                variant="outline"
              >
                Cancel
              </Button>
            </DialogClose>
            <Button
              type="submit"
              disabled={pending}
              focusSurface="card"
              loading={pending}
              variant="destructive"
            >
              Log out
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
