import "server-only";

import type { ActivityListInput } from "@/features/activity/activity-schema";
import { requireProfileWithClient } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database, Json } from "@/types/database.generated";

export const ACTIVITY_PER_PAGE = 10;
type Action = Database["public"]["Enums"]["activity_action_type"];
type ReadError = { category: "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "infrastructure"; message: string };
type Result<T> = { ok: true; data: T } | { ok: false; error: ReadError };
type EntityType = ActivityListInput["entity"] extends "all" | infer T ? Exclude<T, "all"> : never;

export type ActivityListItem = Readonly<{
  id: string; action: Action; actionLabel: string; description: string; occurredAt: string;
  actorLabel: string; entityType: EntityType; entityLabel: string; entityHref: string | null;
}>;
export type ActivityListResult = Readonly<{ activities: readonly ActivityListItem[]; totalCount: number; totalPages: number }>;

const actionLabels: Record<Action, string> = {
  driver_created: "Driver created", driver_status_changed: "Driver status changed",
  client_created: "Client created", client_updated: "Client updated", client_archived: "Client archived", client_reactivated: "Client reactivated",
  vehicle_created: "Vehicle created", vehicle_updated: "Vehicle updated", vehicle_status_changed: "Vehicle status changed", vehicle_archived: "Vehicle archived",
  shipment_created: "Shipment created", shipment_updated: "Shipment updated", shipment_assigned: "Shipment assigned",
  shipment_status_changed: "Shipment status changed", shipment_delayed: "Shipment delayed", shipment_cancelled: "Shipment cancelled",
  status_request_created: "Status request created", status_request_approved: "Status request approved", status_request_rejected: "Status request rejected",
  document_uploaded: "Document uploaded", document_archived: "Document archived", document_restored: "Document restored",
  maintenance_record_created: "Maintenance recorded", maintenance_record_updated: "Maintenance updated",
  expense_created: "Expense created", expense_updated: "Expense updated", alert_created: "Alert created", alert_resolved: "Alert resolved",
  tracking_started: "Tracking started", tracking_stopped: "Tracking stopped",
};

function failure(): Result<never> { return { ok: false, error: { category: "infrastructure", message: "Unable to load activity." } }; }
function safeMetadata(metadata: Json | null): Record<string, string | number> {
  if (metadata === null || Array.isArray(metadata) || typeof metadata !== "object") return {};
  const allowed = new Set(["status", "from_status", "to_status", "requested_status", "operation", "field", "from", "to", "unit", "source", "alert_type", "delayed"]);
  return Object.fromEntries(Object.entries(metadata).filter(([key, value]) => allowed.has(key) && (typeof value === "string" || typeof value === "number"))) as Record<string, string | number>;
}
function description(action: Action, metadata: Json | null): string {
  const facts = safeMetadata(metadata);
  if (facts.from_status && facts.to_status) return `${actionLabels[action]} from ${String(facts.from_status).replaceAll("_", " ")} to ${String(facts.to_status).replaceAll("_", " ")}.`;
  if (facts.from_status && facts.requested_status) return `${actionLabels[action]} from ${String(facts.from_status).replaceAll("_", " ")} to ${String(facts.requested_status).replaceAll("_", " ")}.`;
  if (facts.field === "mileage" && facts.from !== undefined && facts.to !== undefined) return `Vehicle mileage changed from ${facts.from} to ${facts.to} ${facts.unit ?? "km"}.`;
  return `${actionLabels[action]}.`;
}

function addCalendarDay(date: string): string {
  const value = new Date(`${date}T12:00:00Z`);
  value.setUTCDate(value.getUTCDate() + 1);
  return value.toISOString().slice(0, 10);
}

function belgradeDayBoundary(date: string): string {
  const offsetPart = new Intl.DateTimeFormat("en-US", {
    timeZone: "Europe/Belgrade",
    timeZoneName: "longOffset",
  }).formatToParts(new Date(`${date}T12:00:00Z`)).find((part) => part.type === "timeZoneName")?.value;
  const offset = offsetPart?.replace("GMT", "") || "+01:00";
  return `${date}T00:00:00${offset}`;
}

export async function listActivity(input: ActivityListInput, pageSize = ACTIVITY_PER_PAGE): Promise<Result<ActivityListResult>> {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok: false, error: { category: "inactive_profile", message: "Account is inactive." } };
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher") return { ok: false, error: { category: "forbidden", message: "Access denied." } };
  let query = client.from("activity_logs").select("id, actor_profile_id, action_type, occurred_at, shipment_id, vehicle_id, driver_id, client_id, document_id, status_request_id, maintenance_record_id, expense_id, metadata", { count: "exact" });
  if (input.actor === "system") query = query.is("actor_profile_id", null);
  if (input.actor === "user") query = query.not("actor_profile_id", "is", null);
  if (input.action !== "all") query = query.eq("action_type", input.action);
  const entityColumns = { shipment: "shipment_id", status_request: "status_request_id", vehicle: "vehicle_id", driver: "driver_id", client: "client_id", document: "document_id", maintenance: "maintenance_record_id", expense: "expense_id" } as const;
  if (input.entity !== "all") query = query.not(entityColumns[input.entity], "is", null);
  if (input.from) query = query.gte("occurred_at", belgradeDayBoundary(input.from));
  if (input.to) query = query.lt("occurred_at", belgradeDayBoundary(addCalendarDay(input.to)));
  const start = (input.page - 1) * pageSize;
  const { data, error, count } = await query.order("occurred_at", { ascending: false }).order("id", { ascending: false }).range(start, start + pageSize - 1);
  if (error || data === null) return failure();

  const actorIds = data.flatMap((row) => row.actor_profile_id ? [row.actor_profile_id] : []);
  const driverIds = data.flatMap((row) => row.driver_id ? [row.driver_id] : []);
  const clientIds = data.flatMap((row) => row.client_id ? [row.client_id] : []);
  const [actorsResult, driversResult, clientsResult] = await Promise.all([
    actorIds.length ? client.from("profiles").select("id, full_name").in("id", actorIds) : Promise.resolve({ data: [], error: null }),
    driverIds.length ? client.from("drivers").select("id, profile_id").in("id", driverIds) : Promise.resolve({ data: [], error: null }),
    clientIds.length ? client.from("clients").select("id, company_name").in("id", clientIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (actorsResult.error || driversResult.error || clientsResult.error) return failure();
  const driverProfileIds = driversResult.data.map((row) => row.profile_id);
  const driverProfilesResult = driverProfileIds.length ? await client.from("profiles").select("id, full_name").in("id", driverProfileIds) : { data: [], error: null };
  if (driverProfilesResult.error) return failure();
  const actors = new Map(actorsResult.data.map((row) => [row.id, row.full_name]));
  const driverProfiles = new Map(driverProfilesResult.data.map((row) => [row.id, row.full_name]));
  const drivers = new Map(driversResult.data.map((row) => [row.id, driverProfiles.get(row.profile_id) ?? null]));
  const clients = new Map(clientsResult.data.map((row) => [row.id, row.company_name]));
  const totalCount = count ?? 0;
  return { ok: true, data: { activities: data.map((row) => {
    let entityType: EntityType = "expense"; let entityLabel = "Expense"; let entityHref: string | null = null;
    if (row.shipment_id) { entityType = "shipment"; entityLabel = "Shipment"; }
    else if (row.status_request_id) { entityType = "status_request"; entityLabel = "Shipment status request"; }
    else if (row.vehicle_id) { entityType = "vehicle"; entityLabel = "Vehicle"; }
    else if (row.driver_id) { entityType = "driver"; const value = drivers.get(row.driver_id); entityLabel = value ?? "Driver"; entityHref = value ? `/operations/drivers?search=${encodeURIComponent(value)}` : null; }
    else if (row.client_id) { entityType = "client"; const value = clients.get(row.client_id); entityLabel = value ?? "Client"; entityHref = value ? `/operations/clients?search=${encodeURIComponent(value)}` : null; }
    else if (row.document_id) { entityType = "document"; entityLabel = "Document"; }
    else if (row.maintenance_record_id) { entityType = "maintenance"; entityLabel = "Maintenance record"; }
    return { id: row.id, action: row.action_type, actionLabel: actionLabels[row.action_type], description: description(row.action_type, row.metadata), occurredAt: row.occurred_at, actorLabel: row.actor_profile_id === null ? "System" : (actors.get(row.actor_profile_id) ?? "Operations user"), entityType, entityLabel, entityHref };
  }), totalCount, totalPages: Math.ceil(totalCount / pageSize) } };
}
