import type { ComponentPropsWithoutRef, ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import Link, { type LinkProps } from "next/link";

import { cn } from "@/lib/utils";

export type DriverNavigationItem = {
  id: "dashboard" | "shipments" | "messages" | "profile";
  label: string;
  href: LinkProps["href"];
  icon: LucideIcon;
  active: boolean;
};

export type DriverNavigationItems = readonly [
  DriverNavigationItem & { id: "dashboard"; label: "Dashboard" },
  DriverNavigationItem & { id: "shipments"; label: "Shipments" },
  DriverNavigationItem & { id: "messages"; label: "Messages" },
  DriverNavigationItem & { id: "profile"; label: "Profile" },
];

export type DriverBottomNavigationProps = Omit<
  ComponentPropsWithoutRef<"nav">,
  "children"
> & {
  items: DriverNavigationItems;
  moreControl: ReactNode;
};

export function DriverBottomNavigation({
  items,
  moreControl,
  className,
  "aria-label": ariaLabel = "Driver navigation",
  ...navProps
}: DriverBottomNavigationProps) {
  return (
    <nav
      {...navProps}
      aria-label={ariaLabel}
      className={cn(
        "fixed inset-x-0 bottom-0 z-10 h-[calc(4rem+env(safe-area-inset-bottom))] border-t border-border-subtle bg-background-card pb-[env(safe-area-inset-bottom)] shadow-none md:hidden",
        className,
      )}
    >
      <ul className="grid h-full grid-cols-5">
        {items.map(({ id, label, href, icon: Icon, active }) => (
          <li key={id} className="min-w-0">
            <Link
              href={href}
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex h-16 min-w-0 flex-col items-center justify-center gap-1 border border-transparent px-1 text-caption text-muted transition-colors duration-interaction ease-standard focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card",
                active && "text-primary",
              )}
            >
              <Icon
                aria-hidden="true"
                size={20}
                strokeWidth={active ? 2 : 1.75}
              />
              <span className="max-w-full truncate">{label}</span>
            </Link>
          </li>
        ))}
        <li className="flex h-16 min-w-0 items-stretch justify-stretch [&>*]:h-full [&>*]:w-full">
          {moreControl}
        </li>
      </ul>
    </nav>
  );
}
