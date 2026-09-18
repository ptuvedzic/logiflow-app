import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

export type ContainerProps = Omit<
  ComponentPropsWithoutRef<"div">,
  "children"
> & {
  children: ReactNode;
};

export function Container({
  className,
  children,
  ...containerProps
}: ContainerProps) {
  return (
    <div
      className={cn("w-full min-w-0 px-4 md:px-5", className)}
      {...containerProps}
    >
      {children}
    </div>
  );
}
