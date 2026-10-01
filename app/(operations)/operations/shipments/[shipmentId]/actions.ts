"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";

import { expenseCreateSchema, expenseEditSchema } from "@/features/expenses/expense-schema";
import { requireRole } from "@/lib/dal/auth";
import { createShipmentExpense, updateShipmentExpense } from "@/lib/dal/expenses";

export type ExpenseActionState = Readonly<{
  status: "idle" | "success" | "validation" | "not_found" | "conflict" | "business_rule" | "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure";
  message: string | null;
  fieldErrors: Readonly<Record<string, string[] | undefined>>;
  correlationId: string | null;
}>;

const EMPTY_ERRORS = Object.freeze({});

function failure(status: ExpenseActionState["status"], message: string, correlationId: string): ExpenseActionState {
  return { status, message, fieldErrors: EMPTY_ERRORS, correlationId };
}

function expenseValues(formData: FormData) {
  return {
    category: formData.get("category"),
    amount: formData.get("amount"),
    expenseDate: formData.get("expenseDate"),
    description: formData.get("description"),
  };
}

function logFailure(operation: string, actorProfileId: string, entityId: string | null, correlationId: string) {
  console.error({ operation, category: "infrastructure", actorProfileId, entityId, correlationId });
}

export async function createExpenseAction(_state: ExpenseActionState, formData: FormData): Promise<ExpenseActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin", "dispatcher");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);

  const parsed = expenseCreateSchema.safeParse({
    shipmentId: formData.get("shipmentId"),
    ...expenseValues(formData),
  });
  if (!parsed.success) {
    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
      correlationId,
    };
  }

  const result = await createShipmentExpense(parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure("expense.create", actor.data.id, parsed.data.shipmentId, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }

  revalidatePath(`/operations/shipments/${parsed.data.shipmentId}`);
  revalidatePath("/operations/activity");
  return { status: "success", message: "Expense added.", fieldErrors: EMPTY_ERRORS, correlationId };
}

export async function editExpenseAction(_state: ExpenseActionState, formData: FormData): Promise<ExpenseActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin", "dispatcher");
  if (!actor.ok) return failure(actor.error.category, actor.error.message, correlationId);

  const parsed = expenseEditSchema.safeParse({
    shipmentId: formData.get("shipmentId"),
    expenseId: formData.get("expenseId"),
    expectedUpdatedAt: formData.get("expectedUpdatedAt"),
    ...expenseValues(formData),
  });
  if (!parsed.success) {
    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
      correlationId,
    };
  }

  const result = await updateShipmentExpense(parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure("expense.edit", actor.data.id, parsed.data.expenseId, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }

  revalidatePath(`/operations/shipments/${parsed.data.shipmentId}`);
  if (result.data === "updated") revalidatePath("/operations/activity");
  return {
    status: "success",
    message: result.data === "noop" ? "No expense changes to save." : "Expense updated.",
    fieldErrors: EMPTY_ERRORS,
    correlationId,
  };
}
