import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

export type SectionProps = Omit<
  ComponentPropsWithoutRef<"section">,
  "children" | "title"
> & {
  title?: string;
  description?: string;
  action?: ReactNode;
  children: ReactNode;
};

export function Section({
  title,
  description,
  action,
  className,
  children,
  ...sectionProps
}: SectionProps) {
  const hasHeader =
    title !== undefined ||
    description !== undefined ||
    (action !== undefined && action !== null);

  return (
    <section
      className={cn("flex min-w-0 flex-col gap-4", className)}
      {...sectionProps}
    >
      {hasHeader ? (
        <div className="flex min-w-0 flex-col gap-4 md:flex-row md:items-start md:justify-between">
          <div className="flex min-w-0 flex-1 flex-col gap-2">
            {title ? <h2 className="text-h2 text-foreground">{title}</h2> : null}
            {description ? (
              <p className="text-small text-secondary">{description}</p>
            ) : null}
          </div>
          {action !== undefined && action !== null ? (
            <div className="flex w-full flex-wrap items-center gap-2 md:w-auto md:shrink-0 md:justify-end">
              {action}
            </div>
          ) : null}
        </div>
      ) : null}
      {children}
    </section>
  );
}
