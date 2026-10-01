"use client";

import { Button } from "@/components/ui/button";
import { ErrorState } from "@/components/ui/error-state";

export default function ShipmentDetailError({ reset }: Readonly<{ reset: () => void }>) {
  return <ErrorState title="Shipment details unavailable" description="Shipment financial details could not be loaded." retryAction={<Button onClick={reset}>Try again</Button>} />;
}
