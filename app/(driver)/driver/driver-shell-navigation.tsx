"use client";

import type { ReactNode } from "react";
import {
  Bell,
  FileText,
  LayoutDashboard,
  Mail,
  PackageOpen,
  Settings,
  Truck,
  UserRound,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { LogoutControl } from "@/components/auth/logout-control";
import { LogiFlowWordmark } from "@/components/brand/logiflow-wordmark";
import type { DriverNavigationItems } from "@/components/ui/driver-bottom-navigation";
import type { DriverMoreNavigationItems } from "@/components/ui/driver-more-navigation";
import { DriverMoreNavigation } from "@/components/ui/driver-more-navigation";
import { DriverShell } from "@/components/ui/driver-shell";
import type { SidebarSectionData } from "@/components/ui/sidebar";

export type DriverShellNavigationProps = {
  children: ReactNode;
  unreadNotificationCount: number;
};

export function DriverShellNavigation({
  children,
  unreadNotificationCount,
}: DriverShellNavigationProps) {
  const pathname = usePathname();
  const isActive = (href: string) => pathname === href;

  const bottomNavigationItems = [
    {
      id: "dashboard",
      label: "Dashboard",
      href: "/driver/dashboard",
      icon: LayoutDashboard,
      active: isActive("/driver/dashboard"),
    },
    {
      id: "shipments",
      label: "Shipments",
      href: "/driver/shipments",
      icon: PackageOpen,
      active: isActive("/driver/shipments"),
    },
    {
      id: "messages",
      label: "Messages",
      href: "/driver/messages",
      icon: Mail,
      active: isActive("/driver/messages"),
    },
    {
      id: "profile",
      label: "Profile",
      href: "/driver/profile",
      icon: UserRound,
      active: isActive("/driver/profile"),
    },
  ] as const satisfies DriverNavigationItems;

  const moreNavigationItems = [
    {
      id: "documents",
      label: "Documents",
      href: "/driver/documents",
      icon: FileText,
      active: isActive("/driver/documents"),
    },
    {
      id: "vehicle",
      label: "Vehicle",
      href: "/driver/vehicle",
      icon: Truck,
      active: isActive("/driver/vehicle"),
    },
    {
      id: "settings",
      label: "Settings",
      href: "/driver/settings",
      icon: Settings,
      active: isActive("/driver/settings"),
    },
  ] as const satisfies DriverMoreNavigationItems;

  const navigationSections = [
    {
      id: "menu",
      label: "Menu",
      items: [...bottomNavigationItems, ...moreNavigationItems],
    },
  ] as const satisfies readonly SidebarSectionData[];

  const logo = <LogiFlowWordmark />;

  return (
    <DriverShell
      logo={logo}
      navigationSections={navigationSections}
      sidebarFooter={
        <LogoutControl
          className="w-full justify-start"
          focusSurface="sidebar"
        />
      }
      topbarTitle="Driver"
      notification={
        <Link
          href="/driver/notifications"
          aria-label={`Notifications, ${unreadNotificationCount} unread`}
          className="relative inline-flex min-h-11 min-w-11 items-center justify-center rounded-control text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10 md:min-w-10"
        >
          <Bell aria-hidden="true" size={20} strokeWidth={1.75} />
          {unreadNotificationCount > 0 ? (
            <span aria-hidden="true" className="absolute right-0 top-0 inline-flex min-h-5 min-w-5 items-center justify-center rounded-pill bg-primary px-1 text-caption text-on-primary">
              {unreadNotificationCount > 99 ? "99+" : unreadNotificationCount}
            </span>
          ) : null}
        </Link>
      }
      bottomNavigationItems={bottomNavigationItems}
      moreControl={
        <DriverMoreNavigation
          title="More"
          description="Open another Driver destination or log out."
          items={moreNavigationItems}
          logoutAction={<LogoutControl className="w-full justify-start" />}
        />
      }
    >
      {children}
    </DriverShell>
  );
}
