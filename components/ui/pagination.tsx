import type { ComponentPropsWithoutRef } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import Link from "next/link";

import { cn } from "@/lib/utils";

type FocusSurface = "app" | "card" | "sidebar";

const focusSurfaceClasses = {
  app: "focus-visible:ring-offset-background-app",
  card: "focus-visible:ring-offset-background-card",
  sidebar: "focus-visible:ring-offset-background-sidebar",
} as const satisfies Record<FocusSurface, string>;

const controlClasses =
  "inline-flex min-h-12 min-w-12 items-center justify-center gap-2 rounded-control border px-3 text-label transition-colors duration-interaction ease-standard focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 md:min-h-10 md:min-w-10";

export type PaginationProps = Omit<
  ComponentPropsWithoutRef<"nav">,
  "aria-label"
> & {
  "aria-label"?: string;
};

export function Pagination({
  "aria-label": ariaLabel = "Pagination",
  className,
  children,
  ...navProps
}: PaginationProps) {
  return (
    <nav aria-label={ariaLabel} className={cn(className)} {...navProps}>
      <ul className="flex flex-wrap items-center justify-center gap-2">
        {children}
      </ul>
    </nav>
  );
}

export type PaginationItemProps = ComponentPropsWithoutRef<"li">;

export function PaginationItem({
  className,
  ...itemProps
}: PaginationItemProps) {
  return <li className={cn(className)} {...itemProps} />;
}

export type PaginationLinkProps = Omit<
  ComponentPropsWithoutRef<typeof Link>,
  "aria-current"
> & {
  active?: boolean;
  focusSurface?: FocusSurface;
};

export function PaginationLink({
  active = false,
  focusSurface = "card",
  className,
  ...linkProps
}: PaginationLinkProps) {
  return (
    <Link
      {...linkProps}
      aria-current={active ? "page" : undefined}
      className={cn(
        controlClasses,
        active
          ? "border-border bg-background-card text-foreground"
          : "border-transparent bg-transparent text-secondary hover:bg-background-hover",
        focusSurfaceClasses[focusSurface],
        className,
      )}
    />
  );
}

type PaginationDirectionEnabledProps = Omit<
  PaginationLinkProps,
  "active" | "children"
> & {
  disabled?: false;
  showIcon?: boolean;
};

type PaginationDirectionDisabledProps = Omit<
  ComponentPropsWithoutRef<"span">,
  "children" | "tabIndex"
> & {
  disabled: true;
  href?: never;
  showIcon?: boolean;
  focusSurface?: FocusSurface;
};

export type PaginationPreviousProps =
  | PaginationDirectionEnabledProps
  | PaginationDirectionDisabledProps;

export type PaginationNextProps = PaginationPreviousProps;

type PaginationDirectionProps = PaginationPreviousProps & {
  direction: "previous" | "next";
};

function PaginationDirection(props: PaginationDirectionProps) {
  const isPrevious = props.direction === "previous";
  const label = isPrevious ? "Previous" : "Next";
  const Icon = isPrevious ? ChevronLeft : ChevronRight;

  if (props.disabled === true) {
    const {
      disabled: _disabled,
      direction: _direction,
      showIcon = true,
      focusSurface: _focusSurface,
      className,
      ...spanProps
    } = props;
    void _disabled;
    void _direction;
    void _focusSurface;

    return (
      <span
        {...spanProps}
        aria-disabled="true"
        className={cn(
          "inline-flex min-h-12 min-w-12 cursor-not-allowed items-center justify-center gap-2 rounded-control border border-transparent px-4 text-label text-secondary opacity-50 md:min-h-10 md:min-w-10",
          className,
        )}
      >
        {isPrevious && showIcon ? (
          <Icon aria-hidden="true" size={20} strokeWidth={1.75} />
        ) : null}
        {label}
        {!isPrevious && showIcon ? (
          <Icon aria-hidden="true" size={20} strokeWidth={1.75} />
        ) : null}
      </span>
    );
  }

  const {
    disabled: _disabled,
    direction: _direction,
    showIcon = true,
    focusSurface = "card",
    className,
    ...linkProps
  } = props;
  void _disabled;
  void _direction;

  return (
    <PaginationLink
      {...linkProps}
      focusSurface={focusSurface}
      className={cn("px-4", className)}
    >
      {isPrevious && showIcon ? (
        <Icon aria-hidden="true" size={20} strokeWidth={1.75} />
      ) : null}
      {label}
      {!isPrevious && showIcon ? (
        <Icon aria-hidden="true" size={20} strokeWidth={1.75} />
      ) : null}
    </PaginationLink>
  );
}

export function PaginationPrevious(props: PaginationPreviousProps) {
  return <PaginationDirection {...props} direction="previous" />;
}

export function PaginationNext(props: PaginationNextProps) {
  return <PaginationDirection {...props} direction="next" />;
}
