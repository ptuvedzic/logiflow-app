import type { ReactNode } from "react";
import { Menu } from "lucide-react";
import Link from "next/link";

import { Button } from "@/components/ui/button";
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
import type { SidebarSectionData } from "@/components/ui/sidebar";
import { cn } from "@/lib/utils";

export type OperationsMobileNavigationProps = {
  logo: ReactNode;
  sections: readonly SidebarSectionData[];
  footer?: ReactNode;
  title: string;
  description: string;
  navigationLabel?: string;
  triggerLabel?: string;
};

export function OperationsMobileNavigation({
  logo,
  sections,
  footer,
  title,
  description,
  navigationLabel = "Mobile navigation",
  triggerLabel = "Open navigation",
}: OperationsMobileNavigationProps) {
  return (
    <NavigationDrawerBoundary>
      <DrawerTrigger asChild>
        <Button
          aria-label={triggerLabel}
          className="min-h-12 min-w-12 px-0"
          focusSurface="card"
          size="medium"
          variant="ghost"
        >
          <Menu aria-hidden="true" size={20} strokeWidth={1.75} />
        </Button>
      </DrawerTrigger>
      <DrawerContent className="flex flex-col gap-4" side="left">
        <div className="min-h-12 pr-12">{logo}</div>
        <DrawerHeader className="pr-12">
          <DrawerTitle>{title}</DrawerTitle>
          <DrawerDescription>{description}</DrawerDescription>
        </DrawerHeader>
        <nav aria-label={navigationLabel} className="flex flex-col gap-6">
          {sections.map((section) => (
            <section
              key={section.id}
              aria-labelledby={`mobile-sidebar-section-${section.id}`}
            >
              <h2
                id={`mobile-sidebar-section-${section.id}`}
                className="px-3 text-caption text-muted"
              >
                {section.label}
              </h2>
              <ul className="mt-2 flex flex-col gap-1">
                {section.items.map(({ id, label, href, icon: Icon, active }) => (
                  <li key={id}>
                    <DrawerClose asChild>
                      <Link
                        href={href}
                        aria-current={active ? "page" : undefined}
                        className={cn(
                          "flex min-h-12 min-w-0 items-center gap-3 rounded-control border border-transparent px-3 text-body-medium text-secondary transition-colors duration-interaction ease-standard hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card",
                          active && "bg-primary-active text-foreground",
                        )}
                      >
                        <Icon
                          aria-hidden="true"
                          className={cn(
                            "shrink-0",
                            active && "text-primary-icon",
                          )}
                          size={20}
                          strokeWidth={1.75}
                        />
                        <span className="min-w-0 truncate">{label}</span>
                      </Link>
                    </DrawerClose>
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </nav>
        {footer !== undefined && footer !== null ? (
          <div className="mt-auto">
            <Divider className="mb-4" />
            {footer}
          </div>
        ) : null}
      </DrawerContent>
    </NavigationDrawerBoundary>
  );
}
