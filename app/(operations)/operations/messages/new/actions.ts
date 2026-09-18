"use server";

import { randomUUID } from "node:crypto";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import {
  messageSendSchema,
  type MessageActionState,
} from "@/features/messages/message-schema";
import { requireRole } from "@/lib/dal/auth";
import { sendDriverMessage } from "@/lib/dal/messages";

const EMPTY_ERRORS = Object.freeze({});

function failure(
  status: MessageActionState["status"],
  message: string,
  correlationId: string,
): MessageActionState {
  return { status, message, fieldErrors: EMPTY_ERRORS, correlationId };
}

export async function sendDriverMessageAction(
  _state: MessageActionState,
  formData: FormData,
): Promise<MessageActionState> {
  const correlationId = randomUUID();
  const actor = await requireRole("admin", "dispatcher");

  if (!actor.ok) {
    return failure(actor.error.category, actor.error.message, correlationId);
  }

  const parsed = messageSendSchema.safeParse({
    driverId: formData.get("driverId"),
    shipmentId: formData.get("shipmentId"),
    body: formData.get("body"),
  });

  if (!parsed.success) {
    return {
      status: "validation",
      message: "Check the highlighted fields.",
      fieldErrors: z.flattenError(parsed.error).fieldErrors,
      correlationId,
    };
  }

  const result = await sendDriverMessage(parsed.data);

  if (!result.ok) {
    if (result.error.category === "infrastructure") {
      console.error({
        operation: "messages.send",
        category: "infrastructure",
        actorProfileId: actor.data.id,
        correlationId,
      });
    }

    return failure(result.error.category, result.error.message, correlationId);
  }

  revalidatePath("/driver/messages");

  return {
    status: "success",
    message: "Message sent.",
    fieldErrors: EMPTY_ERRORS,
    correlationId,
  };
}
