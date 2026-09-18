import type { ComponentPropsWithoutRef } from "react";
import { LoaderCircle, type LucideIcon } from "lucide-react";

import { cn } from "@/lib/utils";

export type ButtonProps = ComponentPropsWithoutRef<"button"> & {
  variant?: "primary" | "outline" | "ghost" | "destructive";
  size?: "small" | "medium" | "large";
  loading?: boolean;
  leftIcon?: LucideIcon;
  rightIcon?: LucideIcon;
  focusSurface?: "app" | "card" | "sidebar";
};

const variantClasses = {
  primary:
    "bg-primary text-primary-text-on-solid hover:bg-primary-hover disabled:hover:bg-primary",
  outline:
    "border border-input bg-background-card text-secondary hover:bg-background-hover disabled:hover:bg-background-card",
  ghost:
    "bg-transparent text-secondary hover:bg-background-hover disabled:hover:bg-transparent",
  destructive:
    "bg-danger text-primary-text-on-solid hover:bg-danger disabled:hover:bg-danger",
} as const;

const sizeClasses = {
  small: "h-8 px-3 text-label",
  medium: "h-10 px-4 text-label",
  large: "h-12 px-5 text-label",
} as const;

const iconSizes = {
  small: 16,
  medium: 20,
  large: 24,
} as const;

const focusSurfaceClasses = {
  app: "focus-visible:ring-offset-background-app",
  card: "focus-visible:ring-offset-background-card",
  sidebar: "focus-visible:ring-offset-background-sidebar",
} as const;

export function Button({
  variant = "primary",
  size = "medium",
  loading = false,
  leftIcon: LeftIcon,
  rightIcon: RightIcon,
  focusSurface = "app",
  disabled,
  type = "button",
  "aria-busy": ariaBusy,
  className,
  children,
  ...buttonProps
}: ButtonProps) {
  const iconSize = iconSizes[size];

  return (
    <button
      {...buttonProps}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || ariaBusy || undefined}
      className={cn(
        "relative inline-flex items-center justify-center gap-2 rounded-control border border-transparent font-medium transition-colors duration-interaction ease-standard focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
        variantClasses[variant],
        sizeClasses[size],
        focusSurfaceClasses[focusSurface],
        className,
      )}
    >
      {loading ? (
        <LoaderCircle
          aria-hidden="true"
          className="absolute animate-spin motion-reduce:animate-none"
          size={iconSize}
          strokeWidth={1.75}
        />
      ) : null}
      <span
        className={cn(
          "inline-flex items-center justify-center gap-2",
          loading && "opacity-0",
        )}
      >
        {LeftIcon ? (
          <LeftIcon aria-hidden="true" size={iconSize} strokeWidth={1.75} />
        ) : null}
        {children}
        {RightIcon ? (
          <RightIcon aria-hidden="true" size={iconSize} strokeWidth={1.75} />
        ) : null}
      </span>
    </button>
  );
}
