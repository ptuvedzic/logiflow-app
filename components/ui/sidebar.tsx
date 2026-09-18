import type { ComponentPropsWithoutRef, ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import Link, { type LinkProps } from "next/link";

import { Divider } from "@/components/ui/divider";
import { SidebarTooltipBoundary } from "@/components/ui/sidebar-tooltip-boundary";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

export type SidebarItemData = {
  id: string;
  label: string;
  href: LinkProps["href"];
  icon: LucideIcon;
  active?: boolean;
};

export type SidebarSectionData = {
  id: string;
  label: string;
  items: readonly SidebarItemData[];
};

export type SidebarItemProps = SidebarItemData & {
  collapsed?: boolean;
};

function SidebarItemLink({
  label,
  href,
  icon: Icon,
  active = false,
  collapsed = false,
}: SidebarItemProps) {
  return (
    <Link
      href={href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "flex min-h-12 min-w-0 items-center gap-3 rounded-control border border-transparent px-3 text-body-medium text-secondary transition-colors duration-interaction ease-standard hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-sidebar",
        active && "bg-primary-active text-foreground",
        collapsed
          ? "justify-center px-2"
          : "justify-center px-2 xl:justify-start xl:px-3",
      )}
    >
      <Icon
        aria-hidden="true"
        className={cn("shrink-0", active && "text-primary-icon")}
        size={20}
        strokeWidth={active ? 2 : 1.75}
      />
      <span
        className={cn(
          "truncate",
          collapsed ? "sr-only" : "sr-only xl:not-sr-only",
        )}
      >
        {label}
      </span>
    </Link>
  );
}

export function SidebarItem(props: SidebarItemProps) {
  return (
    <li>
      <SidebarItemLink {...props} />
    </li>
  );
}

function SidebarTooltipItem(props: SidebarItemProps) {
  return (
    <li>
      <Tooltip>
        <TooltipTrigger asChild>
          <SidebarItemLink {...props} />
        </TooltipTrigger>
        <TooltipContent side="right">{props.label}</TooltipContent>
      </Tooltip>
    </li>
  );
}

export type SidebarSectionProps = {
  section: SidebarSectionData;
  collapsed?: boolean;
};

export function SidebarSection({
  section,
  collapsed = false,
}: SidebarSectionProps) {
  return (
    <section aria-labelledby={`sidebar-section-${section.id}`}>
      <h2
        id={`sidebar-section-${section.id}`}
        className={cn(
          "px-3 text-caption text-muted",
          collapsed ? "sr-only" : "sr-only xl:not-sr-only",
        )}
      >
        {section.label}
      </h2>
      <ul className="mt-2 flex flex-col gap-1">
        {section.items.map((item) => (
          <SidebarItem key={item.id} {...item} collapsed={collapsed} />
        ))}
      </ul>
    </section>
  );
}

type SidebarNavigationProps = {
  sections: readonly SidebarSectionData[];
  collapsed: boolean;
  withTooltips: boolean;
};

function SidebarNavigation({
  sections,
  collapsed,
  withTooltips,
}: SidebarNavigationProps) {
  return sections.map((section) => (
    <section key={section.id} aria-labelledby={`sidebar-section-${section.id}`}>
      <h2
        id={`sidebar-section-${section.id}`}
        className={cn(
          "px-3 text-caption text-muted",
          collapsed ? "sr-only" : "sr-only xl:not-sr-only",
        )}
      >
        {section.label}
      </h2>
      <ul className="mt-2 flex flex-col gap-1">
        {section.items.map((item) =>
          withTooltips ? (
            <SidebarTooltipItem
              key={item.id}
              {...item}
              collapsed={collapsed}
            />
          ) : (
            <SidebarItem key={item.id} {...item} collapsed={collapsed} />
          ),
        )}
      </ul>
    </section>
  ));
}

export type SidebarProps = Omit<
  ComponentPropsWithoutRef<"aside">,
  "children"
> & {
  logo: ReactNode;
  sections: readonly SidebarSectionData[];
  footer?: ReactNode;
  collapsed?: boolean;
  navigationLabel?: string;
};

export function Sidebar({
  logo,
  sections,
  footer,
  collapsed = false,
  navigationLabel = "Primary navigation",
  className,
  ...asideProps
}: SidebarProps) {
  return (
    <aside
      className={cn(
        "sticky top-0 hidden h-screen shrink-0 flex-col border-r border-border-subtle bg-background-sidebar shadow-none md:flex md:w-16",
        collapsed ? "xl:w-16" : "xl:w-[276px]",
        className,
      )}
      {...asideProps}
    >
      {!collapsed ? (
        <div className="hidden min-h-16 items-center px-5 xl:flex">{logo}</div>
      ) : null}
      <nav
        aria-label={navigationLabel}
        className={cn(
          "flex min-h-0 flex-1 flex-col gap-6 overflow-y-auto p-2",
          !collapsed && "xl:p-4",
        )}
      >
        <SidebarTooltipBoundary
          collapsed={collapsed}
          tooltipNavigation={
            <SidebarNavigation
              sections={sections}
              collapsed={collapsed}
              withTooltips={true}
            />
          }
          expandedNavigation={
            <SidebarNavigation
              sections={sections}
              collapsed={collapsed}
              withTooltips={false}
            />
          }
        />
      </nav>
      {footer !== undefined && footer !== null ? (
        <div className={cn("p-2", !collapsed && "xl:p-4")}>
          <Divider className="mb-4" />
          {footer}
        </div>
      ) : null}
    </aside>
  );
}
