"use client";

import type { ReactNode } from "react";
import { Activity, Bell, Building2, FileText, LayoutDashboard, Mail, Map, Package, TriangleAlert, Truck, UserRound, Users, Wrench } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

import { LogoutControl } from "@/components/auth/logout-control";
import { LogiFlowWordmark } from "@/components/brand/logiflow-wordmark";
import { OperationsMobileNavigation } from "@/components/ui/operations-mobile-navigation";
import { AdminShell, DispatcherShell } from "@/components/ui/operations-shell";
import type { SidebarSectionData } from "@/components/ui/sidebar";

type OperationsShellNavigationProps = Readonly<{
  children: ReactNode;
  fullName: string;
  role: "admin" | "dispatcher";
  unreadNotificationCount: number;
}>;

export function OperationsShellNavigation({ children, fullName, role, unreadNotificationCount }: OperationsShellNavigationProps) {
  const pathname = usePathname();
  const navigationSections = [
    {
      id: "menu",
      label: "Menu",
      items: [
        {
          id: "dashboard",
          label: "Dashboard",
          href: "/operations/dashboard",
          icon: LayoutDashboard,
          active: pathname === "/operations/dashboard",
        },
        ...(role === "admin" ? [{
          id: "accounts",
          label: "Accounts",
          href: "/operations/accounts",
          icon: Users,
          active: pathname === "/operations/accounts" || pathname.startsWith("/operations/accounts/"),
        }] : []),
        {
          id: "clients",
          label: "Clients",
          href: "/operations/clients",
          icon: Building2,
          active: pathname === "/operations/clients" || pathname.startsWith("/operations/clients/"),
        },
        {
          id: "drivers",
          label: "Drivers",
          href: "/operations/drivers",
          icon: UserRound,
          active: pathname === "/operations/drivers" || pathname.startsWith("/operations/drivers/"),
        },
        {
          id: "vehicles",
          label: "Vehicles",
          href: "/operations/vehicles",
          icon: Truck,
          active: pathname === "/operations/vehicles" || pathname.startsWith("/operations/vehicles/"),
        },
        {
          id: "maintenance",
          label: "Maintenance",
          href: "/operations/maintenance",
          icon: Wrench,
          active: pathname === "/operations/maintenance" || pathname.startsWith("/operations/maintenance/"),
        },
        {
          id: "shipments",
          label: "Shipments",
          href: "/operations/shipments",
          icon: Package,
          active: pathname === "/operations/shipments" || pathname.startsWith("/operations/shipments/"),
        },
        {
          id: "tracking",
          label: "Tracking",
          href: "/operations/tracking",
          icon: Map,
          active: pathname === "/operations/tracking",
        },
        {
          id: "documents",
          label: "Documents",
          href: "/operations/documents",
          icon: FileText,
          active: pathname === "/operations/documents" || pathname.startsWith("/operations/documents/"),
        },
        {
          id: "messages",
          label: "Messages",
          href: "/operations/messages/new",
          icon: Mail,
          active: pathname.startsWith("/operations/messages/"),
        },
        {
          id: "notifications",
          label: "Notifications",
          href: "/operations/notifications",
          icon: Bell,
          active: pathname === "/operations/notifications",
        },
        {
          id: "alerts",
          label: "Alerts",
          href: "/operations/alerts",
          icon: TriangleAlert,
          active: pathname === "/operations/alerts",
        },
        {
          id: "activity",
          label: "Activity",
          href: "/operations/activity",
          icon: Activity,
          active: pathname === "/operations/activity",
        },
      ],
    },
  ] as const satisfies readonly SidebarSectionData[];
  const logo = <LogiFlowWordmark />;
  const mobileNavigation = (
    <OperationsMobileNavigation
      description="Navigate the operations workspace."
      footer={<LogoutControl className="w-full justify-start" />}
      logo={logo}
      sections={navigationSections}
      title="Operations"
    />
  );
  const shellProps = {
    logo,
    navigationSections,
    sidebarFooter: <LogoutControl className="w-full justify-start" focusSurface="sidebar" />,
    topbarTitle: pathname.startsWith("/operations/accounts")
      ? "Accounts"
      : pathname.startsWith("/operations/clients")
        ? "Clients"
        : pathname.startsWith("/operations/drivers")
          ? "Drivers"
          : pathname.startsWith("/operations/vehicles")
            ? "Vehicles"
          : pathname.startsWith("/operations/maintenance")
            ? "Maintenance"
            : pathname.startsWith("/operations/shipments")
              ? "Shipments"
            : pathname.startsWith("/operations/documents")
              ? "Documents"
            : pathname.startsWith("/operations/tracking")
              ? "Tracking"
            : pathname.startsWith("/operations/messages/")
              ? "Messages"
            : pathname.startsWith("/operations/alerts")
              ? "Alerts"
            : pathname.startsWith("/operations/notifications")
              ? "Notifications"
            : pathname.startsWith("/operations/activity")
              ? "Activity"
            : "Dashboard",
    mobileNavigationTrigger: mobileNavigation,
    notification: (
      <Link
        href="/operations/notifications"
        aria-label={`Notifications, ${unreadNotificationCount} unread`}
        className="relative inline-flex min-h-11 min-w-11 items-center justify-center rounded-control text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10 md:min-w-10"
      >
        <Bell aria-hidden="true" size={20} strokeWidth={1.75} />
        {unreadNotificationCount > 0 ? <span aria-hidden="true" className="absolute right-0 top-0 inline-flex min-h-5 min-w-5 items-center justify-center rounded-pill bg-primary px-1 text-caption text-on-primary">{unreadNotificationCount > 99 ? "99+" : unreadNotificationCount}</span> : null}
      </Link>
    ),
    profile: (
      <div className="text-right">
        <p className="text-body-medium text-foreground">{fullName}</p>
        <p className="text-small capitalize text-secondary">{role}</p>
      </div>
    ),
    children,
  };

  return role === "admin" ? <AdminShell {...shellProps} /> : <DispatcherShell {...shellProps} />;
}
