import "server-only";

import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryError } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

type ShipmentStatus = Database["public"]["Enums"]["shipment_status"];
type DashboardError = AuthBoundaryError | { category: "infrastructure"; message: string };
type DashboardResult<T> = { ok: true; data: T } | { ok: false; error: DashboardError };

export type OperationsDashboardKpis = Readonly<{
  activeShipments: number;
  inUseVehicles: number;
  assignedDrivers: number;
  activeAlerts: number;
}>;

export type DashboardPendingStatusRequest = Readonly<{
  id: string;
  trackingNumber: string;
  driverName: string;
  currentStatus: ShipmentStatus;
  requestedStatus: ShipmentStatus;
  requestedAt: string;
}>;

export type OperationsDashboardSnapshot = Readonly<{
  kpis: DashboardResult<OperationsDashboardKpis>;
  pendingStatusRequests: DashboardResult<readonly DashboardPendingStatusRequest[]>;
}>;

export async function getOperationsDashboardSnapshot(): Promise<DashboardResult<OperationsDashboardSnapshot>> {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);

  if (!profile.ok) return profile;
  if (!profile.data.isActive) {
    return { ok: false, error: { category: "inactive_profile", message: "Account is inactive." } };
  }
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher") {
    return { ok: false, error: { category: "forbidden", message: "Access denied." } };
  }

  const [kpiResponse, requestsResponse] = await Promise.all([
    client.rpc("get_operations_dashboard_kpis"),
    client.rpc("list_operations_dashboard_pending_status_requests", { preview_limit: 5 }),
  ]);
  const kpi = kpiResponse.data?.[0];
  const infrastructureError = { category: "infrastructure" as const, message: "Unable to load the dashboard overview." };

  return {
    ok: true,
    data: {
      kpis: kpiResponse.error || kpi === undefined
        ? { ok: false, error: infrastructureError }
        : { ok: true, data: { activeShipments: Number(kpi.active_shipments), inUseVehicles: Number(kpi.in_use_vehicles), assignedDrivers: Number(kpi.assigned_drivers), activeAlerts: Number(kpi.active_alerts) } },
      pendingStatusRequests: requestsResponse.error || requestsResponse.data === null
        ? { ok: false, error: infrastructureError }
        : { ok: true, data: requestsResponse.data.map((row) => ({ id: row.id, trackingNumber: row.tracking_number, driverName: row.driver_name, currentStatus: row.current_status, requestedStatus: row.requested_status, requestedAt: row.requested_at })) },
    },
  };
}
