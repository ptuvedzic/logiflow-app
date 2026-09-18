import "server-only";

import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryResult } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";
import type { VehicleCreateInput, VehicleEditInput, VehicleLifecycleInput, VehicleMileageInput, VehicleStatus } from "@/features/vehicles/vehicle-schema";

export type AssignedDriverVehicle = Readonly<{
  registration: string;
  make: string;
  model: string;
  vehicleType: string;
  status: Database["public"]["Enums"]["vehicle_status"];
}>;

const CURRENT_SHIPMENT_STATUSES = [
  "assigned",
  "loading",
  "in_transit",
] as const satisfies readonly Database["public"]["Enums"]["shipment_status"][];

export async function getAssignedDriverVehicle(): Promise<
  AuthBoundaryResult<AssignedDriverVehicle | null>
> {
  const client = await createClient();
  const profileResult = await requireProfileWithClient(client);

  if (!profileResult.ok) {
    return profileResult;
  }

  if (!profileResult.data.isActive) {
    return {
      ok: false,
      error: {
        category: "inactive_profile",
        message: "Account is inactive.",
      },
    };
  }

  if (profileResult.data.role !== "driver") {
    return {
      ok: false,
      error: {
        category: "forbidden",
        message: "Access denied.",
      },
    };
  }

  const { data: driver, error: driverError } = await client
    .from("drivers")
    .select("id")
    .eq("profile_id", profileResult.data.id)
    .maybeSingle();

  if (driverError) {
    return infrastructureFailure();
  }

  if (driver === null) {
    return {
      ok: false,
      error: {
        category: "missing_profile",
        message: "Account profile unavailable.",
      },
    };
  }

  const { data: shipments, error: shipmentError } = await client
    .from("shipments")
    .select("vehicle_id")
    .eq("driver_id", driver.id)
    .in("status", [...CURRENT_SHIPMENT_STATUSES])
    .limit(2);

  if (shipmentError || shipments === null || shipments.length > 1) {
    return infrastructureFailure();
  }

  const shipment = shipments[0];

  if (shipment === undefined) {
    return { ok: true, data: null };
  }

  if (shipment.vehicle_id === null) {
    return infrastructureFailure();
  }

  const { data: vehicle, error: vehicleError } = await client
    .from("vehicles")
    .select("id, registration, make, model, vehicle_type, status")
    .eq("id", shipment.vehicle_id)
    .maybeSingle();

  if (vehicleError || vehicle === null) {
    return infrastructureFailure();
  }

  return {
    ok: true,
    data: {
      registration: vehicle.registration,
      make: vehicle.make,
      model: vehicle.model,
      vehicleType: vehicle.vehicle_type,
      status: vehicle.status,
    },
  };
}

function infrastructureFailure(): AuthBoundaryResult<never> {
  return {
    ok: false,
    error: {
      category: "infrastructure",
      message: "Unable to verify account access.",
    },
  };
}

export const VEHICLES_PER_PAGE = 10;
export type VehicleListInput = Readonly<{ search: string; status: "all" | VehicleStatus; type: string; page: number }>;
export type VehicleListItem = Readonly<{ id: string; registration: string; make: string; model: string; vehicleType: string; mileage: number; status: VehicleStatus }>;
export type VehicleRecord = VehicleListItem & Readonly<{ vin: string | null; fuelType: string | null; firstRegistrationDate: string | null; updatedAt: string }>;
export type VehicleListResult = Readonly<{ vehicles: readonly VehicleListItem[]; totalCount: number; totalPages: number }>;
type VehicleError = { category: "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden" | "not_found" | "conflict" | "business_rule" | "infrastructure"; message: string };
export type VehicleResult<T> = { ok: true; data: T } | { ok: false; error: VehicleError };

function vehicleError(message: string): VehicleError {
  if (message.includes("vehicle_read_access_denied") || message.includes("vehicle_mutation_access_denied")) return { category: "forbidden", message: "Access denied." };
  if (message.includes("vehicle_not_found")) return { category: "not_found", message: "Vehicle unavailable." };
  if (message.includes("vehicle_stale")) return { category: "conflict", message: "Vehicle changed since you opened this form. Reload and try again." };
  if (message.includes("vehicle_mileage_decrease")) return { category: "business_rule", message: "Mileage cannot be lower than the current mileage." };
  if (message.includes("vehicle_active_shipment")) return { category: "business_rule", message: "This Vehicle has an active shipment and cannot change status." };
  if (message.includes("vehicle_transition_invalid")) return { category: "conflict", message: "This Vehicle action is no longer available." };
  if (message.includes("vehicles_registration_lower_key")) return { category: "business_rule", message: "A Vehicle with this registration already exists." };
  if (message.includes("vehicles_vin_key")) return { category: "business_rule", message: "A Vehicle with this VIN already exists." };
  return { category: "infrastructure", message: "Unable to manage Vehicles right now." };
}

export async function listVehicles(input: VehicleListInput): Promise<VehicleResult<VehicleListResult>> {
  const client = await createClient();
  const { data, error } = await client.rpc("list_operations_vehicles", { search_text: input.search, status_filter: input.status, type_filter: input.type, requested_page: input.page });
  if (error) return { ok: false, error: vehicleError(error.message) };
  let totalCount = Number(data[0]?.total_count ?? 0);
  if (data.length === 0 && input.page > 1) {
    const countResult = await client.rpc("list_operations_vehicles", { search_text: input.search, status_filter: input.status, type_filter: input.type, requested_page: 1 });
    if (countResult.error) return { ok: false, error: vehicleError(countResult.error.message) };
    totalCount = Number(countResult.data[0]?.total_count ?? 0);
  }
  return { ok: true, data: { vehicles: data.map((row) => ({ id: row.id, registration: row.registration, make: row.make, model: row.model, vehicleType: row.vehicle_type, mileage: row.mileage, status: row.status })), totalCount, totalPages: Math.ceil(totalCount / VEHICLES_PER_PAGE) } };
}

export async function listVehicleTypes(): Promise<VehicleResult<readonly string[]>> {
  const client = await createClient();
  const { data, error } = await client.rpc("list_operations_vehicle_types");
  return error ? { ok: false, error: vehicleError(error.message) } : { ok: true, data: data.map((row) => row.vehicle_type) };
}

export async function getVehicleForEdit(vehicleId: string): Promise<VehicleResult<VehicleRecord>> {
  const client = await createClient();
  const { data, error } = await client.rpc("get_operations_vehicle_for_edit", { target_vehicle_id: vehicleId });
  if (error) return { ok: false, error: vehicleError(error.message) };
  const row = data[0];
  if (!row) return { ok: false, error: { category: "not_found", message: "Vehicle unavailable." } };
  return { ok: true, data: { id: row.id, registration: row.registration, make: row.make, model: row.model, vehicleType: row.vehicle_type, mileage: row.mileage, status: row.status, vin: row.vin, fuelType: row.fuel_type, firstRegistrationDate: row.first_registration_date, updatedAt: row.updated_at } };
}

export async function createVehicleRecord(input: VehicleCreateInput): Promise<VehicleResult<string>> {
  const client = await createClient();
  const { data, error } = await client.rpc("create_vehicle", { input_registration: input.registration, input_make: input.make, input_model: input.model, input_vehicle_type: input.vehicleType, input_vin: input.vin ?? undefined, input_mileage: input.mileage, input_fuel_type: input.fuelType ?? undefined, input_first_registration_date: input.firstRegistrationDate ?? undefined });
  return error ? { ok: false, error: vehicleError(error.message) } : { ok: true, data };
}

export async function updateVehicleMasterData(input: VehicleEditInput): Promise<VehicleResult<"updated" | "noop">> {
  const client = await createClient();
  const { data, error } = await client.rpc("update_vehicle_master_data", { target_vehicle_id: input.vehicleId, expected_updated_at: input.expectedUpdatedAt, input_registration: input.registration, input_make: input.make, input_model: input.model, input_vehicle_type: input.vehicleType, input_vin: input.vin ?? undefined, input_fuel_type: input.fuelType ?? undefined, input_first_registration_date: input.firstRegistrationDate ?? undefined });
  return error ? { ok: false, error: vehicleError(error.message) } : { ok: true, data: data === "noop" ? "noop" : "updated" };
}

export async function updateVehicleMileage(input: VehicleMileageInput): Promise<VehicleResult<"updated" | "noop">> {
  const client = await createClient();
  const { data, error } = await client.rpc("update_vehicle_mileage", { target_vehicle_id: input.vehicleId, expected_updated_at: input.expectedUpdatedAt, new_mileage: input.mileage });
  return error ? { ok: false, error: vehicleError(error.message) } : { ok: true, data: data === "noop" ? "noop" : "updated" };
}

export async function changeVehicleOperationalStatus(input: VehicleLifecycleInput): Promise<VehicleResult<VehicleStatus>> {
  const client = await createClient();
  const { data, error } = await client.rpc("change_vehicle_operational_status", { target_vehicle_id: input.vehicleId, requested_operation: input.operation });
  return error ? { ok: false, error: vehicleError(error.message) } : { ok: true, data };
}
