"use server";

import { randomUUID } from "node:crypto";

import { z } from "zod";

import { accountProvisioningSchema } from "@/features/accounts/account-schema";
import { requireRole } from "@/lib/dal/auth";
import { provisionAccount } from "@/lib/domain/account-provisioning";

type AccountFieldErrors = Readonly<{
  fullName?: string[];
  username?: string[];
  initialPassword?: string[];
  role?: string[];
}>;

export type AccountProvisioningActionState =
  | {
      status: "idle";
      message: null;
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: null;
    }
  | {
      status: "success";
      message: "Account created.";
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: string;
    }
  | {
      status: "validation" | "username_conflict" | "weak_password";
      message: string;
      fieldErrors: AccountFieldErrors;
      correlationId: string;
    }
  | {
      status:
        | "unauthenticated"
        | "inactive_profile"
        | "missing_profile"
        | "forbidden"
        | "infrastructure";
      message: string;
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: string;
    };

const EMPTY_FIELD_ERRORS = Object.freeze({});

export async function provisionAccountAction(
  _previousState: AccountProvisioningActionState,
  formData: FormData,
): Promise<AccountProvisioningActionState> {
  void _previousState;
  const correlationId = randomUUID();
  const profileResult = await requireRole("admin");

  if (!profileResult.ok) {
    return {
      status: profileResult.error.category,
      message: profileResult.error.message,
      fieldErrors: EMPTY_FIELD_ERRORS,
      correlationId,
    };
  }

  const validationResult = accountProvisioningSchema.safeParse({
    fullName: formData.get("fullName"),
    username: formData.get("username"),
    initialPassword: formData.get("initialPassword"),
    role: formData.get("role"),
  });

  if (!validationResult.success) {
    const fieldErrors = z.flattenError(validationResult.error).fieldErrors;

    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: {
        fullName: fieldErrors.fullName,
        username: fieldErrors.username,
        initialPassword: fieldErrors.initialPassword,
        role: fieldErrors.role,
      },
      correlationId,
    };
  }

  const result = await provisionAccount(validationResult.data, correlationId);

  if (result.ok) {
    return {
      status: "success",
      message: "Account created.",
      fieldErrors: EMPTY_FIELD_ERRORS,
      correlationId,
    };
  }

  if (result.error.category === "username_conflict") {
    return {
      status: "username_conflict",
      message: "Check the highlighted fields.",
      fieldErrors: { username: [result.error.message] },
      correlationId,
    };
  }

  if (result.error.category === "weak_password") {
    return {
      status: "weak_password",
      message: "Check the highlighted fields.",
      fieldErrors: { initialPassword: [result.error.message] },
      correlationId,
    };
  }

  console.error({
    operation: "accounts.provision",
    category: "infrastructure",
    actorProfileId: profileResult.data.id,
    correlationId,
  });

  return {
    status: "infrastructure",
    message: "Unable to create the account right now. Try again later.",
    fieldErrors: EMPTY_FIELD_ERRORS,
    correlationId,
  };
}
