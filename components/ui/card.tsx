import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

export type CardProps = Omit<ComponentPropsWithoutRef<"div">, "children"> & {
  variant?: "default" | "hover";
  header?: ReactNode;
  footer?: ReactNode;
  children: ReactNode;
};

export function Card({
  variant = "default",
  header,
  footer,
  className,
  children,
  ...cardProps
}: CardProps) {
  return (
    <div
      className={cn(
        "flex flex-col gap-4 rounded-card border border-border bg-background-card p-4 shadow-none",
        variant === "hover" &&
          "transition-colors duration-interaction ease-standard hover:bg-background-hover",
        className,
      )}
      {...cardProps}
    >
      {header !== undefined && header !== null ? <div>{header}</div> : null}
      <div>{children}</div>
      {footer !== undefined && footer !== null ? <div>{footer}</div> : null}
    </div>
  );
}
