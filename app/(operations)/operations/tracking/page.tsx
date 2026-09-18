import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PageHeader } from "@/components/ui/page-header";
import { LiveTrackingMap } from "@/features/tracking/live-tracking-map";
import { getOperationsTrackingLocations } from "@/lib/dal/tracking";
import { publicEnv } from "@/lib/env";

export default async function OperationsTrackingPage() {
  const result = await getOperationsTrackingLocations();
  if (!result.ok) handleAuthBoundaryFailure(result.error);
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Tracking" description="Monitor active in-transit Shipments." />
    <LiveTrackingMap initialLocations={result.data} mapStyleUrl={publicEnv.NEXT_PUBLIC_MAP_STYLE_URL} routeUrl={publicEnv.NEXT_PUBLIC_TRACKING_ROUTE_GEOJSON_URL} />
  </div>;
}
