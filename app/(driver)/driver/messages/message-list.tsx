"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Mail } from "lucide-react";

import { markMessageReadAction } from "@/app/(driver)/driver/messages/actions";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import type { DriverMessage } from "@/lib/dal/messages";

const timestampFormatter = new Intl.DateTimeFormat("en", {
  dateStyle: "medium",
  timeStyle: "short",
  timeZone: "UTC",
});

export function MessageList({
  messages,
}: Readonly<{ messages: readonly DriverMessage[] }>) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [pendingMessageId, setPendingMessageId] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  function acknowledge(messageId: string) {
    setPendingMessageId(messageId);
    setErrorMessage(null);

    startTransition(async () => {
      const result = await markMessageReadAction(messageId);

      if (result.status === "success") {
        router.refresh();
      } else {
        setErrorMessage(
          result.status === "not_found" || result.status === "validation"
            ? "This message is unavailable."
            : "Unable to mark this message as read. Try again.",
        );
      }

      setPendingMessageId(null);
    });
  }

  return (
    <section aria-labelledby="message-list-heading" className="flex flex-col gap-4">
      <h2 id="message-list-heading" className="sr-only">
        Messages
      </h2>
      {errorMessage ? (
        <p role="alert" className="text-small text-danger">
          {errorMessage}
        </p>
      ) : null}
      <ol className="grid min-w-0 gap-4">
        {messages.map((message) => {
          const unread = message.readAt === null;
          const acknowledging = isPending && pendingMessageId === message.id;

          return (
            <li key={message.id}>
              <Card
                className={unread ? "border-primary" : undefined}
                header={
                  <div className="flex min-w-0 items-start justify-between gap-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <Mail
                        aria-hidden="true"
                        className="shrink-0 text-primary"
                        size={20}
                        strokeWidth={1.75}
                      />
                      <div className="min-w-0">
                        <h3 className="text-body-medium text-foreground">
                          Operations
                        </h3>
                        <time
                          dateTime={message.sentAt}
                          className="text-small text-secondary"
                        >
                          {timestampFormatter.format(new Date(message.sentAt))} UTC
                        </time>
                      </div>
                    </div>
                    {unread ? (
                      <span className="shrink-0 rounded-pill border border-primary bg-primary-active px-2 py-1 text-caption text-primary">
                        Unread
                      </span>
                    ) : null}
                  </div>
                }
                footer={
                  unread ? (
                    <Button
                      variant="outline"
                      focusSurface="card"
                      className="min-h-11 w-full md:w-auto"
                      loading={acknowledging}
                      disabled={isPending && !acknowledging}
                      onClick={() => acknowledge(message.id)}
                    >
                      Mark as read
                    </Button>
                  ) : null
                }
              >
                <div className="flex min-w-0 flex-col gap-3">
                  <p className="whitespace-pre-wrap break-words text-body text-foreground">
                    {message.body}
                  </p>
                  {message.shipmentReference ? (
                    <p className="text-small text-secondary">
                      Shipment {message.shipmentReference}
                    </p>
                  ) : null}
                </div>
              </Card>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
