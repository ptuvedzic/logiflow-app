import type { ComponentPropsWithoutRef, ReactNode } from "react";

import { Container } from "@/components/ui/container";
import {
  DriverBottomNavigation,
  type DriverNavigationItems,
} from "@/components/ui/driver-bottom-navigation";
import {
  Sidebar,
  type SidebarSectionData,
} from "@/components/ui/sidebar";
import { Topbar } from "@/components/ui/topbar";
import { cn } from "@/lib/utils";

export type DriverShellProps = Omit<
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
  bottomNavigationItems: DriverNavigationItems;
  moreControl: ReactNode;
  children: ReactNode;
};

export function DriverShell({
  logo,
  navigationSections,
  sidebarFooter,
  sidebarCollapsed = false,
  topbarTitle,
  topbarActions,
  notification,
  profile,
  bottomNavigationItems,
  moreControl,
  children,
  className,
  ...shellProps
}: DriverShellProps) {
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
      <div className="flex min-w-0 flex-1 flex-col pb-[calc(4rem+env(safe-area-inset-bottom))] md:pb-0">
        <Topbar
          title={topbarTitle}
          logo={logo}
          showLogoAtDesktop={sidebarCollapsed}
          actions={topbarActions}
          notification={notification}
          profile={profile}
        />
        <main className="min-w-0 flex-1 py-4 md:py-5">
          <Container>{children}</Container>
        </main>
      </div>
      <DriverBottomNavigation
        items={bottomNavigationItems}
        moreControl={moreControl}
      />
    </div>
  );
}
