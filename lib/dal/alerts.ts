import "server-only";

import type { AlertListInput } from "@/features/alerts/alert-schema";
import { requireProfileWithClient } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export const ALERTS_PER_PAGE = 10;
type AlertType = Database["public"]["Enums"]["alert_type"];
type AlertSeverity = Database["public"]["Enums"]["alert_severity"];
type AlertState = Database["public"]["Enums"]["alert_state"];
type ReadError = { category: "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure"; message: string };
type Result<T> = { ok: true; data: T } | { ok: false; error: ReadError };

export type AlertListItem = Readonly<{
  id: string;
  type: AlertType;
  severity: AlertSeverity;
  message: string;
  state: AlertState;
  entityLabel: string;
  entityHref: string | null;
  createdAt: string;
  resolvedAt: string | null;
  resolverLabel: string | null;
}>;

export type AlertListResult = Readonly<{ alerts: readonly AlertListItem[]; totalCount: number; totalPages: number }>;

function failure(): Result<never> {
  return { ok: false, error: { category: "infrastructure", message: "Unable to load alerts." } };
}

export async function listAlerts(input: AlertListInput, pageSize = ALERTS_PER_PAGE): Promise<Result<AlertListResult>> {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok: false, error: { category: "inactive_profile", message: "Account is inactive." } };
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher") return { ok: false, error: { category: "forbidden", message: "Access denied." } };

  let query = client.from("alerts").select(
    "id, alert_type, severity, message, alert_state, shipment_id, vehicle_id, driver_id, document_id, created_at, resolved_at, resolved_by_profile_id",
    { count: "exact" },
  );
  if (input.search) query = query.ilike("message", `%${input.search}%`);
  if (input.state !== "all") query = query.eq("alert_state", input.state);
  if (input.severity !== "all") query = query.eq("severity", input.severity);
  if (input.type !== "all") query = query.eq("alert_type", input.type);
  if (input.entity !== "all") query = query.not(`${input.entity}_id`, "is", null);
  const start = (input.page - 1) * pageSize;
  const { data, error, count } = await query.order("created_at", { ascending: false }).order("id", { ascending: false }).range(start, start + pageSize - 1);
  if (error || data === null) return failure();

  const driverIds = data.flatMap((row) => row.driver_id ? [row.driver_id] : []);
  const resolverIds = data.flatMap((row) => row.resolved_by_profile_id ? [row.resolved_by_profile_id] : []);
  const [driversResult, resolversResult] = await Promise.all([
    driverIds.length ? client.from("drivers").select("id, profile_id").in("id", driverIds) : Promise.resolve({ data: [], error: null }),
    resolverIds.length ? client.from("profiles").select("id, full_name").in("id", resolverIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (driversResult.error || resolversResult.error) return failure();
  const driverProfileIds = driversResult.data.flatMap((row) => row.profile_id ? [row.profile_id] : []);
  const driverProfilesResult = driverProfileIds.length
    ? await client.from("profiles").select("id, full_name").in("id", driverProfileIds)
    : { data: [], error: null };
  if (driverProfilesResult.error) return failure();

  const driverProfiles = new Map(driverProfilesResult.data.map((row) => [row.id, row.full_name]));
  const drivers = new Map(driversResult.data.map((row) => [row.id, driverProfiles.get(row.profile_id) ?? null]));
  const resolvers = new Map(resolversResult.data.map((row) => [row.id, row.full_name]));
  const totalCount = count ?? 0;

  return {
    ok: true,
    data: {
      alerts: data.map((row) => {
        let entityLabel = "Document";
        let entityHref: string | null = null;
        if (row.shipment_id) entityLabel = "Shipment";
        else if (row.vehicle_id) entityLabel = "Vehicle";
        else if (row.driver_id) {
          const name = drivers.get(row.driver_id);
          entityLabel = name ?? "Driver";
          entityHref = name ? `/operations/drivers?search=${encodeURIComponent(name)}` : null;
        }
        return {
          id: row.id, type: row.alert_type, severity: row.severity, message: row.message,
          state: row.alert_state, entityLabel, entityHref, createdAt: row.created_at,
          resolvedAt: row.resolved_at,
          resolverLabel: row.alert_state === "active" ? null : row.resolved_by_profile_id === null ? "System" : (resolvers.get(row.resolved_by_profile_id) ?? "Operations user"),
        };
      }),
      totalCount,
      totalPages: Math.ceil(totalCount / pageSize),
    },
  };
}
