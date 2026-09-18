"use server";

import { randomUUID } from "node:crypto";

import { revalidatePath } from "next/cache";

import { markDriverMessageRead } from "@/lib/dal/messages";

export type MarkMessageReadActionState =
  | {
      status: "success";
      message: null;
      correlationId: string;
      data: Readonly<{ messageId: string; readAt: string }>;
    }
  | {
      status:
        | "validation"
        | "not_found"
        | "unauthenticated"
        | "inactive_profile"
        | "missing_profile"
        | "forbidden"
        | "infrastructure";
      message: string;
      correlationId: string;
      data: null;
    };

export async function markMessageReadAction(
  messageId: string,
): Promise<MarkMessageReadActionState> {
  const correlationId = randomUUID();
  const result = await markDriverMessageRead(messageId);

  if (!result.ok) {
    if (result.error.category === "infrastructure") {
      console.error({
        operation: "driver.messages.acknowledge",
        category: "infrastructure",
        correlationId,
      });
    }

    return {
      status: result.error.category,
      message: result.error.message,
      correlationId,
      data: null,
    };
  }

  revalidatePath("/driver/messages");

  return {
    status: "success",
    message: null,
    correlationId,
    data: result.data,
  };
}
