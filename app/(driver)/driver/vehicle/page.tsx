import { Truck } from "lucide-react";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { StatusBadge } from "@/components/ui/status-badge";
import { getAssignedDriverVehicle } from "@/lib/dal/vehicles";

export default async function DriverVehiclePage() {
  const result = await getAssignedDriverVehicle();

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  const vehicle = result.data;

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="Assigned Vehicle" />
      {vehicle === null ? (
        <EmptyState
          icon={Truck}
          title="No assigned vehicle"
          description="You do not have a vehicle assigned right now."
        />
      ) : (
        <Card
          header={
            <div className="flex min-w-0 flex-wrap items-center justify-between gap-2">
              <h2 className="min-w-0 break-words text-h3 text-foreground">
                {vehicle.registration}
              </h2>
              <StatusBadge domain="vehicle" status={vehicle.status} />
            </div>
          }
        >
          <dl className="grid min-w-0 gap-4 md:grid-cols-3">
            <div className="min-w-0">
              <dt className="text-label text-secondary">Make</dt>
              <dd className="mt-2 break-words text-body-medium text-foreground">
                {vehicle.make}
              </dd>
            </div>
            <div className="min-w-0">
              <dt className="text-label text-secondary">Model</dt>
              <dd className="mt-2 break-words text-body-medium text-foreground">
                {vehicle.model}
              </dd>
            </div>
            <div className="min-w-0">
              <dt className="text-label text-secondary">Vehicle type</dt>
              <dd className="mt-2 break-words text-body-medium text-foreground">
                {vehicle.vehicleType}
              </dd>
            </div>
          </dl>
        </Card>
      )}
    </div>
  );
}
