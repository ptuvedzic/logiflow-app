"use client";

import { useSyncExternalStore, type ReactNode } from "react";

import { TooltipProvider } from "@/components/ui/tooltip";

const tabletRailMediaQuery =
  "(min-width: 768px) and (max-width: 1279px)";

function subscribeToTabletRail(callback: () => void) {
  const mediaQuery = window.matchMedia(tabletRailMediaQuery);

  mediaQuery.addEventListener("change", callback);

  return () => {
    mediaQuery.removeEventListener("change", callback);
  };
}

function getTabletRailSnapshot() {
  return window.matchMedia(tabletRailMediaQuery).matches;
}

function getServerTabletRailSnapshot() {
  return false;
}

type SidebarTooltipBoundaryProps = {
  collapsed: boolean;
  tooltipNavigation: ReactNode;
  expandedNavigation: ReactNode;
};

export function SidebarTooltipBoundary({
  collapsed,
  tooltipNavigation,
  expandedNavigation,
}: SidebarTooltipBoundaryProps) {
  const tabletRail = useSyncExternalStore(
    subscribeToTabletRail,
    getTabletRailSnapshot,
    getServerTabletRailSnapshot,
  );
  const tooltipMode = collapsed || tabletRail;

  return tooltipMode ? (
    <TooltipProvider>{tooltipNavigation}</TooltipProvider>
  ) : (
    expandedNavigation
  );
}
