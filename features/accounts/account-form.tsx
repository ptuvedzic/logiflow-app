"use client";

import { useActionState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";

import {
  provisionAccountAction,
  type AccountProvisioningActionState,
} from "@/app/(operations)/operations/accounts/new/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";

const INITIAL_STATE: AccountProvisioningActionState = {
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

export function AccountForm() {
  const router = useRouter();
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState(
    provisionAccountAction,
    INITIAL_STATE,
  );

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

  const fullNameError = state.fieldErrors.fullName?.[0];
  const usernameError = state.fieldErrors.username?.[0];
  const initialPasswordError = state.fieldErrors.initialPassword?.[0];
  const roleError = state.fieldErrors.role?.[0];
  const formMessage =
    state.status === "validation" ||
    state.status === "username_conflict" ||
    state.status === "weak_password"
      ? null
      : state.message;

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-4" noValidate>
      <div className="grid gap-4 md:grid-cols-2">
        <div className="flex flex-col gap-2">
          <label className="text-label text-foreground" htmlFor="full-name">
            Full name
          </label>
          <Input
            id="full-name"
            name="fullName"
            autoComplete="name"
            required
            disabled={pending}
            invalid={Boolean(fullNameError)}
            aria-describedby={fullNameError ? "full-name-error" : undefined}
            focusSurface="card"
          />
          {fullNameError ? (
            <p id="full-name-error" className="text-small text-danger">
              {fullNameError}
            </p>
          ) : null}
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-label text-foreground" htmlFor="username">
            Username
          </label>
          <Input
            id="username"
            name="username"
            autoComplete="username"
            required
            disabled={pending}
            invalid={Boolean(usernameError)}
            aria-describedby={usernameError ? "username-error" : undefined}
            focusSurface="card"
          />
          {usernameError ? (
            <p id="username-error" className="text-small text-danger">
              {usernameError}
            </p>
          ) : null}
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-label text-foreground" htmlFor="initial-password">
            Initial password
          </label>
          <Input
            id="initial-password"
            name="initialPassword"
            type="password"
            autoComplete="new-password"
            required
            disabled={pending}
            invalid={Boolean(initialPasswordError)}
            aria-describedby={
              initialPasswordError ? "initial-password-error" : undefined
            }
            focusSurface="card"
          />
          {initialPasswordError ? (
            <p id="initial-password-error" className="text-small text-danger">
              {initialPasswordError}
            </p>
          ) : null}
        </div>

        <div className="flex flex-col gap-2">
          <label className="text-label text-foreground" htmlFor="role">
            Role
          </label>
          <Select
            id="role"
            name="role"
            defaultValue=""
            required
            disabled={pending}
            invalid={Boolean(roleError)}
            aria-describedby={roleError ? "role-error" : undefined}
            focusSurface="card"
          >
            <option value="" disabled>
              Select a role
            </option>
            <option value="dispatcher">Dispatcher</option>
            <option value="driver">Driver</option>
          </Select>
          {roleError ? (
            <p id="role-error" className="text-small text-danger">
              {roleError}
            </p>
          ) : null}
        </div>
      </div>

      {formMessage ? (
        <div>
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
          {state.status === "infrastructure" && state.correlationId ? (
            <p className="text-caption text-muted">
              Reference: {state.correlationId}
            </p>
          ) : null}
        </div>
      ) : null}

      <div className="flex flex-col-reverse gap-2 sm:flex-row">
        <Button
          type="button"
          variant="outline"
          className="min-h-11 w-full sm:w-auto"
          disabled={pending}
          focusSurface="card"
          onClick={() => router.push("/operations/accounts")}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          className="min-h-11 w-full sm:w-auto"
          loading={pending}
          disabled={pending}
          focusSurface="card"
        >
          Create account
        </Button>
      </div>
    </form>
  );
}
