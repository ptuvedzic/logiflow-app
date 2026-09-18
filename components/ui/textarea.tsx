import type { ComponentPropsWithoutRef } from "react";

import { cn } from "@/lib/utils";

export type TextareaProps = ComponentPropsWithoutRef<"textarea"> & {
  invalid?: boolean;
  focusSurface?: "app" | "card" | "sidebar";
};

const focusSurfaceClasses = {
  app: "focus-visible:ring-offset-background-app",
  card: "focus-visible:ring-offset-background-card",
  sidebar: "focus-visible:ring-offset-background-sidebar",
} as const;

export function Textarea({
  invalid = false,
  focusSurface = "app",
  "aria-invalid": ariaInvalid,
  className,
  ...textareaProps
}: TextareaProps) {
  const isInvalid =
    invalid ||
    ariaInvalid === true ||
    ariaInvalid === "true" ||
    ariaInvalid === "grammar" ||
    ariaInvalid === "spelling";

  return (
    <textarea
      {...textareaProps}
      aria-invalid={invalid ? true : ariaInvalid}
      className={cn(
        "min-h-[120px] resize-y rounded-control border border-input bg-background-card px-[14px] py-3 text-body text-foreground placeholder:text-placeholder transition-colors duration-interaction ease-standard focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
        isInvalid && "border-danger",
        focusSurfaceClasses[focusSurface],
        className,
      )}
    />
  );
}
