import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { Container } from "@/components/ui/container";
import {
  Sidebar,
  type SidebarSectionData,
} from "@/components/ui/sidebar";
import { Topbar } from "@/components/ui/topbar";
import { cn } from "@/lib/utils";

type OperationsShellProps = Omit<
  ComponentPropsWithoutRef<"div">,
  "children"
> & {
  logo: ReactNode;
  navigationSections: readonly SidebarSectionData[];
  sidebarFooter?: ReactNode;
  sidebarCollapsed?: boolean;
  topbarTitle: ReactNode;
  topbarActions?: ReactNode;
  notification?: ReactNode;
  profile?: ReactNode;
  mobileNavigationTrigger?: ReactNode;
  mobileNavigation?: ReactNode;
  children: ReactNode;
};

export type AdminShellProps = OperationsShellProps;
export type DispatcherShellProps = OperationsShellProps;

function OperationsShell({
  logo,
  navigationSections,
  sidebarFooter,
  sidebarCollapsed = false,
  topbarTitle,
  topbarActions,
  notification,
  profile,
  mobileNavigationTrigger,
  mobileNavigation,
  children,
  className,
  ...shellProps
}: OperationsShellProps) {
  return (
    <div
      className={cn("flex min-h-screen min-w-0 bg-background-app", className)}
      {...shellProps}
    >
      <Sidebar
        logo={logo}
        sections={navigationSections}
        footer={sidebarFooter}
        collapsed={sidebarCollapsed}
      />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar
          title={topbarTitle}
          logo={logo}
          showLogoAtDesktop={sidebarCollapsed}
          mobileNavigationTrigger={mobileNavigationTrigger}
          actions={topbarActions}
          notification={notification}
          profile={profile}
        />
        {mobileNavigation !== undefined && mobileNavigation !== null ? (
          <div className="md:hidden">{mobileNavigation}</div>
        ) : null}
        <main className="min-w-0 flex-1 py-4 md:py-5">
          <Container>{children}</Container>
        </main>
      </div>
    </div>
  );
}

export function AdminShell(props: AdminShellProps) {
  return <OperationsShell {...props} />;
}

export function DispatcherShell(props: DispatcherShellProps) {
  return <OperationsShell {...props} />;
}
