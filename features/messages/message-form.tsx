"use client";

import { useMemo, useRef, useState, useTransition } from "react";

import { sendDriverMessageAction } from "@/app/(operations)/operations/messages/new/actions";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import {
  MESSAGE_BODY_MAX_LENGTH,
  type MessageActionState,
} from "@/features/messages/message-schema";
import type {
  MessageRecipientOption,
  MessageShipmentOption,
} from "@/lib/dal/messages";

const INITIAL_STATE: MessageActionState = {
  status: "idle",
  message: null,
  fieldErrors: {},
  correlationId: null,
};

export function MessageForm({
  recipients,
  shipments,
}: Readonly<{
  recipients: readonly MessageRecipientOption[];
  shipments: readonly MessageShipmentOption[];
}>) {
  const [state, setState] = useState<MessageActionState>(INITIAL_STATE);
  const [pending, startTransition] = useTransition();
  const [driverId, setDriverId] = useState("");
  const [bodyLength, setBodyLength] = useState(0);
  const formRef = useRef<HTMLFormElement>(null);
  const matchingShipments = useMemo(
    () => shipments.filter((shipment) => shipment.driverId === driverId),
    [driverId, shipments],
  );

  function submit(formData: FormData) {
    startTransition(async () => {
      const result = await sendDriverMessageAction(INITIAL_STATE, formData);
      setState(result);
      if (result.status === "success") {
        formRef.current?.reset();
        setDriverId("");
        setBodyLength(0);
      }
    });
  }

  const driverError = state.fieldErrors.driverId?.[0];
  const shipmentError = state.fieldErrors.shipmentId?.[0];
  const bodyError = state.fieldErrors.body?.[0];

  return (
    <form ref={formRef} action={submit} className="flex flex-col gap-4" noValidate>
      <div className="flex flex-col gap-2">
        <label className="text-label text-foreground" htmlFor="message-driver">
          Driver
        </label>
        <Select
          id="message-driver"
          name="driverId"
          required
          disabled={pending}
          invalid={Boolean(driverError)}
          aria-describedby={driverError ? "message-driver-error" : undefined}
          focusSurface="card"
          className="min-h-11 md:min-h-10"
          value={driverId}
          onChange={(event) => setDriverId(event.target.value)}
        >
          <option value="">Select a Driver</option>
          {recipients.map((recipient) => (
            <option key={recipient.id} value={recipient.id}>
              {recipient.displayName}
            </option>
          ))}
        </Select>
        {driverError ? <p id="message-driver-error" className="text-small text-danger">{driverError}</p> : null}
      </div>

      <div className="flex flex-col gap-2">
        <label className="text-label text-foreground" htmlFor="message-shipment">
          Shipment <span className="text-secondary">(optional)</span>
        </label>
        <Select
          key={driverId}
          id="message-shipment"
          name="shipmentId"
          disabled={pending || driverId === ""}
          invalid={Boolean(shipmentError)}
          aria-describedby={shipmentError ? "message-shipment-error" : undefined}
          focusSurface="card"
          className="min-h-11 md:min-h-10"
        >
          <option value="">No Shipment</option>
          {matchingShipments.map((shipment) => (
            <option key={shipment.id} value={shipment.id}>
              {shipment.trackingNumber} — {shipment.statusLabel}
            </option>
          ))}
        </Select>
        {shipmentError ? <p id="message-shipment-error" className="text-small text-danger">{shipmentError}</p> : null}
      </div>

      <div className="flex flex-col gap-2">
        <div className="flex items-center justify-between gap-3">
          <label className="text-label text-foreground" htmlFor="message-body">Message</label>
          <span className="text-caption text-secondary" aria-live="polite">
            {bodyLength}/{MESSAGE_BODY_MAX_LENGTH}
          </span>
        </div>
        <Textarea
          id="message-body"
          name="body"
          required
          maxLength={MESSAGE_BODY_MAX_LENGTH}
          disabled={pending}
          invalid={Boolean(bodyError)}
          aria-describedby={bodyError ? "message-body-error" : "message-body-help"}
          focusSurface="card"
          onChange={(event) => setBodyLength(event.target.value.length)}
        />
        <p id="message-body-help" className="text-small text-secondary">
          Plain text only. Leading and trailing whitespace will be removed.
        </p>
        {bodyError ? <p id="message-body-error" className="text-small text-danger">{bodyError}</p> : null}
      </div>

      {state.message ? (
        <div>
          <p
            role={state.status === "success" ? "status" : "alert"}
            aria-live="polite"
            className={state.status === "success" ? "text-small text-success" : "text-small text-danger"}
          >
            {state.message}
          </p>
          {state.status === "infrastructure" && state.correlationId ? (
            <p className="text-caption text-muted">Reference: {state.correlationId}</p>
          ) : null}
        </div>
      ) : null}

      <div>
        <Button type="submit" loading={pending} disabled={pending || recipients.length === 0} focusSurface="card" className="min-h-11 w-full sm:w-auto">
          Send message
        </Button>
      </div>
    </form>
  );
}
