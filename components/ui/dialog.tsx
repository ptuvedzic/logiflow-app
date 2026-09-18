"use client";

import type { ComponentPropsWithoutRef } from "react";
import * as DialogPrimitive from "@radix-ui/react-dialog";

import { cn } from "@/lib/utils";

import styles from "./dialog.module.css";

export type DialogProps = Omit<
  ComponentPropsWithoutRef<typeof DialogPrimitive.Root>,
  "modal"
>;

export function Dialog(props: DialogProps) {
  return <DialogPrimitive.Root {...props} modal={true} />;
}

export type DialogTriggerProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Trigger
>;

export function DialogTrigger(props: DialogTriggerProps) {
  return <DialogPrimitive.Trigger {...props} />;
}

export type DialogPortalProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Portal
>;

export function DialogPortal(props: DialogPortalProps) {
  return <DialogPrimitive.Portal {...props} />;
}

export type DialogOverlayProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Overlay
>;

export function DialogOverlay({
  className,
  ...overlayProps
}: DialogOverlayProps) {
  return (
    <DialogPrimitive.Overlay
      className={cn(
        "fixed inset-0 z-50 bg-foreground/50",
        styles.overlay,
        className,
      )}
      {...overlayProps}
    />
  );
}

export type DialogContentProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Content
>;

/**
 * Compose exactly one DialogTitle and one DialogDescription within each
 * DialogContent. This accessibility invariant is not enforced by child types.
 */
export function DialogContent({
  className,
  children,
  ...contentProps
}: DialogContentProps) {
  return (
    <DialogPortal>
      <DialogOverlay />
      <DialogPrimitive.Content
        className={cn(
          "fixed left-1/2 top-1/2 z-50 max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-overlay border border-border bg-background-card p-4 shadow-none focus:outline-none",
          styles.content,
          className,
        )}
        {...contentProps}
      >
        {children}
      </DialogPrimitive.Content>
    </DialogPortal>
  );
}

export type DialogTitleProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Title
>;

export function DialogTitle({ className, ...titleProps }: DialogTitleProps) {
  return (
    <DialogPrimitive.Title
      className={cn("text-h2 text-foreground", className)}
      {...titleProps}
    />
  );
}

export type DialogDescriptionProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Description
>;

export function DialogDescription({
  className,
  ...descriptionProps
}: DialogDescriptionProps) {
  return (
    <DialogPrimitive.Description
      className={cn("text-small text-secondary", className)}
      {...descriptionProps}
    />
  );
}

export type DialogCloseProps = ComponentPropsWithoutRef<
  typeof DialogPrimitive.Close
>;

export function DialogClose(props: DialogCloseProps) {
  return <DialogPrimitive.Close {...props} />;
}

export type DialogHeaderProps = ComponentPropsWithoutRef<"div">;

export function DialogHeader({
  className,
  ...headerProps
}: DialogHeaderProps) {
  return (
    <div className={cn("flex flex-col gap-2", className)} {...headerProps} />
  );
}

export type DialogFooterProps = ComponentPropsWithoutRef<"div">;

export function DialogFooter({
  className,
  ...footerProps
}: DialogFooterProps) {
  return (
    <div
      className={cn(
        "flex flex-col gap-2 sm:flex-row sm:justify-end",
        className,
      )}
      {...footerProps}
    />
  );
}
