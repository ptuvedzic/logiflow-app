import type { ReactNode } from "react";
import { Ellipsis, type LucideIcon } from "lucide-react";
import Link, { type LinkProps } from "next/link";

import { Divider } from "@/components/ui/divider";
import {
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger,
} from "@/components/ui/drawer";
import { NavigationDrawerBoundary } from "@/components/ui/navigation-drawer-boundary";
import { cn } from "@/lib/utils";

export type DriverMoreNavigationItem = {
  id: "documents" | "vehicle" | "settings";
  label: string;
  href: LinkProps["href"];
  icon: LucideIcon;
  active: boolean;
};

export type DriverMoreNavigationItems = readonly [
  DriverMoreNavigationItem & { id: "documents"; label: "Documents" },
  DriverMoreNavigationItem & { id: "vehicle"; label: "Vehicle" },
  DriverMoreNavigationItem & { id: "settings"; label: "Settings" },
];

export type DriverMoreNavigationProps = {
  items: DriverMoreNavigationItems;
  logoutAction: ReactNode;
  title: string;
  description: string;
};

export function DriverMoreNavigation({
  items,
  logoutAction,
  title,
  description,
}: DriverMoreNavigationProps) {
  const active = items.some((item) => item.active);

  return (
    <NavigationDrawerBoundary>
      <DrawerTrigger asChild>
        <button
          type="button"
          aria-label="More"
          className={cn(
            "flex h-16 w-full min-w-0 flex-col items-center justify-center gap-1 border border-transparent px-1 text-caption text-muted transition-colors duration-interaction ease-standard focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card data-[state=open]:text-primary",
            active && "text-primary",
          )}
        >
          <Ellipsis
            aria-hidden="true"
            size={20}
            strokeWidth={active ? 2 : 1.75}
          />
          <span className="max-w-full truncate">More</span>
        </button>
      </DrawerTrigger>
      <DrawerContent
        className="flex flex-col gap-4 pb-[calc(1rem+env(safe-area-inset-bottom))]"
        side="bottom"
      >
        <DrawerHeader className="pr-12">
          <DrawerTitle>{title}</DrawerTitle>
          <DrawerDescription>{description}</DrawerDescription>
        </DrawerHeader>
        <nav aria-label="More navigation">
          <ul className="flex flex-col gap-1">
            {items.map(({ id, label, href, icon: Icon, active: itemActive }) => (
              <li key={id}>
                <DrawerClose asChild>
                  <Link
                    href={href}
                    aria-current={itemActive ? "page" : undefined}
                    className={cn(
                      "flex min-h-12 min-w-0 items-center gap-3 rounded-control border border-transparent px-3 text-body-medium text-secondary transition-colors duration-interaction ease-standard hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card",
                      itemActive && "bg-primary-active text-foreground",
                    )}
                  >
                    <Icon
                      aria-hidden="true"
                      className={cn(
                        "shrink-0",
                        itemActive && "text-primary-icon",
                      )}
                      size={20}
                      strokeWidth={itemActive ? 2 : 1.75}
                    />
                    <span className="min-w-0 truncate">{label}</span>
                  </Link>
                </DrawerClose>
              </li>
            ))}
          </ul>
        </nav>
        <div>
          <Divider className="mb-4" />
          {logoutAction}
        </div>
      </DrawerContent>
    </NavigationDrawerBoundary>
  );
}
