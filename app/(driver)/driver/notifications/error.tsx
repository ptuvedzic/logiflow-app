"use client";

import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/ui/error-state";

export default function DriverNotificationsError({ reset }: Readonly<{ error: Error & { digest?: string }; reset: () => void }>) {
  return (
    <ErrorState
      title="Unable to load notifications"
      description="Try loading your notifications again."
      retryAction={<Button onClick={reset}>Try again</Button>}
    />
  );
}
