"use client";

import type {
  ComponentPropsWithoutRef,
  CSSProperties,
  ReactNode,
} from "react";
import * as TooltipPrimitive from "@radix-ui/react-tooltip";

import { cn } from "@/lib/utils";

import styles from "./tooltip.module.css";

export type TooltipProviderProps = {
  delayDuration?: number;
  skipDelayDuration?: number;
  children: ReactNode;
};

export function TooltipProvider({
  delayDuration = 700,
  skipDelayDuration = 300,
  children,
}: TooltipProviderProps) {
  return (
    <TooltipPrimitive.Provider
      delayDuration={delayDuration}
      skipDelayDuration={skipDelayDuration}
      disableHoverableContent={true}
    >
      {children}
    </TooltipPrimitive.Provider>
  );
}

export type TooltipProps = {
  open?: boolean;
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
  children: ReactNode;
};

export function Tooltip({
  open,
  defaultOpen,
  onOpenChange,
  children,
}: TooltipProps) {
  return (
    <TooltipPrimitive.Root
      open={open}
      defaultOpen={defaultOpen}
      onOpenChange={onOpenChange}
    >
      {children}
    </TooltipPrimitive.Root>
  );
}

export type TooltipTriggerProps = ComponentPropsWithoutRef<
  typeof TooltipPrimitive.Trigger
>;

/**
 * A Tooltip supplements an existing accessible name. The trigger must provide
 * its own name through visible text, aria-label, or another equivalent naming
 * mechanism; Tooltip content must never be its only accessible name.
 */
export function TooltipTrigger(props: TooltipTriggerProps) {
  return <TooltipPrimitive.Trigger {...props} />;
}

type TooltipContentNativeProps = {
  id?: string;
  dir?: "ltr" | "rtl" | "auto";
  lang?: string;
  style?: CSSProperties;
};

export type TooltipContentProps = TooltipContentNativeProps & {
  children: ReactNode;
  side?: "top" | "right" | "bottom" | "left";
  sideOffset?: number;
  align?: "start" | "center" | "end";
  className?: string;
};

/**
 * Tooltip content must remain visible, supplementary, and non-interactive.
 * The trigger retains its own accessible name; ReactNode cannot enforce this
 * composition invariant or prohibit focusable descendants.
 */
export function TooltipContent({
  children,
  side = "right",
  sideOffset = 8,
  align = "center",
  className,
  id,
  dir,
  lang,
  style,
}: TooltipContentProps) {
  return (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Content
        id={id}
        dir={dir}
        lang={lang}
        style={style}
        side={side}
        sideOffset={sideOffset}
        align={align}
        className={cn(
          "z-50 rounded-tooltip bg-foreground px-2 py-1 text-caption text-background-card shadow-none",
          styles.content,
          className,
        )}
      >
        {children}
      </TooltipPrimitive.Content>
    </TooltipPrimitive.Portal>
  );
}
