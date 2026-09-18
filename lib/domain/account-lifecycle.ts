import "server-only";

import type { AuthError } from "@supabase/supabase-js";

import type {
  AccountLifecycleInput,
  AdministrativePasswordResetInput,
} from "@/features/accounts/account-lifecycle-schema";
import {
  getManagedAccountTarget,
  setManagedAccountActiveState,
} from "@/lib/dal/accounts";
import { createAdminClient } from "@/lib/supabase/admin";

export type AccountLifecycleResult =
  | { ok: true }
  | {
      ok: false;
      error: {
        category:
          | "unauthenticated"
          | "missing_profile"
          | "inactive_profile"
          | "forbidden"
          | "not_found"
          | "invalid_state"
          | "active_shipment"
          | "weak_password"
          | "infrastructure";
        message: string;
      };
    };

function isWeakPassword(error: AuthError): boolean {
  return error.code === "weak_password";
}

export async function resetManagedAccountPassword(
  input: AdministrativePasswordResetInput,
): Promise<AccountLifecycleResult> {
  const targetResult = await getManagedAccountTarget(input.username);

  if (!targetResult.ok) {
    return targetResult;
  }

  if (!targetResult.data.isActive) {
    return {
      ok: false,
      error: { category: "invalid_state", message: "Reactivate the account before resetting its password." },
    };
  }

  const client = createAdminClient();

  try {
    const { error } = await client.auth.admin.updateUserById(targetResult.data.id, {
      password: input.newPassword,
    });

    if (!error) {
      return { ok: true };
    }

    if (isWeakPassword(error)) {
      return {
        ok: false,
        error: { category: "weak_password", message: "The password does not meet the configured password policy." },
      };
    }
  } catch {
    // Translate below without exposing the Auth response or credential input.
  }

  return {
    ok: false,
    error: { category: "infrastructure", message: "Unable to reset the password right now." },
  };
}

export async function changeManagedAccountLifecycle(
  input: AccountLifecycleInput,
): Promise<AccountLifecycleResult> {
  const requestedActive = input.operation === "reactivate";
  const targetResult = await getManagedAccountTarget(input.username);

  if (!targetResult.ok) {
    return targetResult;
  }

  if (targetResult.data.isActive === requestedActive) {
    return {
      ok: false,
      error: {
        category: "invalid_state",
        message: requestedActive ? "Account is already active." : "Account is already inactive.",
      },
    };
  }

  try {
    const result = await setManagedAccountActiveState(input.username, requestedActive);

    if (result.ok) {
      return { ok: true };
    }

    const commandError = result.error;

    if (commandError.category !== "database") {
      return { ok: false, error: commandError };
    }

    if (commandError.code === "P0001") {
      return {
        ok: false,
        error: { category: "active_shipment", message: "Resolve the Driver's active shipment before deactivating this account." },
      };
    }

    if (commandError.code === "P0002") {
      return {
        ok: false,
        error: { category: "not_found", message: "Managed account unavailable." },
      };
    }

    if (commandError.code === "22023") {
      return {
        ok: false,
        error: { category: "invalid_state", message: commandError.message },
      };
    }
  } catch {
    // Translate below without exposing database details.
  }

  return {
    ok: false,
    error: { category: "infrastructure", message: "Unable to update the account right now." },
  };
}
