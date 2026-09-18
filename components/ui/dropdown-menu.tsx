"use client";

import type { ComponentPropsWithoutRef, ReactNode } from "react";
import * as DropdownMenuPrimitive from "@radix-ui/react-dropdown-menu";
import type { LucideIcon } from "lucide-react";

import { cn } from "@/lib/utils";

import styles from "./dropdown-menu.module.css";

type DropdownMenuStructuralProps = {
  id?: string;
  dir?: "ltr" | "rtl" | "auto";
  lang?: string;
  className?: string;
};

export type DropdownMenuProps = {
  open?: boolean;
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
  children: ReactNode;
};

export function DropdownMenu({
  open,
  defaultOpen,
  onOpenChange,
  children,
}: DropdownMenuProps) {
  return (
    <DropdownMenuPrimitive.Root
      open={open}
      defaultOpen={defaultOpen}
      onOpenChange={onOpenChange}
      modal={true}
    >
      {children}
    </DropdownMenuPrimitive.Root>
  );
}

export type DropdownMenuTriggerProps = ComponentPropsWithoutRef<
  typeof DropdownMenuPrimitive.Trigger
>;

/**
 * An icon-only trigger must provide its own accessible name through visible
 * text, aria-label, or another equivalent mechanism. Dropdown menu content
 * must not be treated as the trigger's accessible name.
 */
export function DropdownMenuTrigger(props: DropdownMenuTriggerProps) {
  return <DropdownMenuPrimitive.Trigger {...props} />;
}

export type DropdownMenuContentProps = DropdownMenuStructuralProps & {
  children: ReactNode;
  side?: "top" | "right" | "bottom" | "left";
  sideOffset?: number;
  align?: "start" | "center" | "end";
};

type DropdownMenuContentPrimitiveProps = ComponentPropsWithoutRef<
  typeof DropdownMenuPrimitive.Content
> &
  Pick<ComponentPropsWithoutRef<"div">, "dir">;

function DropdownMenuContentPrimitive(
  props: DropdownMenuContentPrimitiveProps,
) {
  return <DropdownMenuPrimitive.Content {...props} />;
}

export function DropdownMenuContent({
  children,
  side = "bottom",
  sideOffset = 8,
  align = "end",
  id,
  dir,
  lang,
  className,
}: DropdownMenuContentProps) {
  return (
    <DropdownMenuPrimitive.Portal>
      <DropdownMenuContentPrimitive
        id={id}
        dir={dir}
        lang={lang}
        side={side}
        sideOffset={sideOffset}
        align={align}
        className={cn(
          "z-50 rounded-control border border-border bg-background-card p-1 text-small text-foreground shadow-none",
          styles.content,
          className,
        )}
      >
        {children}
      </DropdownMenuContentPrimitive>
    </DropdownMenuPrimitive.Portal>
  );
}

type DropdownMenuItemSelectHandler = ComponentPropsWithoutRef<
  typeof DropdownMenuPrimitive.Item
>["onSelect"];

export type DropdownMenuItemProps = DropdownMenuStructuralProps & {
  children: ReactNode;
  icon?: LucideIcon;
  shortcut?: ReactNode;
  disabled?: boolean;
  variant?: "default" | "destructive";
  onSelect?: DropdownMenuItemSelectHandler;
};

export function DropdownMenuItem({
  children,
  icon: Icon,
  shortcut,
  disabled = false,
  variant = "default",
  onSelect,
  id,
  dir,
  lang,
  className,
}: DropdownMenuItemProps) {
  return (
    <DropdownMenuPrimitive.Item
      id={id}
      dir={dir}
      lang={lang}
      disabled={disabled}
      onSelect={onSelect}
      className={cn(
        "flex min-h-10 cursor-default select-none items-center gap-2 rounded-control border border-transparent px-3 py-2 text-small text-foreground outline-none transition-colors duration-interaction ease-standard data-[highlighted]:bg-background-hover focus-visible:border-info focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
        variant === "destructive" && "text-danger",
        className,
      )}
    >
      {Icon ? (
        <Icon aria-hidden="true" className="shrink-0" size={16} strokeWidth={1.75} />
      ) : null}
      <span>{children}</span>
      {shortcut !== undefined && shortcut !== null ? (
        <span className="ml-auto pl-4 text-caption text-muted">
          {shortcut}
        </span>
      ) : null}
    </DropdownMenuPrimitive.Item>
  );
}

export type DropdownMenuLabelProps = DropdownMenuStructuralProps & {
  children: ReactNode;
};

export function DropdownMenuLabel({
  children,
  id,
  dir,
  lang,
  className,
}: DropdownMenuLabelProps) {
  return (
    <DropdownMenuPrimitive.Label
      id={id}
      dir={dir}
      lang={lang}
      className={cn("px-3 py-2 text-caption text-muted", className)}
    >
      {children}
    </DropdownMenuPrimitive.Label>
  );
}

export type DropdownMenuGroupProps = DropdownMenuStructuralProps & {
  children: ReactNode;
};

export function DropdownMenuGroup({
  children,
  id,
  dir,
  lang,
  className,
}: DropdownMenuGroupProps) {
  return (
    <DropdownMenuPrimitive.Group
      id={id}
      dir={dir}
      lang={lang}
      className={className}
    >
      {children}
    </DropdownMenuPrimitive.Group>
  );
}

export type DropdownMenuSeparatorProps = DropdownMenuStructuralProps;

export function DropdownMenuSeparator({
  id,
  dir,
  lang,
  className,
}: DropdownMenuSeparatorProps) {
  return (
    <DropdownMenuPrimitive.Separator
      id={id}
      dir={dir}
      lang={lang}
      className={cn("my-1 h-px bg-border-subtle", className)}
    />
  );
}
