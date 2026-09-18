"use client";

import type { ComponentPropsWithoutRef } from "react";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

import styles from "./drawer.module.css";

export type DrawerProps = Omit<
  ComponentPropsWithoutRef<typeof DialogPrimitive.Root>,
  "modal"
>;

export function Drawer(props: DrawerProps) {
  return <DialogPrimitive.Root {...props} modal={true} />;
}

export type DrawerTriggerProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Trigger
>;

export function DrawerTrigger(props: DrawerTriggerProps) {
  return <DialogPrimitive.Trigger {...props} />;
}

export type DrawerCloseProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Close
>;

export function DrawerClose(props: DrawerCloseProps) {
  return <DialogPrimitive.Close {...props} />;
}

type ProhibitedDrawerContentProp =
  | "forceMount"
  | "onEscapeKeyDown"
  | "onPointerDownOutside"
  | "onFocusOutside"
  | "onInteractOutside"
  | "onOpenAutoFocus"
  | "onCloseAutoFocus";

export type DrawerContentProps = Omit<
  ComponentPropsWithoutRef<typeof DialogPrimitive.Content>,
  ProhibitedDrawerContentProp
> & {
  side?: "left" | "bottom";
  showCloseButton?: boolean;
};

/**
 * Compose exactly one DrawerTitle and one DrawerDescription within each
 * DrawerContent. This accessibility invariant is not enforced by child types.
 */
export function DrawerContent({
  side = "left",
  showCloseButton = true,
  className,
  children,
  ...contentProps
}: DrawerContentProps) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay
        className={cn(
          "fixed inset-0 z-50 bg-foreground/50 shadow-none",
          styles.overlay,
        )}
      />
      <DialogPrimitive.Content
        className={cn(
          "fixed z-50 overflow-y-auto border-border bg-background-card p-4 shadow-none focus:outline-none",
          side === "left" &&
            "inset-y-0 left-0 right-16 rounded-overlay border-r",
          side === "bottom" &&
            "inset-x-0 bottom-0 max-h-dvh rounded-sheet border-t",
          side === "left" ? styles.leftPanel : styles.bottomPanel,
          className,
        )}
        {...contentProps}
      >
        {children}
        {showCloseButton ? (
          <DialogPrimitive.Close asChild>
            <Button
              aria-label="Close drawer"
              className="absolute right-4 top-4"
              focusSurface="card"
              size="medium"
              variant="ghost"
            >
              <X aria-hidden="true" size={20} strokeWidth={1.75} />
            </Button>
          </DialogPrimitive.Close>
        ) : null}
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}

export type DrawerHeaderProps = ComponentPropsWithoutRef<"div">;

export function DrawerHeader({ className, ...headerProps }: DrawerHeaderProps) {
  return (
    <div
      className={cn("flex flex-col gap-2", className)}
      {...headerProps}
    />
  );
}

export type DrawerTitleProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Title
>;

export function DrawerTitle({ className, ...titleProps }: DrawerTitleProps) {
  return (
    <DialogPrimitive.Title
      className={cn("text-h2 text-foreground", className)}
      {...titleProps}
    />
  );
}

export type DrawerDescriptionProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Description
>;

export function DrawerDescription({
  className,
  ...descriptionProps
}: DrawerDescriptionProps) {
  return (
    <DialogPrimitive.Description
      className={cn("text-small text-secondary", className)}
      {...descriptionProps}
    />
  );
}

export type DrawerFooterProps = ComponentPropsWithoutRef<"div">;

export function DrawerFooter({ className, ...footerProps }: DrawerFooterProps) {
  return (
    <div
      className={cn("flex flex-wrap items-center justify-end gap-2", className)}
      {...footerProps}
    />
  );
}
