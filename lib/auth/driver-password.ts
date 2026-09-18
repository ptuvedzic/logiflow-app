import "server-only";

import type { AuthError } from "@supabase/supabase-js";

import { deriveInternalAuthIdentifier } from "@/lib/auth/internal-identifier";
import { getTrustedLoginSource } from "@/lib/auth/login-rate-limit";
import {
  checkPasswordChangeLimit,
  clearPasswordChangeUserLimit,
  recordPasswordChangeFailure,
} from "@/lib/auth/password-change-rate-limit";
import type { AuthBoundaryError } from "@/lib/dal/auth";
import { requireDriverAccountWithClient } from "@/lib/dal/profile";
import { createAuthVerifierClient } from "@/lib/supabase/auth-verifier";
import { createClient } from "@/lib/supabase/server";

export type DriverPasswordChangeError =
  | AuthBoundaryError
  | {
      category: "invalid_current_password";
      message: "Current password is incorrect.";
    }
  | {
      category: "weak_password";
      message: "New password does not meet the password requirements.";
    }
  | {
      category: "rate_limited";
      message: "Too many password change attempts. Try again later.";
    };

export type DriverPasswordChangeResult =
  | { ok: true }
  | { ok: false; error: DriverPasswordChangeError };

type CurrentPasswordVerificationResult =
  | { status: "verified"; userId: string }
  | { status: "invalid_credentials" }
  | { status: "rate_limited" }
  | { status: "infrastructure" };

const INFRASTRUCTURE_ERROR = {
  category: "infrastructure",
  message: "Unable to verify account access.",
} as const;

const RATE_LIMIT_ERROR = {
  category: "rate_limited",
  message: "Too many password change attempts. Try again later.",
} as const;

function isInvalidCredentials(error: AuthError) {
  return error.code === "invalid_credentials";
}

function isRateLimitError(error: AuthError) {
  return error.status === 429;
}

async function verifyCurrentPassword(
  identifier: string,
  currentPassword: string,
): Promise<CurrentPasswordVerificationResult> {
  try {
    const verifier = createAuthVerifierClient();
    const { data, error } = await verifier.auth.signInWithPassword({
      email: identifier,
      password: currentPassword,
    });

    if (error) {
      if (isInvalidCredentials(error)) {
        return { status: "invalid_credentials" };
      }

      return isRateLimitError(error)
        ? { status: "rate_limited" }
        : { status: "infrastructure" };
    }

    if (!data.user || !data.session) {
      return { status: "infrastructure" };
    }

    return { status: "verified", userId: data.user.id };
  } catch {
    return { status: "infrastructure" };
  }
}

async function clearUserLimitAfterSuccess(
  profileId: string,
  correlationId: string,
) {
  const firstAttempt = await clearPasswordChangeUserLimit(profileId);

  if (firstAttempt.status === "cleared") {
    return;
  }

  const retry = await clearPasswordChangeUserLimit(profileId);

  if (retry.status === "infrastructure") {
    console.error({
      operation: "driver.settings.password_change.limit_cleanup",
      category: "infrastructure",
      correlationId,
    });
  }
}

export async function changeDriverPassword({
  currentPassword,
  newPassword,
  correlationId,
}: Readonly<{
  currentPassword: string;
  newPassword: string;
  correlationId: string;
}>): Promise<DriverPasswordChangeResult> {
  let client;

  try {
    client = await createClient();
  } catch {
    return { ok: false, error: INFRASTRUCTURE_ERROR };
  }

  const accountResult = await requireDriverAccountWithClient(client);

  if (!accountResult.ok) {
    return accountResult;
  }

  const sourceResult = await getTrustedLoginSource();

  if (!sourceResult.ok) {
    return { ok: false, error: INFRASTRUCTURE_ERROR };
  }

  const limitIdentity = {
    profileId: accountResult.data.profileId,
    sourceIdentity: sourceResult.sourceIdentity,
  };
  const limitResult = await checkPasswordChangeLimit(limitIdentity);

  if (limitResult.status === "blocked") {
    return { ok: false, error: RATE_LIMIT_ERROR };
  }

  if (limitResult.status === "infrastructure") {
    return { ok: false, error: INFRASTRUCTURE_ERROR };
  }

  const identifierResult = await deriveInternalAuthIdentifier(
    client,
    accountResult.data.username,
  );

  if (!identifierResult.ok) {
    return { ok: false, error: INFRASTRUCTURE_ERROR };
  }

  const verificationResult = await verifyCurrentPassword(
    identifierResult.identifier,
    currentPassword,
  );

  if (verificationResult.status === "invalid_credentials") {
    const failureResult = await recordPasswordChangeFailure(limitIdentity);

    if (failureResult.status === "infrastructure") {
      return { ok: false, error: INFRASTRUCTURE_ERROR };
    }

    return {
      ok: false,
      error: {
        category: "invalid_current_password",
        message: "Current password is incorrect.",
      },
    };
  }

  if (verificationResult.status === "rate_limited") {
    return { ok: false, error: RATE_LIMIT_ERROR };
  }

  if (
    verificationResult.status === "infrastructure" ||
    verificationResult.userId !== accountResult.data.profileId
  ) {
    return { ok: false, error: INFRASTRUCTURE_ERROR };
  }

  let updateError: AuthError | null;

  try {
    const { error } = await client.auth.updateUser({ password: newPassword });
    updateError = error;
  } catch {
    return { ok: false, error: INFRASTRUCTURE_ERROR };
  }

  if (updateError) {
    if (updateError.code === "weak_password") {
      return {
        ok: false,
        error: {
          category: "weak_password",
          message: "New password does not meet the password requirements.",
        },
      };
    }

    return {
      ok: false,
      error: isRateLimitError(updateError)
        ? RATE_LIMIT_ERROR
        : INFRASTRUCTURE_ERROR,
    };
  }

  await clearUserLimitAfterSuccess(
    accountResult.data.profileId,
    correlationId,
  );

  return { ok: true };
}
