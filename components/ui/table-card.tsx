import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export type TableCardProps = Omit<
  ComponentPropsWithoutRef<"div">,
  "children" | "title"
> & {
  title?: string;
  description?: string;
  toolbar?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
};

export function TableCard({
  title,
  description,
  toolbar,
  children,
  footer,
  className,
  ...cardProps
}: TableCardProps) {
  const hasIdentity = Boolean(title || description);
  const hasToolbar = toolbar !== undefined && toolbar !== null;

  return (
    <Card
      {...cardProps}
      className={cn(className)}
      header={
        hasIdentity || hasToolbar ? (
          <div className="flex min-w-0 flex-col gap-4">
            {hasIdentity ? (
              <div className="flex min-w-0 flex-col gap-2">
                {title ? (
                  <h2 className="text-h2 text-foreground">{title}</h2>
                ) : null}
                {description ? (
                  <p className="text-small text-secondary">{description}</p>
                ) : null}
              </div>
            ) : null}
            {hasToolbar ? <div>{toolbar}</div> : null}
          </div>
        ) : undefined
      }
      footer={footer}
    >
      {children}
    </Card>
  );
}
