import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { cn } from "@/lib/utils";

export type TopbarProps = Omit<
  ComponentPropsWithoutRef<"header">,
  "children" | "title"
> & {
  title: ReactNode;
  logo?: ReactNode;
  showLogoAtDesktop?: boolean;
  mobileNavigationTrigger?: ReactNode;
  actions?: ReactNode;
  notification?: ReactNode;
  profile?: ReactNode;
};

export function Topbar({
  title,
  logo,
  showLogoAtDesktop = false,
  mobileNavigationTrigger,
  actions,
  notification,
  profile,
  className,
  ...headerProps
}: TopbarProps) {
  return (
    <header
      className={cn(
        "flex min-h-16 min-w-0 flex-wrap items-center gap-4 border-b border-border-subtle bg-background-card px-4 py-2 shadow-none md:px-5",
        className,
      )}
      {...headerProps}
    >
      <div className="flex min-w-0 flex-1 flex-wrap items-center gap-4">
        {mobileNavigationTrigger !== undefined &&
        mobileNavigationTrigger !== null ? (
          <div className="shrink-0 md:hidden">{mobileNavigationTrigger}</div>
        ) : null}
        {logo !== undefined && logo !== null ? (
          <div
            className={cn(
              "hidden shrink-0 md:flex",
              !showLogoAtDesktop && "xl:hidden",
            )}
          >
            {logo}
          </div>
        ) : null}
        <div className="min-w-0 flex-1 text-h3 text-foreground">{title}</div>
      </div>
      <div className="flex min-w-0 flex-wrap items-center justify-end gap-2">
        {actions !== undefined && actions !== null ? (
          <div className="flex min-w-0 flex-wrap items-center gap-2">
            {actions}
          </div>
        ) : null}
        {notification !== undefined && notification !== null ? (
          <div className="shrink-0">{notification}</div>
        ) : null}
        {profile !== undefined && profile !== null ? (
          <div className="shrink-0">{profile}</div>
        ) : null}
      </div>
    </header>
  );
}
