import "server-only";

import type { DriverOperationInput, DriverPhoneEditInput, DriverStatus } from "@/features/drivers/driver-schema";
import { requireProfileWithClient, type AuthBoundaryError } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";

export const DRIVERS_PER_PAGE = 10;

export type DriverListInput = Readonly<{
  search: string;
  status: "all" | DriverStatus;
  account: "all" | "active" | "inactive";
  page: number;
}>;
export type DriverListItem = Readonly<{
  id: string;
  fullName: string;
  username: string;
  phone: string | null;
  accountActive: boolean;
  status: DriverStatus;
}>;
export type DriverRecord = DriverListItem & Readonly<{ updatedAt: string }>;
export type DriverListResult = Readonly<{ drivers: readonly DriverListItem[]; totalCount: number; totalPages: number }>;

type DriverError = AuthBoundaryError
  | { category: "not_found"; message: string }
  | { category: "conflict"; message: string }
  | { category: "business_rule"; message: string }
  | { category: "infrastructure"; message: string };
export type DriverResult<T> = { ok: true; data: T } | { ok: false; error: DriverError };

async function authorizedOperationsClient(adminOnly = false) {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return profile;
  if (!profile.data.isActive) return { ok: false as const, error: { category: "inactive_profile" as const, message: "Account is inactive." as const } };
  if (adminOnly ? profile.data.role !== "admin" : profile.data.role !== "admin" && profile.data.role !== "dispatcher") {
    return { ok: false as const, error: { category: "forbidden" as const, message: "Access denied." as const } };
  }
  return { ok: true as const, client, profile: profile.data };
}

type DriverRow = {
  id: string;
  phone: string | null;
  status: DriverStatus;
  updated_at: string;
  profiles: { full_name: string; username: string; is_active: boolean };
};

function mapRow(row: DriverRow): DriverRecord {
  return { id: row.id, fullName: row.profiles.full_name, username: row.profiles.username, phone: row.phone, accountActive: row.profiles.is_active, status: row.status, updatedAt: row.updated_at };
}

function quotedSearch(value: string) { return value.replaceAll("\\", "\\\\").replaceAll('"', '\\"'); }

export async function listDrivers(input: DriverListInput): Promise<DriverResult<DriverListResult>> {
  const auth = await authorizedOperationsClient();
  if (!auth.ok) return auth;
  let query = auth.client.from("drivers").select("id, phone, status, updated_at, profiles!inner(full_name, username, is_active)", { count: "exact" });
  if (input.search !== "") {
    const search = quotedSearch(input.search);
    query = query.or(`full_name.ilike."%${search}%",username.ilike."%${search}%"`, { referencedTable: "profiles" });
  }
  if (input.status !== "all") query = query.eq("status", input.status);
  if (input.account !== "all") query = query.eq("profiles.is_active", input.account === "active");
  const from = (input.page - 1) * DRIVERS_PER_PAGE;
  const { data, error, count } = await query
    .order("full_name", { ascending: true, referencedTable: "profiles" })
    .order("username", { ascending: true, referencedTable: "profiles" })
    .order("id", { ascending: true })
    .range(from, from + DRIVERS_PER_PAGE - 1);
  if (error || count === null) return { ok: false, error: { category: "infrastructure", message: "Unable to load drivers right now." } };
  return { ok: true, data: { drivers: data.map((row) => mapRow(row as DriverRow)), totalCount: count, totalPages: Math.ceil(count / DRIVERS_PER_PAGE) } };
}

export async function getDriver(driverId: string, adminOnly = false): Promise<DriverResult<DriverRecord>> {
  const auth = await authorizedOperationsClient(adminOnly);
  if (!auth.ok) return auth;
  const { data, error } = await auth.client.from("drivers").select("id, phone, status, updated_at, profiles!inner(full_name, username, is_active)").eq("id", driverId).maybeSingle();
  if (error) return { ok: false, error: { category: "infrastructure", message: "Unable to load the driver right now." } };
  if (!data) return { ok: false, error: { category: "not_found", message: "Driver unavailable." } };
  return { ok: true, data: mapRow(data as DriverRow) };
}

function mutationError(message: string): DriverError {
  if (message.includes("driver_status_active_shipment")) return { category: "business_rule", message: "This Driver has an active shipment and cannot change operational status." };
  if (message.includes("driver_status_transition_invalid")) return { category: "conflict", message: "Driver status changed before this action could be completed." };
  if (message.includes("driver_target_unavailable")) return { category: "not_found", message: "Driver unavailable." };
  if (message.includes("driver_status_access_denied") || message.includes("driver_phone_access_denied")) return { category: "forbidden", message: "Access denied." };
  return { category: "infrastructure", message: "Unable to manage the driver right now." };
}

export async function updateDriverPhone(input: DriverPhoneEditInput): Promise<DriverResult<"updated" | "noop">> {
  const auth = await authorizedOperationsClient(true);
  if (!auth.ok) return auth;
  const current = await getDriver(input.driverId, true);
  if (!current.ok) return current;
  if (!current.data.accountActive) return { ok: false, error: { category: "conflict", message: "Inactive Driver accounts are read-only." } };
  if (current.data.updatedAt !== input.expectedUpdatedAt) return { ok: false, error: { category: "conflict", message: "Driver changed since you opened this form. Reload and try again." } };
  if (current.data.phone === input.phone) return { ok: true, data: "noop" };
  const { data, error } = await auth.client.from("drivers").update({ phone: input.phone }).eq("id", input.driverId).eq("updated_at", input.expectedUpdatedAt).select("id").maybeSingle();
  if (error) return { ok: false, error: mutationError(error.message) };
  if (!data) return { ok: false, error: { category: "conflict", message: "Driver changed since you opened this form. Reload and try again." } };
  return { ok: true, data: "updated" };
}

export async function changeDriverOperationalStatus(input: DriverOperationInput): Promise<DriverResult<DriverStatus>> {
  const auth = await authorizedOperationsClient(true);
  if (!auth.ok) return auth;
  const { data, error } = await auth.client.rpc("change_driver_operational_status", { target_driver_id: input.driverId, requested_operation: input.operation });
  if (error) return { ok: false, error: mutationError(error.message) };
  return { ok: true, data };
}
