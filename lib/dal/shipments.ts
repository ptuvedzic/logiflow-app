import "server-only";

import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryResult } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";
import type { TrackingLocation } from "@/features/tracking/tracking-types";
import type { ShipmentAssignmentInput, ShipmentCreateInput, ShipmentDelayInput, ShipmentEditInput, ShipmentListInput, ShipmentRequestedStatus } from "@/features/shipments/shipment-schema";

type ShipmentStatus = Database["public"]["Enums"]["shipment_status"];
type StatusRequestState = Database["public"]["Enums"]["status_request_state"];

export type DriverShipmentStatusRequest = Readonly<{
  state: StatusRequestState;
  currentStatus: ShipmentStatus;
  requestedStatus: ShipmentStatus;
  requestedAt: string;
  resolvedAt: string | null;
  rejectionReason: string | null;
}>;

export type CurrentDriverShipment = Readonly<{
  reference: string;
  status: Database["public"]["Enums"]["shipment_status"];
  delayed: boolean;
  pickupAddress: string;
  deliveryAddress: string;
  vehicleId: string;
  trackingLocation: TrackingLocation | null;
  statusRequest: DriverShipmentStatusRequest | null;
}>;

const CURRENT_SHIPMENT_STATUSES = [
  "assigned",
  "loading",
  "in_transit",
] as const satisfies readonly Database["public"]["Enums"]["shipment_status"][];

export async function getCurrentDriverShipment(): Promise<
  AuthBoundaryResult<CurrentDriverShipment | null>
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
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
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

  const [shipmentResponse, requestResponse] = await Promise.all([
    client
      .from("shipments")
      .select("id, tracking_number, status, delayed, pickup_address, delivery_address, vehicle_id")
      .eq("driver_id", driver.id)
      .in("status", [...CURRENT_SHIPMENT_STATUSES])
      .limit(2),
    client.rpc("get_current_driver_status_request"),
  ]);
  const { data: shipments, error: shipmentError } = shipmentResponse;

  if (shipmentError || shipments === null || shipments.length > 1 || requestResponse.error || requestResponse.data === null) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  const shipment = shipments[0];

  if (shipment === undefined) {
    return { ok: true, data: null };
  }

  if (shipment.vehicle_id === null) {
    return { ok: false, error: { category: "infrastructure", message: "Unable to verify account access." } };
  }

  const locationResponse = shipment.status === "in_transit"
    ? await client.from("vehicle_locations")
        .select("vehicle_id, shipment_id, latitude, longitude, speed, heading, route_progress, updated_at")
        .eq("shipment_id", shipment.id).eq("vehicle_id", shipment.vehicle_id).maybeSingle()
    : { data: null, error: null };
  if (locationResponse.error) {
    return { ok: false, error: { category: "infrastructure", message: "Unable to verify account access." } };
  }
  const location = locationResponse.data;

  return {
    ok: true,
    data: {
      reference: shipment.tracking_number,
      status: shipment.status,
      delayed: shipment.delayed,
      pickupAddress: shipment.pickup_address,
      deliveryAddress: shipment.delivery_address,
      vehicleId: shipment.vehicle_id,
      trackingLocation: location === null ? null : {
        vehicleId: location.vehicle_id, shipmentId: location.shipment_id, latitude: location.latitude,
        longitude: location.longitude, speed: location.speed, heading: location.heading,
        routeProgress: location.route_progress, updatedAt: location.updated_at,
      },
      statusRequest: requestResponse.data[0] === undefined ? null : {
        state: requestResponse.data[0].request_state,
        currentStatus: requestResponse.data[0].current_status,
        requestedStatus: requestResponse.data[0].requested_status,
        requestedAt: requestResponse.data[0].requested_at,
        resolvedAt: requestResponse.data[0].resolved_at,
        rejectionReason: requestResponse.data[0].rejection_reason,
      },
    },
  };
}

export const SHIPMENTS_PER_PAGE = 10;
type ShipmentError = { category: "unauthenticated"|"missing_profile"|"inactive_profile"|"forbidden"|"not_found"|"conflict"|"business_rule"|"infrastructure"; message: string };
export type ShipmentResult<T> = {ok:true;data:T}|{ok:false;error:ShipmentError};
export type ShipmentListItem = Readonly<{id:string;trackingNumber:string;clientCompany:string;pickupAddress:string;deliveryAddress:string;driverName:string|null;vehicleRegistration:string|null;status:ShipmentStatus;delayed:boolean;updatedAt:string}>;
export type ShipmentListResult = Readonly<{shipments:readonly ShipmentListItem[];totalCount:number;totalPages:number}>;
export type ShipmentCandidateData = Readonly<{clients:readonly {id:string;companyName:string}[];drivers:readonly {id:string;displayName:string}[];vehicles:readonly {id:string;registration:string;make:string;model:string}[]}>;
export type ShipmentEditRecord = Readonly<{id:string;trackingNumber:string;pickupAddress:string;deliveryAddress:string;pickupAt:string;expectedDeliveryAt:string;cargoType:string;price:number;status:ShipmentStatus;updatedAt:string}>;
export type PendingStatusRequest = Readonly<{id:string;trackingNumber:string;driverName:string;currentStatus:ShipmentStatus;requestedStatus:ShipmentStatus;requestedAt:string}>;

function shipmentError(message:string):ShipmentError {
  if(message.includes("access_denied")) return {category:"forbidden",message:"Access denied."};
  if(message.includes("shipment_unavailable")) return {category:"not_found",message:"Shipment unavailable."};
  if(message.includes("assignment_stale")) return {category:"conflict",message:"Shipment changed before assignment. Refresh and try again."};
  if(message.includes("shipment_edit_stale")) return {category:"conflict",message:"Shipment changed since you opened it. Refresh and try again."};
  if(message.includes("shipment_delay_stale")) return {category:"conflict",message:"Shipment changed since this list loaded. Refresh and try again."};
  if(message.includes("shipment_delay_unavailable")) return {category:"not_found",message:"Shipment unavailable."};
  if(message.includes("shipment_delay_status_invalid")) return {category:"business_rule",message:"Only an in-transit Shipment can be marked or cleared as delayed."};
  if(message.includes("shipment_delay_integrity")) return {category:"business_rule",message:"Shipment delay information is inconsistent. No changes were applied."};
  if(message.includes("shipment_cancellation_already_cancelled")) return {category:"conflict",message:"Shipment is already cancelled."};
  if(message.includes("shipment_cancellation_stale")) return {category:"conflict",message:"Shipment changed before cancellation. Refresh and try again."};
  if(message.includes("shipment_edit_unavailable")||message.includes("shipment_cancellation_unavailable")) return {category:"not_found",message:"Shipment unavailable."};
  if(message.includes("shipment_edit_status_invalid")) return {category:"business_rule",message:"Shipment can no longer be edited."};
  if(message.includes("shipment_edit_price_forbidden")) return {category:"forbidden",message:"Dispatchers cannot edit Shipment price."};
  if(message.includes("shipment_edit_blank")||message.includes("shipment_edit_schedule_invalid")||message.includes("shipment_edit_price_invalid")||message.includes("shipment_edit_invalid")) return {category:"business_rule",message:"Shipment details are invalid."};
  if(message.includes("shipment_cancellation_delivered")) return {category:"business_rule",message:"Delivered Shipments cannot be cancelled."};
  if(message.includes("shipment_cancellation_invalid")) return {category:"business_rule",message:"Shipment cancellation is invalid."};
  if(message.includes("shipment_cancellation_integrity")) return {category:"infrastructure",message:"Shipment resources are inconsistent. Cancellation was not applied."};
  if(message.includes("status_request_pending")) return {category:"conflict",message:"A status request is already pending."};
  if(message.includes("status_request_stale")||message.includes("status_request_resolved")) return {category:"conflict",message:"This status request is no longer current. Refresh and try again."};
  if(message.includes("delivery_pod_required")) return {category:"business_rule",message:"Proof of Delivery is required before delivery can be approved."};
  if(message.includes("status_request_unavailable")) return {category:"not_found",message:"Status request unavailable."};
  if(message.includes("transition_invalid")) return {category:"business_rule",message:"That Shipment status change is not allowed."};
  if(message.includes("status_rejection_invalid")) return {category:"business_rule",message:"Rejection reason is invalid."};
  if(message.includes("status_request_integrity")||message.includes("status_resolution_integrity")||message.includes("tracking_integrity")) return {category:"infrastructure",message:"Unable to manage Shipment status right now."};
  if(message.includes("client_unavailable")) return {category:"business_rule",message:"The selected Client is no longer active."};
  if(message.includes("driver_unavailable")) return {category:"business_rule",message:"The selected Driver is no longer available."};
  if(message.includes("vehicle_unavailable")) return {category:"business_rule",message:"The selected Vehicle is no longer available."};
  if(message.includes("validation")||message.includes("invalid")) return {category:"business_rule",message:"Shipment data is invalid."};
  return {category:"infrastructure",message:"Unable to manage Shipments right now."};
}
export async function listShipments(input:ShipmentListInput):Promise<ShipmentResult<ShipmentListResult>> { const client=await createClient(); const args={search_text:input.search,status_filter:input.status,delayed_filter:input.delayed,requested_page:input.page}; const response=await client.rpc("list_operations_shipments",args); if(response.error||response.data===null)return {ok:false,error:shipmentError(response.error?.message??"missing shipment data")}; const data=response.data; let totalCount=Number(data[0]?.total_count??0); if(data.length===0&&input.page>1){const first=await client.rpc("list_operations_shipments",{...args,requested_page:1});if(first.error||first.data===null)return {ok:false,error:shipmentError(first.error?.message??"missing shipment data")};totalCount=Number(first.data[0]?.total_count??0);} return {ok:true,data:{shipments:data.map(r=>({id:r.id,trackingNumber:r.tracking_number,clientCompany:r.client_company,pickupAddress:r.pickup_address,deliveryAddress:r.delivery_address,driverName:r.driver_name,vehicleRegistration:r.vehicle_registration,status:r.status,delayed:r.delayed,updatedAt:r.updated_at})),totalCount,totalPages:Math.ceil(totalCount/SHIPMENTS_PER_PAGE)}}; }
export async function getShipmentCandidates():Promise<ShipmentResult<ShipmentCandidateData>> {const client=await createClient();const [clients,drivers,vehicles]=await Promise.all([client.rpc("list_active_shipment_clients"),client.rpc("list_eligible_shipment_drivers"),client.rpc("list_eligible_shipment_vehicles")]);const error=clients.error??drivers.error??vehicles.error;if(error||clients.data===null||drivers.data===null||vehicles.data===null)return {ok:false,error:shipmentError(error?.message??"missing candidate data")};return {ok:true,data:{clients:clients.data.map(r=>({id:r.id,companyName:r.company_name})),drivers:drivers.data.map(r=>({id:r.id,displayName:r.display_name})),vehicles:vehicles.data.map(r=>({id:r.id,registration:r.registration,make:r.make,model:r.model}))}};}
export async function createPendingShipment(input:ShipmentCreateInput):Promise<ShipmentResult<{id:string;trackingNumber:string}>>{const client=await createClient();const {data,error}=await client.rpc("create_pending_shipment",{input_client_id:input.clientId,input_pickup_address:input.pickupAddress,input_delivery_address:input.deliveryAddress,input_pickup_at:input.pickupAt.toISOString(),input_expected_delivery_at:input.expectedDeliveryAt.toISOString(),input_cargo_type:input.cargoType,input_price:input.price});if(error)return {ok:false,error:shipmentError(error.message)};const row=data[0];return row?{ok:true,data:{id:row.id,trackingNumber:row.tracking_number}}:{ok:false,error:{category:"infrastructure",message:"Unable to create Shipment."}};}
export async function assignPendingShipment(input:ShipmentAssignmentInput):Promise<ShipmentResult<{id:string;trackingNumber:string}>>{const client=await createClient();const {data,error}=await client.rpc("assign_pending_shipment",{target_shipment_id:input.shipmentId,target_driver_id:input.driverId,target_vehicle_id:input.vehicleId});if(error)return {ok:false,error:shipmentError(error.message)};const row=data[0];return row?{ok:true,data:{id:row.id,trackingNumber:row.tracking_number}}:{ok:false,error:{category:"infrastructure",message:"Unable to assign Shipment."}};}

export async function getShipmentForEdit(shipmentId:string):Promise<ShipmentResult<ShipmentEditRecord>> { const client=await createClient(); const {data,error}=await client.rpc("get_operations_shipment_for_edit",{target_shipment_id:shipmentId}); if(error||data===null)return {ok:false,error:shipmentError(error?.message??"missing shipment edit data")}; const row=data[0]; if(!row)return {ok:false,error:{category:"not_found",message:"Shipment unavailable."}}; return {ok:true,data:{id:row.id,trackingNumber:row.tracking_number,pickupAddress:row.pickup_address,deliveryAddress:row.delivery_address,pickupAt:row.pickup_at,expectedDeliveryAt:row.expected_delivery_at,cargoType:row.cargo_type,price:row.price,status:row.status,updatedAt:row.updated_at}}; }
export async function updateShipmentDetails(input:ShipmentEditInput):Promise<ShipmentResult<{id:string;trackingNumber:string;updatedAt:string;mutated:boolean}>> { const client=await createClient(); const {data,error}=await client.rpc("update_shipment_details",{target_shipment_id:input.shipmentId,expected_updated_at:input.expectedUpdatedAt,input_pickup_address:input.pickupAddress,input_delivery_address:input.deliveryAddress,input_pickup_at:input.pickupAt.toISOString(),input_expected_delivery_at:input.expectedDeliveryAt.toISOString(),input_cargo_type:input.cargoType,input_price:input.price}); if(error)return {ok:false,error:shipmentError(error.message)}; const row=data[0]; return row?{ok:true,data:{id:row.id,trackingNumber:row.tracking_number,updatedAt:row.updated_at,mutated:row.mutated}}:{ok:false,error:{category:"infrastructure",message:"Unable to update Shipment."}}; }
export async function cancelShipment(shipmentId:string):Promise<ShipmentResult<{id:string;trackingNumber:string;previousStatus:ShipmentStatus;status:ShipmentStatus}>> { const client=await createClient(); const {data,error}=await client.rpc("cancel_shipment",{target_shipment_id:shipmentId}); if(error)return {ok:false,error:shipmentError(error.message)}; const row=data[0]; return row?{ok:true,data:{id:row.id,trackingNumber:row.tracking_number,previousStatus:row.previous_status,status:row.shipment_status}}:{ok:false,error:{category:"infrastructure",message:"Unable to cancel Shipment."}}; }
export async function setShipmentDelayed(input:ShipmentDelayInput):Promise<ShipmentResult<{result:string;shipmentId:string;delayed:boolean;updatedAt:string}>> { const client=await createClient(); const {data,error}=await client.rpc("set_shipment_delayed",{target_shipment_id:input.shipmentId,target_delayed:input.delayed,expected_updated_at:input.expectedUpdatedAt}); if(error)return {ok:false,error:shipmentError(error.message)}; const row=data[0]; return row?{ok:true,data:{result:row.mutation_result,shipmentId:row.shipment_id,delayed:row.delayed,updatedAt:row.updated_at}}:{ok:false,error:{category:"infrastructure",message:"Unable to update Shipment delay."}}; }

export async function listPendingStatusRequests():Promise<ShipmentResult<readonly PendingStatusRequest[]>> {
  const client=await createClient();
  const {data,error}=await client.rpc("list_operations_pending_status_requests");
  if(error||data===null)return {ok:false,error:shipmentError(error?.message??"missing status request data")};
  return {ok:true,data:data.map((row)=>({id:row.id,trackingNumber:row.tracking_number,driverName:row.driver_name,currentStatus:row.current_status,requestedStatus:row.requested_status,requestedAt:row.requested_at}))};
}

export async function createShipmentStatusRequest(requestedStatus:ShipmentRequestedStatus):Promise<ShipmentResult<StatusRequestState>> {
  const client=await createClient();
  const {data,error}=await client.rpc("create_shipment_status_request",{requested_status:requestedStatus});
  if(error)return {ok:false,error:shipmentError(error.message)};
  return data[0]?{ok:true,data:data[0].request_state}:{ok:false,error:{category:"infrastructure",message:"Unable to request Shipment status."}};
}

export async function approveShipmentStatusRequest(requestId:string):Promise<ShipmentResult<StatusRequestState>> {
  const client=await createClient();
  const {data,error}=await client.rpc("approve_shipment_status_request",{target_request_id:requestId});
  if(error)return {ok:false,error:shipmentError(error.message)};
  return data[0]?{ok:true,data:data[0].request_state}:{ok:false,error:{category:"infrastructure",message:"Unable to approve Shipment status."}};
}

export async function rejectShipmentStatusRequest(requestId:string,rejectionReason:string|null):Promise<ShipmentResult<StatusRequestState>> {
  const client=await createClient();
  const {data,error}=await client.rpc("reject_shipment_status_request",{target_request_id:requestId,input_rejection_reason:rejectionReason??undefined});
  if(error)return {ok:false,error:shipmentError(error.message)};
  return data[0]?{ok:true,data:data[0].request_state}:{ok:false,error:{category:"infrastructure",message:"Unable to reject Shipment status."}};
}
