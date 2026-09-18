"use server";

import { randomUUID } from "node:crypto";

import type { AuthError, SupabaseClient } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { z } from "zod";

import { deriveInternalAuthIdentifier } from "@/lib/auth/internal-identifier";
import {
  clearSuccessfulUsernameLimit,
  evaluateLoginAttempt,
  getTrustedLoginSource,
} from "@/lib/auth/login-rate-limit";
import { getRoleHome, type RoleHome } from "@/lib/auth/role-home";
import { requireProfileWithClient } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

const loginSchema = z.object({
  username: z
    .string({ error: "Enter your username." })
    .refine((value) => value.trim().length > 0, "Enter your username."),
  password: z.string({ error: "Enter your password." }).min(1, "Enter your password."),
});

type LoginFieldErrors = Readonly<{
  username?: string[];
  password?: string[];
}>;

export type LoginActionState =
  | {
      status: "idle";
      message: null;
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: null;
    }
  | {
      status: "validation";
      message: "Check the highlighted fields.";
      fieldErrors: LoginFieldErrors;
      correlationId: string;
    }
  | {
      status: "invalid_credentials";
      message: "Invalid username or password.";
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: string;
    }
  | {
      status: "rate_limited";
      message: "Too many sign-in attempts. Try again later.";
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: string;
    }
  | {
      status: "infrastructure";
      message: "Unable to sign in right now. Try again later.";
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: string;
    };

const EMPTY_FIELD_ERRORS = Object.freeze({});

function infrastructureState(correlationId: string): LoginActionState {
  return {
    status: "infrastructure",
    message: "Unable to sign in right now. Try again later.",
    fieldErrors: EMPTY_FIELD_ERRORS,
    correlationId,
  };
}

function logInfrastructureFailure(operation: string, correlationId: string) {
  console.error({
    operation,
    category: "infrastructure",
    correlationId,
  });
}

function isCredentialFailure(error: AuthError): boolean {
  return (
    typeof error.status === "number" &&
    error.status >= 400 &&
    error.status < 500 &&
    error.status !== 429
  );
}

async function clearNewSession(
  client: SupabaseClient<Database>,
  correlationId: string,
  operation: string,
): Promise<boolean> {
  try {
    const { error } = await client.auth.signOut({ scope: "local" });

    if (error) {
      logInfrastructureFailure(operation, correlationId);
      return false;
    }

    return true;
  } catch {
    logInfrastructureFailure(operation, correlationId);
    return false;
  }
}

export async function loginAction(
  _previousState: LoginActionState,
  formData: FormData,
): Promise<LoginActionState> {
  const correlationId = randomUUID();
  const validationResult = loginSchema.safeParse({
    username: formData.get("username"),
    password: formData.get("password"),
  });

  if (!validationResult.success) {
    const fieldErrors = z.flattenError(validationResult.error).fieldErrors;

    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: {
        username: fieldErrors.username,
        password: fieldErrors.password,
      },
      correlationId,
    };
  }

  const sourceResult = await getTrustedLoginSource();

  if (!sourceResult.ok) {
    return infrastructureState(correlationId);
  }

  let client: SupabaseClient<Database>;

  try {
    client = await createClient();
  } catch {
    logInfrastructureFailure("auth.login.create_client", correlationId);
    return infrastructureState(correlationId);
  }

  const identifierResult = await deriveInternalAuthIdentifier(
    client,
    validationResult.data.username,
  );

  if (!identifierResult.ok) {
    if (identifierResult.error.category === "invalid_username") {
      return {
        status: "validation",
        message: "Check the highlighted fields.",
        fieldErrors: { username: ["Enter a valid username."] },
        correlationId,
      };
    }

    return infrastructureState(correlationId);
  }

  const limiterResult = await evaluateLoginAttempt({
    sourceIdentity: sourceResult.sourceIdentity,
    credentialIdentity: identifierResult.credentialIdentity,
  });

  if (limiterResult.status === "blocked") {
    return {
      status: "rate_limited",
      message: "Too many sign-in attempts. Try again later.",
      fieldErrors: EMPTY_FIELD_ERRORS,
      correlationId,
    };
  }

  if (limiterResult.status === "infrastructure") {
    return infrastructureState(correlationId);
  }

  let signInResult;

  try {
    signInResult = await client.auth.signInWithPassword({
      email: identifierResult.identifier,
      password: validationResult.data.password,
    });
  } catch {
    logInfrastructureFailure("auth.login.sign_in", correlationId);
    return infrastructureState(correlationId);
  }

  if (signInResult.error) {
    if (isCredentialFailure(signInResult.error)) {
      return {
        status: "invalid_credentials",
        message: "Invalid username or password.",
        fieldErrors: EMPTY_FIELD_ERRORS,
        correlationId,
      };
    }

    logInfrastructureFailure("auth.login.sign_in", correlationId);
    return infrastructureState(correlationId);
  }

  if (!signInResult.data.session || !signInResult.data.user) {
    await clearNewSession(
      client,
      correlationId,
      "auth.login.invalid_auth_result_cleanup",
    );
    return infrastructureState(correlationId);
  }

  const profileResult = await requireProfileWithClient(client);
  let redirectTarget: RoleHome | "/account-error" | "/account-inactive";

  if (!profileResult.ok) {
    const cleanupSucceeded = await clearNewSession(
      client,
      correlationId,
      "auth.login.profile_failure_cleanup",
    );

    if (!cleanupSucceeded) {
      return infrastructureState(correlationId);
    }

    if (profileResult.error.category === "missing_profile") {
      redirectTarget = "/account-error";
    } else {
      if (profileResult.error.category === "infrastructure") {
        logInfrastructureFailure("auth.login.profile_validation", correlationId);
      }

      return infrastructureState(correlationId);
    }
  } else if (!profileResult.data.isActive) {
    const cleanupSucceeded = await clearNewSession(
      client,
      correlationId,
      "auth.login.inactive_profile_cleanup",
    );

    if (!cleanupSucceeded) {
      return infrastructureState(correlationId);
    }

    redirectTarget = "/account-inactive";
  } else {
    redirectTarget = getRoleHome(profileResult.data.role);

    const cleanupResult = await clearSuccessfulUsernameLimit({
      credentialIdentity: identifierResult.credentialIdentity,
    });

    if (cleanupResult.status === "infrastructure") {
      logInfrastructureFailure(
        "auth.login.username_limiter_cleanup",
        correlationId,
      );
    }
  }

  redirect(redirectTarget);
}
