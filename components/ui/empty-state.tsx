import type { ComponentPropsWithoutRef, ReactNode } from "react";
import type { LucideIcon } from "lucide-react";

import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export type EmptyStateProps = Omit<
  ComponentPropsWithoutRef<"div">,
  "children" | "title"
> & {
  icon?: LucideIcon;
  title: string;
  description: string;
  action?: ReactNode;
};

export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
  className,
  ...emptyStateProps
}: EmptyStateProps) {
  return (
    <Card className={cn("text-center", className)} {...emptyStateProps}>
      <div className="flex flex-col items-center gap-4">
        {Icon ? (
          <Icon
            aria-hidden="true"
            className="text-muted"
            size={24}
            strokeWidth={1.75}
          />
        ) : null}
        <div className="flex flex-col gap-2">
          <h2 className="text-h3 text-foreground">{title}</h2>
          <p className="text-small text-secondary">{description}</p>
        </div>
        {action !== undefined && action !== null ? <div>{action}</div> : null}
      </div>
    </Card>
  );
}
