import type { ComponentPropsWithoutRef, ReactNode } from "react";
import { CircleAlert } from "lucide-react";

import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export type ErrorStateProps = Omit<
  ComponentPropsWithoutRef<"div">,
  "children" | "title"
> & {
  title: string;
  description: string;
  retryAction?: ReactNode;
};

export function ErrorState({
  title,
  description,
  retryAction,
  className,
  ...errorStateProps
}: ErrorStateProps) {
  return (
    <Card
      {...errorStateProps}
      role="alert"
      className={cn("text-center", className)}
    >
      <div className="flex flex-col items-center gap-4">
        <CircleAlert
          aria-hidden="true"
          className="text-danger"
          size={24}
          strokeWidth={1.75}
        />
        <div className="flex flex-col gap-2">
          <h2 className="text-h3 text-foreground">{title}</h2>
          <p className="text-small text-secondary">{description}</p>
        </div>
        {retryAction !== undefined && retryAction !== null ? (
          <div>{retryAction}</div>
        ) : null}
      </div>
    </Card>
  );
}
