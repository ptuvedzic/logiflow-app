import "server-only";

import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryResult } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { TrackingLocation } from "@/features/tracking/tracking-types";

const TRACKING_COLUMNS = "vehicle_id, shipment_id, latitude, longitude, speed, heading, route_progress, updated_at" as const;

function mapLocation(row: { vehicle_id:string;shipment_id:string;latitude:number;longitude:number;speed:number|null;heading:number|null;route_progress:number|null;updated_at:string }): TrackingLocation {
  return { vehicleId:row.vehicle_id,shipmentId:row.shipment_id,latitude:row.latitude,longitude:row.longitude,
    speed:row.speed,heading:row.heading,routeProgress:row.route_progress,updatedAt:row.updated_at };
}

export async function getAuthorizedTrackingLocations(): Promise<AuthBoundaryResult<readonly TrackingLocation[]>> {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok:false,error:{category:"inactive_profile",message:"Account is inactive."} };
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher" && profile.data.role !== "driver")
    return { ok:false,error:{category:"forbidden",message:"Access denied."} };
  const result = await client.from("vehicle_locations").select(TRACKING_COLUMNS).order("vehicle_id");
  if (result.error || result.data === null) return { ok:false,error:{category:"infrastructure",message:"Unable to verify account access."} };
  return { ok:true,data:result.data.map(mapLocation) };
}

export async function getOperationsTrackingLocations(): Promise<AuthBoundaryResult<readonly TrackingLocation[]>> {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok:false,error:{category:"inactive_profile",message:"Account is inactive."} };
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher") return { ok:false,error:{category:"forbidden",message:"Access denied."} };
  const result = await client.from("vehicle_locations").select(TRACKING_COLUMNS).order("vehicle_id");
  if (result.error || result.data === null) return { ok:false,error:{category:"infrastructure",message:"Unable to verify account access."} };
  return { ok:true,data:result.data.map(mapLocation) };
}
