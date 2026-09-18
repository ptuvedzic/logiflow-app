import "server-only";

import { randomBytes, randomUUID } from "node:crypto";

import type { AuthError, SupabaseClient } from "@supabase/supabase-js";

import type { AccountProvisioningInput } from "@/features/accounts/account-schema";
import { deriveInternalAuthIdentifier } from "@/lib/auth/internal-identifier";
import { createAccountApplicationState } from "@/lib/dal/accounts";
import { createAdminClient } from "@/lib/supabase/admin";
import { createAuthVerifierClient } from "@/lib/supabase/auth-verifier";
import type { Database } from "@/types/database.generated";

export type AccountProvisioningResult =
  | { ok: true }
  | {
      ok: false;
      error:
        | { category: "username_conflict"; message: "Username is already in use." }
        | { category: "weak_password"; message: string }
        | { category: "infrastructure"; message: "Unable to create the account right now." };
    };

function isUsernameConflict(error: AuthError): boolean {
  return (
    error.code === "email_exists" ||
    error.code === "user_already_exists"
  );
}

function isPasswordPolicyFailure(error: AuthError): boolean {
  return error.code === "weak_password";
}

type InitialPasswordResult =
  | { status: "success" }
  | { status: "weak_password" }
  | { status: "infrastructure" };

async function applyInitialPassword({
  authUserId,
  identifier,
  initialPassword,
  temporaryPassword,
}: Readonly<{
  authUserId: string;
  identifier: string;
  initialPassword: string;
  temporaryPassword: string;
}>): Promise<InitialPasswordResult> {
  const verifier = createAuthVerifierClient();

  try {
    const signInResult = await verifier.auth.signInWithPassword({
      email: identifier,
      password: temporaryPassword,
    });

    if (
      signInResult.error ||
      !signInResult.data.session ||
      signInResult.data.user?.id !== authUserId
    ) {
      return { status: "infrastructure" };
    }

    const updateResult = await verifier.auth.updateUser({
      password: initialPassword,
    });

    if (updateResult.error) {
      return isPasswordPolicyFailure(updateResult.error)
        ? { status: "weak_password" }
        : { status: "infrastructure" };
    }

    return { status: "success" };
  } catch {
    return { status: "infrastructure" };
  } finally {
    try {
      await verifier.auth.signOut({ scope: "local" });
    } catch {
      // The verifier is non-persistent and never leaves this server-only scope.
    }
  }
}

async function compensateAuthUser(
  adminClient: SupabaseClient<Database>,
  authUserId: string,
  correlationId: string,
): Promise<boolean> {
  try {
    const compensationResult = await adminClient.auth.admin.deleteUser(authUserId);

    if (!compensationResult.error) {
      return true;
    }
  } catch {
    // Log only the same minimum reconciliation metadata as a returned failure.
  }

  console.error({
    operation: "accounts.provision.compensation",
    category: "infrastructure",
    authUserId,
    correlationId,
  });

  return false;
}

export async function provisionAccount(
  input: AccountProvisioningInput,
  correlationId: string,
): Promise<AccountProvisioningResult> {
  const adminClient = createAdminClient();
  let identifierResult: Awaited<
    ReturnType<typeof deriveInternalAuthIdentifier>
  >;

  try {
    identifierResult = await deriveInternalAuthIdentifier(
      adminClient,
      input.username,
    );
  } catch {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  if (!identifierResult.ok) {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  const temporaryPassword = `${randomBytes(48).toString("base64url")}Aa1!`;
  let authResult: Awaited<
    ReturnType<typeof adminClient.auth.admin.createUser>
  >;

  try {
    authResult = await adminClient.auth.admin.createUser({
      email: identifierResult.identifier,
      password: temporaryPassword,
      email_confirm: true,
    });
  } catch {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  if (authResult.error) {
    if (isPasswordPolicyFailure(authResult.error)) {
      return {
        ok: false,
        error: {
          category: "weak_password",
          message: "The password does not meet the configured password policy.",
        },
      };
    }

    if (isUsernameConflict(authResult.error)) {
      return {
        ok: false,
        error: { category: "username_conflict", message: "Username is already in use." },
      };
    }

    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  const authUser = authResult.data.user;

  if (!authUser) {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  const passwordResult = await applyInitialPassword({
    authUserId: authUser.id,
    identifier: identifierResult.identifier,
    initialPassword: input.initialPassword,
    temporaryPassword,
  });

  if (passwordResult.status !== "success") {
    const compensated = await compensateAuthUser(
      adminClient,
      authUser.id,
      correlationId,
    );

    if (!compensated) {
      return {
        ok: false,
        error: { category: "infrastructure", message: "Unable to create the account right now." },
      };
    }

    return passwordResult.status === "weak_password"
      ? {
          ok: false,
          error: {
            category: "weak_password",
            message: "The password does not meet the configured password policy.",
          },
        }
      : {
          ok: false,
          error: { category: "infrastructure", message: "Unable to create the account right now." },
        };
  }

  let applicationResult: Awaited<
    ReturnType<typeof createAccountApplicationState>
  >;

  try {
    applicationResult = await createAccountApplicationState(adminClient, {
      ...input,
      authUserId: authUser.id,
      driverId: input.role === "driver" ? randomUUID() : null,
    });
  } catch {
    await compensateAuthUser(adminClient, authUser.id, correlationId);

    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  if (!applicationResult.error) {
    return { ok: true };
  }

  const compensated = await compensateAuthUser(
    adminClient,
    authUser.id,
    correlationId,
  );

  if (!compensated) {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to create the account right now." },
    };
  }

  if (applicationResult.error.code === "23505") {
    return {
      ok: false,
      error: { category: "username_conflict", message: "Username is already in use." },
    };
  }

  return {
    ok: false,
    error: { category: "infrastructure", message: "Unable to create the account right now." },
  };
}
