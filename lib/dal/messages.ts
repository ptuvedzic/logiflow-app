import "server-only";

import { z } from "zod";

import type { MessageSendInput } from "@/features/messages/message-schema";
import { shipmentStatusLabels } from "@/features/shipments/shipment-schema";
import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryError, AuthBoundaryResult } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

type ShipmentStatus = Database["public"]["Enums"]["shipment_status"];

export type MessageRecipientOption = Readonly<{
  id: string;
  displayName: string;
}>;

export type MessageShipmentOption = Readonly<{
  id: string;
  trackingNumber: string;
  driverId: string;
  status: ShipmentStatus;
  statusLabel: string;
}>;

export type MessageSendOptions = Readonly<{
  recipients: readonly MessageRecipientOption[];
  shipments: readonly MessageShipmentOption[];
}>;

export type DriverMessage = Readonly<{
  id: string;
  body: string;
  sentAt: string;
  readAt: string | null;
  shipmentReference: string | null;
}>;

type MessageAcknowledgementError =
  | AuthBoundaryError
  | { category: "validation"; message: "Message unavailable." }
  | { category: "not_found"; message: "Message unavailable." };

type MessageSendError =
  | AuthBoundaryError
  | { category: "not_found" | "business_rule" | "rate_limited"; message: string }
  | { category: "infrastructure"; message: string };

type MessageResult<T> = { ok: true; data: T } | { ok: false; error: MessageSendError };

export type MessageAcknowledgementResult =
  | {
      ok: true;
      data: Readonly<{ messageId: string; readAt: string }>;
    }
  | { ok: false; error: MessageAcknowledgementError };

const messageIdSchema = z.uuid();

async function requireOperations(
  client: Awaited<ReturnType<typeof createClient>>,
): Promise<AuthBoundaryResult<Readonly<{ id: string }>>> {
  const profileResult = await requireProfileWithClient(client);
  if (!profileResult.ok) return profileResult;
  if (!profileResult.data.isActive) {
    return { ok: false, error: { category: "inactive_profile", message: "Account is inactive." } };
  }
  if (profileResult.data.role !== "admin" && profileResult.data.role !== "dispatcher") {
    return { ok: false, error: { category: "forbidden", message: "Access denied." } };
  }
  return { ok: true, data: { id: profileResult.data.id } };
}

export async function getMessageSendOptions(): Promise<AuthBoundaryResult<MessageSendOptions>> {
  const client = await createClient();
  const actor = await requireOperations(client);
  if (!actor.ok) return actor;

  const [recipientResponse, shipmentResponse] = await Promise.all([
    client.rpc("list_message_recipient_options"),
    client.rpc("list_message_shipment_options"),
  ]);
  const error = recipientResponse.error ?? shipmentResponse.error;

  if (error || recipientResponse.data === null || shipmentResponse.data === null) {
    return { ok: false, error: { category: "infrastructure", message: "Unable to verify account access." } };
  }

  return {
    ok: true,
    data: {
      recipients: recipientResponse.data.map((row) => ({ id: row.id, displayName: row.display_name })),
      shipments: shipmentResponse.data.map((row) => ({
        id: row.id,
        trackingNumber: row.tracking_number,
        driverId: row.driver_id,
        status: row.status,
        statusLabel: shipmentStatusLabels[row.status],
      })),
    },
  };
}

function mapSendError(message: string): MessageSendError {
  if (message.includes("message_send_access_denied")) return { category: "forbidden", message: "Access denied." };
  if (message.includes("message_send_driver_unavailable")) return { category: "not_found", message: "Driver unavailable." };
  if (message.includes("message_send_shipment_unavailable")) return { category: "not_found", message: "Shipment unavailable." };
  if (message.includes("message_send_shipment_driver_mismatch")) return { category: "business_rule", message: "Shipment unavailable for the selected Driver." };
  if (message.includes("message_send_rate_limited")) return { category: "rate_limited", message: "Too many messages have been sent. Try again later." };
  if (message.includes("message_send_body_invalid")) return { category: "business_rule", message: "Message content is invalid." };
  return { category: "infrastructure", message: "Unable to send the message right now." };
}

export async function sendDriverMessage(
  input: MessageSendInput,
): Promise<MessageResult<Readonly<{ messageId: string; notificationId: string; sentAt: string }>>> {
  const client = await createClient();
  const actor = await requireOperations(client);
  if (!actor.ok) return actor;
  const { data, error } = await client.rpc("send_driver_message", {
    target_driver_id: input.driverId,
    // The generated RPC type cannot express a nullable PostgreSQL function argument.
    target_shipment_id: input.shipmentId as string,
    input_body: input.body,
  });
  if (error) return { ok: false, error: mapSendError(error.message) };
  const row = data?.[0];
  if (!row) return { ok: false, error: { category: "infrastructure", message: "Unable to send the message right now." } };
  return { ok: true, data: { messageId: row.message_id, notificationId: row.notification_id, sentAt: row.sent_at } };
}

async function requireDriver(
  client: Awaited<ReturnType<typeof createClient>>,
): Promise<AuthBoundaryResult<Readonly<{ id: string }>>> {
  const profileResult = await requireProfileWithClient(client);

  if (!profileResult.ok) {
    return profileResult;
  }

  if (!profileResult.data.isActive) {
    return {
      ok: false,
      error: { category: "inactive_profile", message: "Account is inactive." },
    };
  }

  if (profileResult.data.role !== "driver") {
    return {
      ok: false,
      error: { category: "forbidden", message: "Access denied." },
    };
  }

  const { data: drivers, error } = await client
    .from("drivers")
    .select("id")
    .eq("profile_id", profileResult.data.id)
    .limit(2);

  if (error || drivers === null || drivers.length > 1) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  const driver = drivers[0];

  if (driver === undefined) {
    return {
      ok: false,
      error: {
        category: "missing_profile",
        message: "Account profile unavailable.",
      },
    };
  }

  return { ok: true, data: { id: driver.id } };
}

export async function getDriverMessages(): Promise<
  AuthBoundaryResult<readonly DriverMessage[]>
> {
  const client = await createClient();
  const driverResult = await requireDriver(client);

  if (!driverResult.ok) {
    return driverResult;
  }

  const { data: messages, error } = await client
    .from("messages")
    .select(
      "id, body, sent_at, read_at, shipment_id, shipments(tracking_number)",
    )
    .order("sent_at", { ascending: false })
    .order("id", { ascending: false })
    .limit(50);

  if (error || messages === null) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  return {
    ok: true,
    data: messages.map((message) => ({
      id: message.id,
      body: message.body,
      sentAt: message.sent_at,
      readAt: message.read_at,
      shipmentReference: message.shipments?.tracking_number ?? null,
    })),
  };
}

export async function markDriverMessageRead(
  messageId: string,
): Promise<MessageAcknowledgementResult> {
  const parsedMessageId = messageIdSchema.safeParse(messageId);

  if (!parsedMessageId.success) {
    return {
      ok: false,
      error: { category: "validation", message: "Message unavailable." },
    };
  }

  const client = await createClient();
  const driverResult = await requireDriver(client);

  if (!driverResult.ok) {
    return driverResult;
  }

  const { data: readAt, error } = await client.rpc(
    "acknowledge_driver_message",
    { message_id: parsedMessageId.data },
  );

  if (error) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  if (readAt === null) {
    return {
      ok: false,
      error: { category: "not_found", message: "Message unavailable." },
    };
  }

  return {
    ok: true,
    data: { messageId: parsedMessageId.data, readAt },
  };
}
