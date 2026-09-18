import "server-only";

import type { MaintenanceCreateInput, MaintenanceEditInput, MaintenanceListInput } from "@/features/maintenance/maintenance-schema";
import { createClient } from "@/lib/supabase/server";

export const MAINTENANCE_PER_PAGE = 10;
export type MaintenanceVehicleOption = Readonly<{ id: string; registration: string }>;
export type MaintenanceListItem = Readonly<{
  id: string; vehicleRegistration: string; serviceType: string; serviceDate: string;
  mileageAtService: number; workshop: string | null; cost: number | null;
  nextServiceDate: string | null; nextServiceMileage: number | null;
}>;
export type MaintenanceRecord = MaintenanceListItem & Readonly<{
  vehicleId: string; notes: string | null; createdAt: string; updatedAt: string;
}>;
export type MaintenanceListResult = Readonly<{ records: readonly MaintenanceListItem[]; totalCount: number; totalPages: number }>;
type MaintenanceError = { category: "forbidden" | "not_found" | "conflict" | "business_rule" | "infrastructure"; message: string };
export type MaintenanceResult<T> = { ok: true; data: T } | { ok: false; error: MaintenanceError };

function errorFor(message: string): MaintenanceError {
  if (message.includes("maintenance_read_access_denied") || message.includes("maintenance_mutation_access_denied")) return { category: "forbidden", message: "Access denied." };
  if (message.includes("maintenance_vehicle_not_found")) return { category: "not_found", message: "Vehicle unavailable." };
  if (message.includes("maintenance_record_not_found")) return { category: "not_found", message: "Maintenance record unavailable." };
  if (message.includes("maintenance_record_stale") || message.includes("maintenance_record_vehicle_changed")) return { category: "conflict", message: "Maintenance record changed since you opened this form. Reload and try again." };
  if (message.includes("maintenance_validation_failed") || message.includes("maintenance_list_invalid")) return { category: "business_rule", message: "Check the maintenance details and try again." };
  return { category: "infrastructure", message: "Unable to manage maintenance records right now." };
}

export async function listMaintenanceRecords(input: MaintenanceListInput): Promise<MaintenanceResult<MaintenanceListResult>> {
  const client = await createClient();
  const args = { search_text: input.search, vehicle_filter: input.vehicle === "all" ? undefined : input.vehicle, service_date_from: input.from || undefined, service_date_to: input.to || undefined, requested_page: input.page };
  const { data, error } = await client.rpc("list_operations_maintenance", args);
  if (error) return { ok: false, error: errorFor(error.message) };
  let totalCount = Number(data[0]?.total_count ?? 0);
  if (data.length === 0 && input.page > 1) {
    const first = await client.rpc("list_operations_maintenance", { ...args, requested_page: 1 });
    if (first.error) return { ok: false, error: errorFor(first.error.message) };
    totalCount = Number(first.data[0]?.total_count ?? 0);
  }
  return { ok: true, data: { records: data.map((row) => ({ id: row.id, vehicleRegistration: row.vehicle_registration, serviceType: row.service_type, serviceDate: row.service_date, mileageAtService: row.mileage_at_service, workshop: row.workshop, cost: row.cost, nextServiceDate: row.next_service_date, nextServiceMileage: row.next_service_mileage })), totalCount, totalPages: Math.ceil(totalCount / MAINTENANCE_PER_PAGE) } };
}

export async function listMaintenanceVehicleOptions(): Promise<MaintenanceResult<readonly MaintenanceVehicleOption[]>> {
  const client = await createClient(); const { data, error } = await client.rpc("list_maintenance_vehicle_options");
  return error ? { ok: false, error: errorFor(error.message) } : { ok: true, data: data.map((row) => ({ id: row.id, registration: row.registration })) };
}

export async function getMaintenanceRecordForEdit(id: string): Promise<MaintenanceResult<MaintenanceRecord>> {
  const client = await createClient(); const { data, error } = await client.rpc("get_operations_maintenance_for_edit", { target_maintenance_record_id: id });
  if (error) return { ok: false, error: errorFor(error.message) }; const row = data[0];
  if (!row) return { ok: false, error: { category: "not_found", message: "Maintenance record unavailable." } };
  return { ok: true, data: { id: row.id, vehicleId: row.vehicle_id, vehicleRegistration: row.vehicle_registration, serviceType: row.service_type, serviceDate: row.service_date, mileageAtService: row.mileage_at_service, workshop: row.workshop, cost: row.cost, notes: row.notes, nextServiceDate: row.next_service_date, nextServiceMileage: row.next_service_mileage, createdAt: row.created_at, updatedAt: row.updated_at } };
}

const mutationArgs = (input: MaintenanceCreateInput | MaintenanceEditInput) => ({ input_service_type: input.serviceType, input_service_date: input.serviceDate, input_mileage_at_service: input.mileageAtService, input_workshop: input.workshop ?? undefined, input_cost: input.cost ?? undefined, input_notes: input.notes ?? undefined, input_next_service_date: input.nextServiceDate ?? undefined, input_next_service_mileage: input.nextServiceMileage ?? undefined });
export async function createMaintenanceRecord(input: MaintenanceCreateInput): Promise<MaintenanceResult<string>> {
  const client = await createClient(); const { data, error } = await client.rpc("create_maintenance_record", { target_vehicle_id: input.vehicleId, ...mutationArgs(input) });
  return error ? { ok: false, error: errorFor(error.message) } : { ok: true, data };
}
export async function updateMaintenanceRecord(input: MaintenanceEditInput): Promise<MaintenanceResult<"updated" | "noop">> {
  const client = await createClient(); const { data, error } = await client.rpc("update_maintenance_record", { target_maintenance_record_id: input.maintenanceRecordId, expected_updated_at: input.expectedUpdatedAt, ...mutationArgs(input) });
  return error ? { ok: false, error: errorFor(error.message) } : { ok: true, data: data === "noop" ? "noop" : "updated" };
}
