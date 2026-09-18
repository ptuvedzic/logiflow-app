"use client";

import { useCallback, useEffect, useState, type ReactNode } from "react";

import { Drawer } from "@/components/ui/drawer";

const desktopMediaQuery = "(min-width: 768px)";

export type NavigationDrawerBoundaryProps = {
  children: ReactNode;
};

export function NavigationDrawerBoundary({
  children,
}: NavigationDrawerBoundaryProps) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia(desktopMediaQuery);

    function handleViewportChange(event: MediaQueryListEvent) {
      if (event.matches) {
        setOpen(false);
      }
    }

    mediaQuery.addEventListener("change", handleViewportChange);

    return () => {
      mediaQuery.removeEventListener("change", handleViewportChange);
    };
  }, []);

  const handleOpenChange = useCallback((nextOpen: boolean) => {
    if (nextOpen && window.matchMedia(desktopMediaQuery).matches) {
      return;
    }

    setOpen(nextOpen);
  }, []);

  return (
    <Drawer open={open} onOpenChange={handleOpenChange}>
      {children}
    </Drawer>
  );
}
