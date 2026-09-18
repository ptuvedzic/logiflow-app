import type { ReactNode } from "react";
import { Bell } from "lucide-react";

import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

type NotificationItemProps = Readonly<{
  title: string;
  message: string;
  createdAt: string;
  timestamp: string;
  unread: boolean;
  action?: ReactNode;
  context?: ReactNode;
}>;

export function NotificationItem({ title, message, createdAt, timestamp, unread, action, context }: NotificationItemProps) {
  return (
    <Card className={cn(unread && "border-primary bg-primary-active")} footer={action}>
      <div className="flex min-w-0 items-start gap-3">
        <Bell aria-hidden="true" className="mt-0.5 shrink-0 text-primary" size={20} strokeWidth={1.75} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-start justify-between gap-2">
            <h2 className="text-body-medium text-foreground">{title}</h2>
            <span className="text-small text-secondary">{unread ? "Unread" : "Read"}</span>
          </div>
          <p className="mt-2 whitespace-pre-wrap break-words text-body text-foreground">{message}</p>
          {context ? <div className="mt-2 text-small">{context}</div> : null}
          <time className="mt-2 block text-small text-secondary" dateTime={createdAt}>{timestamp}</time>
        </div>
      </div>
    </Card>
  );
}
