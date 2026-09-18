import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

export type TableToolbarProps = Omit<
  ComponentPropsWithoutRef<"div">,
  "children"
> & {
  leading?: ReactNode;
  trailing?: ReactNode;
};

export function TableToolbar({
  leading,
  trailing,
  className,
  ...toolbarProps
}: TableToolbarProps) {
  return (
    <div
      className={cn(
        "flex min-w-0 flex-col gap-4 md:flex-row md:items-center md:justify-between",
        className,
      )}
      {...toolbarProps}
    >
      {leading !== undefined && leading !== null ? (
        <div className="flex w-full min-w-0 flex-1 flex-wrap items-center gap-2">
          {leading}
        </div>
      ) : null}
      {trailing !== undefined && trailing !== null ? (
        <div className="flex w-full min-w-0 flex-wrap items-center gap-2 md:w-auto md:shrink-0 md:justify-end">
          {trailing}
        </div>
      ) : null}
    </div>
  );
}
