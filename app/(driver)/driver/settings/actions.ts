"use server";

import { randomUUID } from "node:crypto";

import { z } from "zod";

import { changeDriverPassword } from "@/lib/auth/driver-password";

const passwordSchema = z
  .object({
    currentPassword: z.string().min(1, "Enter your current password."),
    newPassword: z.string().min(1, "Enter a new password."),
    confirmNewPassword: z.string().min(1, "Confirm your new password."),
  })
  .superRefine((value, context) => {
    if (value.newPassword !== value.confirmNewPassword) {
      context.addIssue({
        code: "custom",
        path: ["confirmNewPassword"],
        message: "New passwords do not match.",
      });
    }
  });

type PasswordFieldErrors = Readonly<{
  currentPassword?: string[];
  newPassword?: string[];
  confirmNewPassword?: string[];
}>;

export type DriverPasswordActionState =
  | {
      status: "idle";
      message: null;
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: null;
    }
  | {
      status: "success";
      message: "Your password has been changed.";
      fieldErrors: Readonly<Record<string, never>>;
      correlationId: string;
    }
  | {
      status: "validation" | "weak_password";
      message: string;
      fieldErrors: PasswordFieldErrors;
      correlationId: string;
    }
  | {
      status:
        | "invalid_current_password"
        | "rate_limited"
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

export async function changeDriverPasswordAction(
  _previousState: DriverPasswordActionState,
  formData: FormData,
): Promise<DriverPasswordActionState> {
  void _previousState;
  const correlationId = randomUUID();
  const validationResult = passwordSchema.safeParse({
    currentPassword: formData.get("currentPassword"),
    newPassword: formData.get("newPassword"),
    confirmNewPassword: formData.get("confirmNewPassword"),
  });

  if (!validationResult.success) {
    const fieldErrors = z.flattenError(validationResult.error).fieldErrors;

    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: {
        currentPassword: fieldErrors.currentPassword,
        newPassword: fieldErrors.newPassword,
        confirmNewPassword: fieldErrors.confirmNewPassword,
      },
      correlationId,
    };
  }

  const result = await changeDriverPassword({
    currentPassword: validationResult.data.currentPassword,
    newPassword: validationResult.data.newPassword,
    correlationId,
  });

  if (result.ok) {
    return {
      status: "success",
      message: "Your password has been changed.",
      fieldErrors: EMPTY_FIELD_ERRORS,
      correlationId,
    };
  }

  if (result.error.category === "infrastructure") {
    console.error({
      operation: "driver.settings.password_change",
      category: "infrastructure",
      correlationId,
    });
  }

  if (result.error.category === "weak_password") {
    return {
      status: "weak_password",
      message: "Check the highlighted fields.",
      fieldErrors: { newPassword: [result.error.message] },
      correlationId,
    };
  }

  return {
    status: result.error.category,
    message:
      result.error.category === "infrastructure"
        ? "Unable to change your password right now. Try again later."
        : result.error.message,
    fieldErrors: EMPTY_FIELD_ERRORS,
    correlationId,
  };
}
