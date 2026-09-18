import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

export type PageHeaderProps = Omit<
  ComponentPropsWithoutRef<"header">,
  "children" | "title"
> & {
  title: string;
  description?: string;
  breadcrumb?: ReactNode;
  status?: ReactNode;
  actions?: ReactNode;
};

export function PageHeader({
  title,
  description,
  breadcrumb,
  status,
  actions,
  className,
  ...headerProps
}: PageHeaderProps) {
  return (
    <header
      className={cn(
        "flex min-w-0 flex-col gap-4 md:flex-row md:items-start md:justify-between",
        className,
      )}
      {...headerProps}
    >
      <div className="flex min-w-0 flex-1 flex-col gap-2">
        {breadcrumb !== undefined && breadcrumb !== null ? (
          <div className="text-small text-secondary">{breadcrumb}</div>
        ) : null}
        <div className="flex min-w-0 flex-wrap items-center gap-2">
          <h1 className="min-w-0 break-words text-h2 text-foreground md:text-h1">
            {title}
          </h1>
          {status !== undefined && status !== null ? <div>{status}</div> : null}
        </div>
        {description ? (
          <p className="text-body text-secondary">{description}</p>
        ) : null}
      </div>
      {actions !== undefined && actions !== null ? (
        <div className="flex w-full flex-wrap items-center gap-2 md:w-auto md:shrink-0 md:justify-end">
          {actions}
        </div>
      ) : null}
    </header>
  );
}
