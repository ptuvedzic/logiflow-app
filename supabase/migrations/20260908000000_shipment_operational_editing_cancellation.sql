alter type public.notification_type add value if not exists 'shipment_cancelled';

create function public.stop_shipment_tracking(
  target_shipment_id uuid,
  target_vehicle_id uuid,
  actor_profile_id uuid,
  tracking_source text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  current_location public.vehicle_locations%rowtype;
begin
  if tracking_source not in ('status_request_approval', 'shipment_cancellation') then
    raise exception using errcode = '22023', message = 'tracking_source_invalid';
  end if;

  select vehicle_locations.* into current_location
  from public.vehicle_locations
  where vehicle_locations.vehicle_id = target_vehicle_id
    and vehicle_locations.shipment_id = target_shipment_id
  for update;

  perform 1 from public.alerts
  where alerts.alert_type = 'stale_vehicle_location'
    and alerts.alert_state = 'active'
    and alerts.vehicle_id = target_vehicle_id
  for update;

  if current_location.vehicle_id is not null then
    insert into public.tracking_history (
      id, vehicle_id, shipment_id, latitude, longitude, speed, heading, route_progress
    ) values (
      gen_random_uuid(), current_location.vehicle_id, current_location.shipment_id,
      current_location.latitude, current_location.longitude, current_location.speed,
      current_location.heading, current_location.route_progress
    );

    delete from public.vehicle_locations
    where vehicle_locations.vehicle_id = target_vehicle_id
      and vehicle_locations.shipment_id = target_shipment_id;
  end if;

  update public.alerts
  set alert_state = 'resolved',
      resolved_at = pg_catalog.now(),
      resolved_by_profile_id = actor_profile_id
  where alerts.alert_type = 'stale_vehicle_location'
    and alerts.alert_state = 'active'
    and alerts.vehicle_id = target_vehicle_id;

  insert into public.activity_logs (
    id, actor_profile_id, action_type, shipment_id, metadata
  ) values (
    gen_random_uuid(), actor_profile_id, 'tracking_stopped', target_shipment_id,
    jsonb_build_object('source', tracking_source)
  );
end;
$function$;

create or replace function public.stop_shipment_tracking(
  target_shipment_id uuid,
  target_vehicle_id uuid,
  actor_profile_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  perform public.stop_shipment_tracking(
    target_shipment_id,
    target_vehicle_id,
    actor_profile_id,
    'status_request_approval'
  );
end;
$function$;

create function public.update_shipment_details(
  target_shipment_id uuid,
  expected_updated_at timestamptz,
  input_pickup_address text,
  input_delivery_address text,
  input_pickup_at timestamptz,
  input_expected_delivery_at timestamptz,
  input_cargo_type text,
  input_price numeric default null
)
returns table (id uuid, tracking_number text, updated_at timestamptz, mutated boolean)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_role public.profile_role;
  target_shipment public.shipments%rowtype;
  normalized_pickup_address text := trim(input_pickup_address);
  normalized_delivery_address text := trim(input_delivery_address);
  normalized_cargo_type text := trim(input_cargo_type);
  changed_fields text[] := array[]::text[];
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = auth.uid()
    and profiles.is_active
    and profiles.role in ('admin', 'dispatcher');
  if not found then
    raise exception using errcode = '42501', message = 'shipment_edit_access_denied';
  end if;

  if target_shipment_id is null or expected_updated_at is null
    or input_pickup_address is null or input_delivery_address is null
    or input_pickup_at is null or input_expected_delivery_at is null
    or input_cargo_type is null then
    raise exception using errcode = '22023', message = 'shipment_edit_invalid';
  end if;
  if normalized_pickup_address = '' or normalized_delivery_address = '' or normalized_cargo_type = '' then
    raise exception using errcode = '22023', message = 'shipment_edit_blank';
  end if;
  if input_expected_delivery_at < input_pickup_at then
    raise exception using errcode = '22023', message = 'shipment_edit_schedule_invalid';
  end if;
  if actor_role = 'admin' and (input_price is null or input_price < 0) then
    raise exception using errcode = '22023', message = 'shipment_edit_price_invalid';
  end if;
  if actor_role = 'dispatcher' and input_price is not null then
    raise exception using errcode = '42501', message = 'shipment_edit_price_forbidden';
  end if;

  select shipments.* into target_shipment
  from public.shipments
  where shipments.id = target_shipment_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_edit_unavailable';
  end if;
  if target_shipment.updated_at <> expected_updated_at then
    raise exception using errcode = '40001', message = 'shipment_edit_stale';
  end if;
  if target_shipment.status not in ('pending', 'assigned', 'loading') then
    raise exception using errcode = 'P0001', message = 'shipment_edit_status_invalid';
  end if;

  if target_shipment.pickup_address is distinct from normalized_pickup_address then changed_fields := array_append(changed_fields, 'pickup_address'); end if;
  if target_shipment.delivery_address is distinct from normalized_delivery_address then changed_fields := array_append(changed_fields, 'delivery_address'); end if;
  if target_shipment.pickup_at is distinct from input_pickup_at then changed_fields := array_append(changed_fields, 'pickup_at'); end if;
  if target_shipment.expected_delivery_at is distinct from input_expected_delivery_at then changed_fields := array_append(changed_fields, 'expected_delivery_at'); end if;
  if target_shipment.cargo_type is distinct from normalized_cargo_type then changed_fields := array_append(changed_fields, 'cargo_type'); end if;
  if actor_role = 'admin' and target_shipment.price is distinct from input_price then changed_fields := array_append(changed_fields, 'price'); end if;

  if cardinality(changed_fields) = 0 then
    return query select target_shipment.id, target_shipment.tracking_number, target_shipment.updated_at, false;
    return;
  end if;

  update public.shipments
  set pickup_address = normalized_pickup_address,
      delivery_address = normalized_delivery_address,
      pickup_at = input_pickup_at,
      expected_delivery_at = input_expected_delivery_at,
      cargo_type = normalized_cargo_type,
      price = case when actor_role = 'admin' then input_price else target_shipment.price end
  where shipments.id = target_shipment.id
  returning shipments.updated_at into target_shipment.updated_at;

  insert into public.activity_logs (id, actor_profile_id, action_type, shipment_id, metadata)
  values (
    gen_random_uuid(), auth.uid(), 'shipment_updated', target_shipment.id,
    jsonb_build_object('changed_fields', to_jsonb(changed_fields))
  );

  return query select target_shipment.id, target_shipment.tracking_number, target_shipment.updated_at, true;
end;
$function$;

create function public.get_operations_shipment_for_edit(target_shipment_id uuid)
returns table (
  id uuid,
  tracking_number text,
  pickup_address text,
  delivery_address text,
  pickup_at timestamptz,
  expected_delivery_at timestamptz,
  cargo_type text,
  price numeric,
  status public.shipment_status,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'shipment_edit_read_access_denied';
  end if;
  return query
  select shipments.id, shipments.tracking_number, shipments.pickup_address,
    shipments.delivery_address, shipments.pickup_at, shipments.expected_delivery_at,
    shipments.cargo_type, shipments.price, shipments.status, shipments.updated_at
  from public.shipments
  where shipments.id = target_shipment_id;
end;
$function$;

create function public.cancel_shipment(target_shipment_id uuid)
returns table (
  id uuid,
  tracking_number text,
  previous_status public.shipment_status,
  shipment_status public.shipment_status
)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  preliminary_shipment public.shipments%rowtype;
  driver_profile_id uuid;
  target_driver public.drivers%rowtype;
  target_vehicle public.vehicles%rowtype;
  target_shipment public.shipments%rowtype;
  target_request public.shipment_status_requests%rowtype;
  pending_request_count integer;
begin
  if actor_id is null or not exists (
    select 1 from public.profiles
    where profiles.id = actor_id and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'shipment_cancellation_access_denied';
  end if;
  if target_shipment_id is null then
    raise exception using errcode = '22023', message = 'shipment_cancellation_invalid';
  end if;

  select shipments.* into preliminary_shipment
  from public.shipments where shipments.id = target_shipment_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_cancellation_unavailable';
  end if;

  if preliminary_shipment.status in ('assigned', 'loading', 'in_transit') then
    select drivers.profile_id into driver_profile_id
    from public.drivers where drivers.id = preliminary_shipment.driver_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'shipment_cancellation_integrity';
    end if;
    perform 1 from public.profiles
    where profiles.id = driver_profile_id and profiles.is_active and profiles.role = 'driver'
    for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'shipment_cancellation_integrity';
    end if;
    select drivers.* into target_driver
    from public.drivers
    where drivers.id = preliminary_shipment.driver_id and drivers.profile_id = driver_profile_id
    for update;
    select vehicles.* into target_vehicle
    from public.vehicles where vehicles.id = preliminary_shipment.vehicle_id
    for update;
  end if;

  select shipments.* into target_shipment
  from public.shipments where shipments.id = target_shipment_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_cancellation_unavailable';
  end if;
  if target_shipment.status = 'delivered' then
    raise exception using errcode = 'P0001', message = 'shipment_cancellation_delivered';
  end if;
  if target_shipment.status = 'cancelled' then
    raise exception using errcode = '40001', message = 'shipment_cancellation_already_cancelled';
  end if;
  if target_shipment.status not in ('pending', 'assigned', 'loading', 'in_transit') then
    raise exception using errcode = '40001', message = 'shipment_cancellation_stale';
  end if;

  if target_shipment.status <> 'pending' and (
    target_shipment.driver_id is distinct from target_driver.id
    or target_driver.status <> 'assigned'
    or target_shipment.vehicle_id is distinct from target_vehicle.id
    or target_vehicle.status <> 'in_use'
  ) then
    raise exception using errcode = 'P0001', message = 'shipment_cancellation_integrity';
  end if;
  if target_shipment.status = 'pending' and (target_shipment.driver_id is not null or target_shipment.vehicle_id is not null) then
    raise exception using errcode = 'P0001', message = 'shipment_cancellation_integrity';
  end if;

  select count(*)::integer into pending_request_count
  from public.shipment_status_requests
  where shipment_status_requests.shipment_id = target_shipment.id
    and shipment_status_requests.request_state = 'pending';
  if pending_request_count > 1 then
    raise exception using errcode = 'P0001', message = 'shipment_cancellation_integrity';
  end if;
  if pending_request_count = 1 then
    select shipment_status_requests.* into target_request
    from public.shipment_status_requests
    where shipment_status_requests.shipment_id = target_shipment.id
      and shipment_status_requests.request_state = 'pending'
    for update;
  end if;

  if target_shipment.status = 'in_transit' then
    perform 1 from public.vehicle_locations
    where vehicle_locations.vehicle_id = target_vehicle.id
      and vehicle_locations.shipment_id = target_shipment.id
    for update;
    perform 1 from public.alerts
    where alerts.alert_type = 'stale_vehicle_location'
      and alerts.alert_state = 'active'
      and alerts.vehicle_id = target_vehicle.id
    for update;
  end if;

  update public.shipments
  set status = 'cancelled', delayed = false
  where shipments.id = target_shipment.id;

  if target_shipment.status <> 'pending' then
    update public.drivers set status = 'available' where drivers.id = target_driver.id;
    update public.vehicles set status = 'available' where vehicles.id = target_vehicle.id;
  end if;

  if target_request.id is not null then
    update public.shipment_status_requests
    set request_state = 'rejected',
        resolved_at = pg_catalog.now(),
        resolved_by_profile_id = actor_id,
        rejection_reason = 'Shipment cancelled'
    where shipment_status_requests.id = target_request.id;
    insert into public.activity_logs (id, actor_profile_id, action_type, status_request_id, metadata)
    values (
      gen_random_uuid(), actor_id, 'status_request_rejected', target_request.id,
      jsonb_build_object('from_status', target_request.current_status, 'requested_status', target_request.requested_status)
    );
  end if;

  if target_shipment.status = 'in_transit' then
    perform public.stop_shipment_tracking(target_shipment.id, target_vehicle.id, actor_id, 'shipment_cancellation');
  end if;

  insert into public.activity_logs (id, actor_profile_id, action_type, shipment_id, metadata)
  values (
    gen_random_uuid(), actor_id, 'shipment_cancelled', target_shipment.id,
    jsonb_build_object('from_status', target_shipment.status)
  );

  if target_shipment.status <> 'pending' then
    insert into public.notifications (
      id, recipient_profile_id, notification_type, title, message, shipment_id
    ) values (
      gen_random_uuid(), driver_profile_id, 'shipment_cancelled', 'Shipment cancelled',
      'Shipment ' || target_shipment.tracking_number || ' has been cancelled.', target_shipment.id
    );
  end if;

  return query select target_shipment.id, target_shipment.tracking_number,
    target_shipment.status, 'cancelled'::public.shipment_status;
end;
$function$;

revoke all on function public.stop_shipment_tracking(uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.stop_shipment_tracking(uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function public.get_operations_shipment_for_edit(uuid) from public, anon;
revoke all on function public.update_shipment_details(uuid,timestamptz,text,text,timestamptz,timestamptz,text,numeric) from public, anon;
revoke all on function public.cancel_shipment(uuid) from public, anon;

grant execute on function public.get_operations_shipment_for_edit(uuid) to authenticated;
grant execute on function public.update_shipment_details(uuid,timestamptz,text,text,timestamptz,timestamptz,text,numeric) to authenticated;
grant execute on function public.cancel_shipment(uuid) to authenticated;

comment on function public.stop_shipment_tracking(uuid,uuid,uuid,text) is
  'Internal tracking-stop implementation with a tightly validated workflow source. Not browser-callable.';
comment on function public.stop_shipment_tracking(uuid,uuid,uuid) is
  'S2-compatible internal tracking-stop wrapper using status_request_approval. Not browser-callable.';
comment on function public.get_operations_shipment_for_edit(uuid) is
  'Role-gated edit-safe Shipment read for Operations.';
comment on function public.update_shipment_details(uuid,timestamptz,text,text,timestamptz,timestamptz,text,numeric) is
  'Narrow ordinary-edit function in the existing Shipment controlled-workflow category.';
comment on function public.cancel_shipment(uuid) is
  'Narrow cancellation function in the existing Shipment controlled-workflow category.';
