"use server";

import { randomUUID } from "node:crypto";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import { clientEditSchema, clientFormSchema, clientLifecycleSchema } from "@/features/clients/client-schema";
import { requireRole } from "@/lib/dal/auth";
import { changeClientLifecycle, createClientRecord, updateClientRecord } from "@/lib/dal/clients";

export type ClientActionState = Readonly<{
  status: "idle" | "success" | "validation" | "not_found" | "conflict" | "business_rule" | "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure";
  message: string | null;
  fieldErrors: Readonly<Record<string, string[] | undefined>>;
  correlationId: string | null;
}>;

const EMPTY_ERRORS = Object.freeze({});
function failure(status: ClientActionState["status"], message: string, correlationId: string): ClientActionState {
  return { status, message, fieldErrors: EMPTY_ERRORS, correlationId };
}
async function authorize(correlationId: string) {
  const result = await requireRole("admin", "dispatcher");
  return result.ok ? result : failure(result.error.category, result.error.message, correlationId);
}
function logFailure(operation: string, actorProfileId: string, correlationId: string) {
  console.error({ operation, category: "infrastructure", actorProfileId, correlationId });
}

export async function createClientAction(_state: ClientActionState, formData: FormData): Promise<ClientActionState> {
  const correlationId = randomUUID();
  const actor = await authorize(correlationId);
  if (!("ok" in actor)) return actor;
  const parsed = clientFormSchema.safeParse({ companyName: formData.get("companyName"), contactPerson: formData.get("contactPerson"), phone: formData.get("phone"), email: formData.get("email"), address: formData.get("address"), notes: formData.get("notes") });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted fields.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await createClientRecord(randomUUID(), parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure("clients.create", actor.data.id, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }
  revalidatePath("/operations/clients");
  redirect("/operations/clients");
}

export async function editClientAction(_state: ClientActionState, formData: FormData): Promise<ClientActionState> {
  const correlationId = randomUUID();
  const actor = await authorize(correlationId);
  if (!("ok" in actor)) return actor;
  const parsed = clientEditSchema.safeParse({ clientId: formData.get("clientId"), expectedUpdatedAt: formData.get("expectedUpdatedAt"), companyName: formData.get("companyName"), contactPerson: formData.get("contactPerson"), phone: formData.get("phone"), email: formData.get("email"), address: formData.get("address"), notes: formData.get("notes") });
  if (!parsed.success) return { status: "validation", message: "Check the highlighted fields.", fieldErrors: z.flattenError(parsed.error).fieldErrors, correlationId };
  const result = await updateClientRecord(parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure("clients.edit", actor.data.id, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }
  revalidatePath("/operations/clients");
  redirect("/operations/clients");
}

export async function changeClientLifecycleAction(_state: ClientActionState, formData: FormData): Promise<ClientActionState> {
  const correlationId = randomUUID();
  const actor = await authorize(correlationId);
  if (!("ok" in actor)) return actor;
  const parsed = clientLifecycleSchema.safeParse({ clientId: formData.get("clientId"), operation: formData.get("operation") });
  if (!parsed.success) return failure("validation", "Client unavailable.", correlationId);
  const result = await changeClientLifecycle(parsed.data);
  if (!result.ok) {
    if (result.error.category === "infrastructure") logFailure(`clients.${parsed.data.operation}`, actor.data.id, correlationId);
    return failure(result.error.category, result.error.message, correlationId);
  }
  revalidatePath("/operations/clients");
  return { status: "success", message: parsed.data.operation === "archive" ? "Client archived." : "Client reactivated.", fieldErrors: EMPTY_ERRORS, correlationId };
}
