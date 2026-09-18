import type { ComponentPropsWithoutRef } from "react";

import { cn } from "@/lib/utils";

export type DividerProps = ComponentPropsWithoutRef<"hr"> & {
  decorative?: boolean;
};

export function Divider({
  decorative = true,
  "aria-hidden": ariaHidden,
  className,
  ...dividerProps
}: DividerProps) {
  return (
    <hr
      {...dividerProps}
      aria-hidden={decorative ? true : ariaHidden}
      className={cn(
        "w-full border-0 border-t border-border-subtle shadow-none",
        className,
      )}
    />
  );
}
