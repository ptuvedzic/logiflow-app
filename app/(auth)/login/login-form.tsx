"use client";

import { useActionState } from "react";

import { loginAction, type LoginActionState } from "@/app/(auth)/login/actions";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const INITIAL_STATE: LoginActionState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  correlationId: null,
};

export function LoginForm() {
  const [state, formAction, pending] = useActionState(
    loginAction,
    INITIAL_STATE,
  );
  const usernameError = state.fieldErrors.username?.[0];
  const passwordError = state.fieldErrors.password?.[0];

  return (
    <form action={formAction} className="flex flex-col gap-4" noValidate>
      <div className="flex flex-col gap-2 text-left">
        <label className="text-label text-foreground" htmlFor="username">
          Username
        </label>
        <Input
          id="username"
          name="username"
          type="text"
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

      <div className="flex flex-col gap-2 text-left">
        <label className="text-label text-foreground" htmlFor="password">
          Password
        </label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          disabled={pending}
          invalid={Boolean(passwordError)}
          aria-describedby={passwordError ? "password-error" : undefined}
          focusSurface="card"
        />
        {passwordError ? (
          <p id="password-error" className="text-small text-danger">
            {passwordError}
          </p>
        ) : null}
      </div>

      {state.message ? (
        <p
          role="alert"
          aria-live="polite"
          className="text-left text-small text-danger"
        >
          {state.message}
        </p>
      ) : null}

      <Button
        type="submit"
        className="w-full"
        loading={pending}
        disabled={pending}
        focusSurface="card"
      >
        Sign in
      </Button>
    </form>
  );
}
