"use client";

import { useActionState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";

import {
  changeDriverPasswordAction,
  type DriverPasswordActionState,
} from "@/app/(driver)/driver/settings/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const INITIAL_STATE: DriverPasswordActionState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  correlationId: null,
};

const BOUNDARY_DESTINATIONS = {
  unauthenticated: "/login",
  inactive_profile: "/account-inactive",
  missing_profile: "/account-error",
  forbidden: "/forbidden",
} as const;

export function PasswordForm() {
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState(
    changeDriverPasswordAction,
    INITIAL_STATE,
  );
  const currentPasswordError = state.fieldErrors.currentPassword?.[0];
  const newPasswordError = state.fieldErrors.newPassword?.[0];
  const confirmNewPasswordError = state.fieldErrors.confirmNewPassword?.[0];

  useEffect(() => {
    if (state.status === "success") {
      formRef.current?.reset();
      return;
    }

    if (state.status in BOUNDARY_DESTINATIONS) {
      router.replace(
        BOUNDARY_DESTINATIONS[
          state.status as keyof typeof BOUNDARY_DESTINATIONS
        ],
      );
    }
  }, [router, state.status]);

  const formMessage =
    state.status === "validation" || state.status === "weak_password"
      ? null
      : state.message;

  return (
    <form
      ref={formRef}
      action={formAction}
      className="flex max-w-xl flex-col gap-4"
      noValidate
    >
      <div className="flex flex-col gap-2">
        <label className="text-label text-foreground" htmlFor="current-password">
          Current password
        </label>
        <Input
          id="current-password"
          name="currentPassword"
          type="password"
          autoComplete="current-password"
          required
          disabled={pending}
          invalid={Boolean(currentPasswordError)}
          aria-describedby={
            currentPasswordError ? "current-password-error" : undefined
          }
          focusSurface="card"
        />
        {currentPasswordError ? (
          <p id="current-password-error" className="text-small text-danger">
            {currentPasswordError}
          </p>
        ) : null}
      </div>

      <div className="flex flex-col gap-2">
        <label className="text-label text-foreground" htmlFor="new-password">
          New password
        </label>
        <Input
          id="new-password"
          name="newPassword"
          type="password"
          autoComplete="new-password"
          required
          disabled={pending}
          invalid={Boolean(newPasswordError)}
          aria-describedby={newPasswordError ? "new-password-error" : undefined}
          focusSurface="card"
        />
        {newPasswordError ? (
          <p id="new-password-error" className="text-small text-danger">
            {newPasswordError}
          </p>
        ) : null}
      </div>

      <div className="flex flex-col gap-2">
        <label
          className="text-label text-foreground"
          htmlFor="confirm-new-password"
        >
          Confirm new password
        </label>
        <Input
          id="confirm-new-password"
          name="confirmNewPassword"
          type="password"
          autoComplete="new-password"
          required
          disabled={pending}
          invalid={Boolean(confirmNewPasswordError)}
          aria-describedby={
            confirmNewPasswordError ? "confirm-new-password-error" : undefined
          }
          focusSurface="card"
        />
        {confirmNewPasswordError ? (
          <p id="confirm-new-password-error" className="text-small text-danger">
            {confirmNewPasswordError}
          </p>
        ) : null}
      </div>

      {formMessage ? (
        <p
          role={state.status === "success" ? "status" : "alert"}
          aria-live="polite"
          className={
            state.status === "success"
              ? "text-small text-success"
              : "text-small text-danger"
          }
        >
          {formMessage}
        </p>
      ) : null}

      <Button
        type="submit"
        className="min-h-11 w-full sm:w-auto sm:self-start"
        loading={pending}
        disabled={pending}
        focusSurface="card"
      >
        Change password
      </Button>
    </form>
  );
}
