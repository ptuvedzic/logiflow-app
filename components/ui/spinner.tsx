import type { ComponentPropsWithoutRef } from "react";
import { LoaderCircle } from "lucide-react";

import { cn } from "@/lib/utils";

export type SpinnerProps = Omit<
  ComponentPropsWithoutRef<"span">,
  "children"
> & {
  size?: "small" | "medium" | "large";
  label?: string;
};

const iconSizes = {
  small: 16,
  medium: 20,
  large: 24,
} as const;

export function Spinner({
  size = "medium",
  label,
  className,
  ...spinnerProps
}: SpinnerProps) {
  const hasLabel = Boolean(label);

  return (
    <span
      {...spinnerProps}
      role={hasLabel ? "status" : undefined}
      aria-live={hasLabel ? "polite" : undefined}
      aria-hidden={hasLabel ? undefined : true}
      className={cn(
        "inline-flex items-center gap-2 text-primary-icon",
        className,
      )}
    >
      <LoaderCircle
        aria-hidden="true"
        className="shrink-0 animate-spin motion-reduce:animate-none"
        size={iconSizes[size]}
        strokeWidth={1.75}
      />
      {hasLabel ? <span className="text-small text-secondary">{label}</span> : null}
    </span>
  );
}
