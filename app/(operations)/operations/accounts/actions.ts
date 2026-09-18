"use server";

import { randomUUID } from "node:crypto";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import {
  accountLifecycleSchema,
  administrativePasswordResetSchema,
} from "@/features/accounts/account-lifecycle-schema";
import { requireRole } from "@/lib/dal/auth";
import {
  changeManagedAccountLifecycle,
  resetManagedAccountPassword,
} from "@/lib/domain/account-lifecycle";

export type AccountActionState = Readonly<{
  status:
    | "idle"
    | "success"
    | "validation"
    | "weak_password"
    | "invalid_state"
    | "active_shipment"
    | "not_found"
    | "unauthenticated"
    | "missing_profile"
    | "inactive_profile"
    | "forbidden"
    | "infrastructure";
  message: string | null;
  fieldErrors: Readonly<{
    newPassword?: string[];
    confirmPassword?: string[];
  }>;
  correlationId: string | null;
}>;

const EMPTY_FIELD_ERRORS = Object.freeze({});

export async function resetManagedAccountPasswordAction(
  _previousState: AccountActionState,
  formData: FormData,
): Promise<AccountActionState> {
  void _previousState;
  const correlationId = randomUUID();
  const adminResult = await requireRole("admin");

  if (!adminResult.ok) {
    return { status: adminResult.error.category, message: adminResult.error.message, fieldErrors: EMPTY_FIELD_ERRORS, correlationId };
  }

  const parsed = administrativePasswordResetSchema.safeParse({
    username: formData.get("username"),
    newPassword: formData.get("newPassword"),
    confirmPassword: formData.get("confirmPassword"),
  });

  if (!parsed.success) {
    const errors = z.flattenError(parsed.error).fieldErrors;
    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: { newPassword: errors.newPassword, confirmPassword: errors.confirmPassword },
      correlationId,
    };
  }

  const result = await resetManagedAccountPassword(parsed.data);

  if (!result.ok) {
    if (result.error.category === "weak_password") {
      return {
        status: "weak_password",
        message: "Check the highlighted fields.",
        fieldErrors: { newPassword: [result.error.message] },
        correlationId,
      };
    }

    if (result.error.category === "infrastructure") {
      console.error({ operation: "accounts.password_reset", category: "infrastructure", actorProfileId: adminResult.data.id, correlationId });
    }

    return { status: result.error.category, message: result.error.message, fieldErrors: EMPTY_FIELD_ERRORS, correlationId };
  }

  revalidatePath("/operations/accounts");
  return { status: "success", message: "Password reset.", fieldErrors: EMPTY_FIELD_ERRORS, correlationId };
}

export async function changeManagedAccountLifecycleAction(
  _previousState: AccountActionState,
  formData: FormData,
): Promise<AccountActionState> {
  void _previousState;
  const correlationId = randomUUID();
  const adminResult = await requireRole("admin");

  if (!adminResult.ok) {
    return { status: adminResult.error.category, message: adminResult.error.message, fieldErrors: EMPTY_FIELD_ERRORS, correlationId };
  }

  const parsed = accountLifecycleSchema.safeParse({
    username: formData.get("username"),
    operation: formData.get("operation"),
  });

  if (!parsed.success) {
    return { status: "validation", message: "Account unavailable.", fieldErrors: EMPTY_FIELD_ERRORS, correlationId };
  }

  const result = await changeManagedAccountLifecycle(parsed.data);

  if (!result.ok) {
    if (result.error.category === "infrastructure") {
      console.error({ operation: `accounts.${parsed.data.operation}`, category: "infrastructure", actorProfileId: adminResult.data.id, correlationId });
    }

    return { status: result.error.category, message: result.error.message, fieldErrors: EMPTY_FIELD_ERRORS, correlationId };
  }

  revalidatePath("/operations/accounts");
  return {
    status: "success",
    message: parsed.data.operation === "deactivate" ? "Account deactivated." : "Account reactivated.",
    fieldErrors: EMPTY_FIELD_ERRORS,
    correlationId,
  };
}
