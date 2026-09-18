import { PackageOpen } from "lucide-react";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { StatusBadge } from "@/components/ui/status-badge";
import { DriverStatusRequest } from "@/features/shipments/driver-status-request";
import { getCurrentDriverShipment } from "@/lib/dal/shipments";
import { LiveTrackingMap } from "@/features/tracking/live-tracking-map";
import { publicEnv } from "@/lib/env";

export default async function DriverShipmentsPage() {
  const result = await getCurrentDriverShipment();

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  const shipment = result.data;

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="My Shipments" />
      {shipment === null ? (
        <EmptyState
          icon={PackageOpen}
          title="No current shipment"
          description="You do not have a shipment assigned right now."
        />
      ) : (
        <Card
          header={
            <div className="flex min-w-0 flex-wrap items-center justify-between gap-2">
              <h2 className="min-w-0 break-words text-h3 text-foreground">
                {shipment.reference}
              </h2>
              <div className="flex flex-wrap items-center gap-2"><StatusBadge domain="shipment" status={shipment.status} />{shipment.delayed ? <StatusBadge domain="shipment_condition" status="delayed" /> : null}</div>
            </div>
          }
        >
          <dl className="grid min-w-0 gap-4 md:grid-cols-2">
            <div className="min-w-0">
              <dt className="text-label text-secondary">Pickup</dt>
              <dd className="mt-2 break-words text-body-medium text-foreground">
                {shipment.pickupAddress}
              </dd>
            </div>
            <div className="min-w-0">
              <dt className="text-label text-secondary">Delivery</dt>
              <dd className="mt-2 break-words text-body-medium text-foreground">
                {shipment.deliveryAddress}
              </dd>
            </div>
          </dl>
          <DriverStatusRequest shipment={shipment} />
        </Card>
      )}
      {shipment?.status === "in_transit" ? (
        <LiveTrackingMap
          initialLocations={shipment.trackingLocation === null ? [] : [shipment.trackingLocation]}
          mapStyleUrl={publicEnv.NEXT_PUBLIC_MAP_STYLE_URL}
          routeUrl={publicEnv.NEXT_PUBLIC_TRACKING_ROUTE_GEOJSON_URL}
          vehicleFilter={shipment.vehicleId}
        />
      ) : null}
    </div>
  );
}
