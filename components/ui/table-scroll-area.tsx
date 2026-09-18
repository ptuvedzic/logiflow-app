import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

type FocusSurface = "app" | "card" | "sidebar";

const focusSurfaceClasses = {
  app: "focus-visible:ring-offset-background-app",
  card: "focus-visible:ring-offset-background-card",
  sidebar: "focus-visible:ring-offset-background-sidebar",
} as const satisfies Record<FocusSurface, string>;

type TableScrollAreaBaseProps = Omit<
  ComponentPropsWithoutRef<"div">,
  | "aria-label"
  | "aria-labelledby"
  | "children"
  | "role"
  | "tabIndex"
> & {
  children: ReactNode;
  focusSurface?: FocusSurface;
};

type TableScrollAreaLabelProps =
  | {
      "aria-label": string;
      "aria-labelledby"?: never;
    }
  | {
      "aria-label"?: never;
      "aria-labelledby": string;
    };

export type TableScrollAreaProps = TableScrollAreaBaseProps &
  TableScrollAreaLabelProps;

export function TableScrollArea({
  "aria-label": ariaLabel,
  "aria-labelledby": ariaLabelledBy,
  focusSurface = "card",
  className,
  children,
  ...scrollAreaProps
}: TableScrollAreaProps) {
  return (
    <div
      {...scrollAreaProps}
      role="region"
      tabIndex={0}
      aria-label={ariaLabel}
      aria-labelledby={ariaLabelledBy}
      className={cn(
        "w-full min-w-0 overflow-x-auto focus-visible:border focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2",
        focusSurfaceClasses[focusSurface],
        className,
      )}
    >
      {children}
    </div>
  );
}
