"use client";

import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/ui/error-state";

export default function AdminReportsError({ unstable_retry }: Readonly<{ unstable_retry: () => void }>) {
  return <ErrorState title="Reports unavailable" description="Admin Reports could not be loaded. No values have been assumed." retryAction={<Button onClick={unstable_retry}>Try again</Button>} />;
}
