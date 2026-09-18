import type { ComponentPropsWithoutRef } from "react";

import { cn } from "@/lib/utils";

export type TableProps = ComponentPropsWithoutRef<"table">;

export function Table({ className, ...tableProps }: TableProps) {
  return (
    <table
      className={cn(
        "w-full border-collapse text-left text-body text-foreground",
        className,
      )}
      {...tableProps}
    />
  );
}

export type TableHeaderProps = ComponentPropsWithoutRef<"thead">;

export function TableHeader({ className, ...headerProps }: TableHeaderProps) {
  return <thead className={cn(className)} {...headerProps} />;
}

export type TableBodyProps = ComponentPropsWithoutRef<"tbody">;

export function TableBody({ className, ...bodyProps }: TableBodyProps) {
  return (
    <tbody
      className={cn(
        "[&>tr:last-child]:border-b-0 [&>tr:hover]:bg-background-hover",
        className,
      )}
      {...bodyProps}
    />
  );
}

export type TableRowProps = ComponentPropsWithoutRef<"tr">;

export function TableRow({ className, ...rowProps }: TableRowProps) {
  return (
    <tr
      className={cn(
        "border-b border-border-subtle transition-colors duration-interaction ease-standard",
        className,
      )}
      {...rowProps}
    />
  );
}

export type TableHeadProps = ComponentPropsWithoutRef<"th">;

export function TableHead({
  scope = "col",
  className,
  ...headProps
}: TableHeadProps) {
  return (
    <th
      scope={scope}
      className={cn(
        "px-5 py-4 align-middle text-label text-secondary",
        className,
      )}
      {...headProps}
    />
  );
}

export type TableCellProps = ComponentPropsWithoutRef<"td">;

export function TableCell({ className, ...cellProps }: TableCellProps) {
  return (
    <td
      className={cn(
        "px-5 py-4 align-middle text-body text-foreground",
        className,
      )}
      {...cellProps}
    />
  );
}

export type TableCaptionProps = ComponentPropsWithoutRef<"caption">;

export function TableCaption({
  className,
  ...captionProps
}: TableCaptionProps) {
  return (
    <caption
      className={cn(
        "caption-top pb-4 text-left text-small text-secondary",
        className,
      )}
      {...captionProps}
    />
  );
}
