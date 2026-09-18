alter table public.shipment_status_requests
add constraint shipment_status_requests_rejection_reason_length_check
check (rejection_reason is null or char_length(rejection_reason) <= 500);

create function public.start_shipment_tracking(
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
  if not exists (
    select 1 from public.shipments
    where shipments.id = target_shipment_id
      and shipments.vehicle_id = target_vehicle_id
      and shipments.status = 'in_transit'
  ) then
    raise exception using errcode = 'P0001', message = 'shipment_tracking_integrity';
  end if;

  if exists (
    select 1 from public.vehicle_locations
    where vehicle_locations.vehicle_id = target_vehicle_id
      and vehicle_locations.shipment_id <> target_shipment_id
  ) or exists (
    select 1 from public.vehicle_locations
    where vehicle_locations.shipment_id = target_shipment_id
      and vehicle_locations.vehicle_id <> target_vehicle_id
  ) then
    raise exception using errcode = 'P0001', message = 'shipment_tracking_integrity';
  end if;

  insert into public.vehicle_locations (
    vehicle_id, shipment_id, latitude, longitude, speed, heading, route_progress
  ) values (
    target_vehicle_id, target_shipment_id, 45.2671, 19.8335, 0, 0, 0
  )
  on conflict (vehicle_id) do update
  set shipment_id = excluded.shipment_id,
      latitude = excluded.latitude,
      longitude = excluded.longitude,
      speed = excluded.speed,
      heading = excluded.heading,
      route_progress = excluded.route_progress,
      updated_at = pg_catalog.now()
  where public.vehicle_locations.shipment_id = excluded.shipment_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'shipment_tracking_integrity';
  end if;

  insert into public.tracking_history (
    id, vehicle_id, shipment_id, latitude, longitude, speed, heading, route_progress
  ) values (
    gen_random_uuid(), target_vehicle_id, target_shipment_id, 45.2671, 19.8335, 0, 0, 0
  );

  insert into public.activity_logs (
    id, actor_profile_id, action_type, shipment_id, metadata
  ) values (
    gen_random_uuid(), actor_profile_id, 'tracking_started', target_shipment_id,
    jsonb_build_object('source', 'status_request_approval')
  );
end;
$function$;

create function public.stop_shipment_tracking(
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
declare
  current_location public.vehicle_locations%rowtype;
begin
  select vehicle_locations.* into current_location
  from public.vehicle_locations
  where vehicle_locations.vehicle_id = target_vehicle_id
    and vehicle_locations.shipment_id = target_shipment_id;

  if found then
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
    jsonb_build_object('source', 'status_request_approval')
  );
end;
$function$;

create function public.create_shipment_status_request(
  requested_status public.shipment_status
)
returns table (request_state public.status_request_state, accepted_status public.shipment_status)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  target_driver public.drivers%rowtype;
  target_vehicle public.vehicles%rowtype;
  target_shipment public.shipments%rowtype;
  target_request_id uuid := gen_random_uuid();
  requested_label text;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'shipment_status_request_access_denied';
  end if;

  perform 1 from public.profiles
  where profiles.id = actor_id and profiles.is_active and profiles.role = 'driver'
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'shipment_status_request_access_denied';
  end if;

  select drivers.* into target_driver
  from public.drivers
  where drivers.profile_id = actor_id
  for update;
  if not found or target_driver.status <> 'assigned' then
    raise exception using errcode = 'P0002', message = 'shipment_status_request_unavailable';
  end if;

  select shipments.* into target_shipment
  from public.shipments
  where shipments.driver_id = target_driver.id
    and shipments.status in ('assigned', 'loading', 'in_transit');
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_status_request_unavailable';
  end if;

  select vehicles.* into target_vehicle
  from public.vehicles
  where vehicles.id = target_shipment.vehicle_id
  for update;
  if not found or target_vehicle.status <> 'in_use' then
    raise exception using errcode = 'P0001', message = 'shipment_status_request_integrity';
  end if;

  select shipments.* into target_shipment
  from public.shipments
  where shipments.id = target_shipment.id
  for update;
  if not found or target_shipment.driver_id <> target_driver.id
    or target_shipment.vehicle_id <> target_vehicle.id
    or target_shipment.status not in ('assigned', 'loading', 'in_transit') then
    raise exception using errcode = '40001', message = 'shipment_status_request_stale';
  end if;

  if not (
    (target_shipment.status = 'assigned' and requested_status = 'loading')
    or (target_shipment.status = 'loading' and requested_status = 'in_transit')
    or (target_shipment.status = 'in_transit' and requested_status = 'delivered')
  ) then
    raise exception using errcode = '22023', message = 'shipment_status_request_transition_invalid';
  end if;

  perform 1 from public.shipment_status_requests
  where shipment_status_requests.shipment_id = target_shipment.id
    and shipment_status_requests.request_state = 'pending'
  for update;
  if found then
    raise exception using errcode = '23505', message = 'shipment_status_request_pending';
  end if;

  insert into public.shipment_status_requests (
    id, shipment_id, driver_id, current_status, requested_status
  ) values (
    target_request_id, target_shipment.id, target_driver.id,
    target_shipment.status, requested_status
  );

  insert into public.activity_logs (
    id, actor_profile_id, action_type, status_request_id, metadata
  ) values (
    gen_random_uuid(), actor_id, 'status_request_created', target_request_id,
    jsonb_build_object(
      'from_status', target_shipment.status,
      'requested_status', requested_status
    )
  );

  requested_label := case requested_status
    when 'loading' then 'Loading'
    when 'in_transit' then 'In transit'
    when 'delivered' then 'Delivered'
  end;

  insert into public.notifications (
    id, recipient_profile_id, notification_type, title, message, shipment_id
  )
  select gen_random_uuid(), profiles.id, 'status_approval_requested',
    'Shipment status request',
    'Shipment ' || target_shipment.tracking_number || ': Driver requested ' || requested_label || '.',
    target_shipment.id
  from public.profiles
  where profiles.is_active and profiles.role in ('admin', 'dispatcher');

  return query select 'pending'::public.status_request_state, requested_status;
exception when unique_violation then
  if sqlerrm like '%shipment_status_requests_pending_shipment_key%' then
    raise exception using errcode = '23505', message = 'shipment_status_request_pending';
  end if;
  raise;
end;
$function$;

create function public.approve_shipment_status_request(target_request_id uuid)
returns table (request_state public.status_request_state, shipment_status public.shipment_status)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  preliminary_request public.shipment_status_requests%rowtype;
  preliminary_shipment public.shipments%rowtype;
  driver_profile_id uuid;
  target_driver public.drivers%rowtype;
  target_vehicle public.vehicles%rowtype;
  target_shipment public.shipments%rowtype;
  target_request public.shipment_status_requests%rowtype;
  requested_label text;
begin
  if actor_id is null or not exists (
    select 1 from public.profiles
    where profiles.id = actor_id and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'shipment_status_resolution_access_denied';
  end if;
  if target_request_id is null then
    raise exception using errcode = '22023', message = 'shipment_status_resolution_invalid';
  end if;

  select shipment_status_requests.* into preliminary_request
  from public.shipment_status_requests
  where shipment_status_requests.id = target_request_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_status_request_unavailable';
  end if;
  select shipments.* into preliminary_shipment
  from public.shipments where shipments.id = preliminary_request.shipment_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_status_request_unavailable';
  end if;
  select drivers.profile_id into driver_profile_id
  from public.drivers where drivers.id = preliminary_request.driver_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'shipment_status_resolution_integrity';
  end if;

  perform 1 from public.profiles
  where profiles.id = driver_profile_id and profiles.is_active and profiles.role = 'driver'
  for update;
  if not found then
    raise exception using errcode = '40001', message = 'shipment_status_request_stale';
  end if;
  select drivers.* into target_driver
  from public.drivers where drivers.id = preliminary_request.driver_id
    and drivers.profile_id = driver_profile_id for update;
  if not found or target_driver.status <> 'assigned' then
    raise exception using errcode = '40001', message = 'shipment_status_request_stale';
  end if;
  select vehicles.* into target_vehicle
  from public.vehicles where vehicles.id = preliminary_shipment.vehicle_id for update;
  if not found or target_vehicle.status <> 'in_use' then
    raise exception using errcode = 'P0001', message = 'shipment_status_resolution_integrity';
  end if;
  select shipments.* into target_shipment
  from public.shipments where shipments.id = preliminary_request.shipment_id for update;
  select shipment_status_requests.* into target_request
  from public.shipment_status_requests where shipment_status_requests.id = target_request_id for update;

  if not found or target_request.request_state <> 'pending' then
    raise exception using errcode = '40001', message = 'shipment_status_request_resolved';
  end if;
  if target_shipment.id is null
    or target_shipment.driver_id <> target_request.driver_id
    or target_shipment.vehicle_id <> target_vehicle.id
    or target_request.current_status <> target_shipment.status
    or not (
      (target_shipment.status = 'assigned' and target_request.requested_status = 'loading')
      or (target_shipment.status = 'loading' and target_request.requested_status = 'in_transit')
      or (target_shipment.status = 'in_transit' and target_request.requested_status = 'delivered')
    ) then
    raise exception using errcode = '40001', message = 'shipment_status_request_stale';
  end if;

  if target_request.requested_status = 'delivered' then
    perform 1 from public.documents
    where documents.shipment_id = target_shipment.id
      and documents.document_type = 'proof_of_delivery'
      and documents.lifecycle_status = 'active'
    order by documents.id
    limit 1 for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'shipment_delivery_pod_required';
    end if;
  end if;

  if target_request.requested_status in ('in_transit', 'delivered') then
    perform 1 from public.vehicle_locations
    where vehicle_locations.vehicle_id = target_vehicle.id
       or vehicle_locations.shipment_id = target_shipment.id
    for update;
  end if;
  if target_request.requested_status = 'delivered' then
    perform 1 from public.alerts
    where alerts.alert_type = 'stale_vehicle_location'
      and alerts.alert_state = 'active'
      and alerts.vehicle_id = target_vehicle.id
    for update;
  end if;

  update public.shipments
  set status = target_request.requested_status,
      delayed = case when target_request.requested_status = 'delivered' then false else delayed end
  where shipments.id = target_shipment.id;

  if target_request.requested_status = 'delivered' then
    update public.drivers set status = 'available' where drivers.id = target_driver.id;
    update public.vehicles set status = 'available' where vehicles.id = target_vehicle.id;
  end if;

  update public.shipment_status_requests
  set request_state = 'approved', resolved_at = pg_catalog.now(),
      resolved_by_profile_id = actor_id, rejection_reason = null
  where shipment_status_requests.id = target_request.id;

  insert into public.activity_logs (
    id, actor_profile_id, action_type, status_request_id, metadata
  ) values (
    gen_random_uuid(), actor_id, 'status_request_approved', target_request.id,
    jsonb_build_object('from_status', target_request.current_status, 'to_status', target_request.requested_status)
  );
  insert into public.activity_logs (
    id, actor_profile_id, action_type, shipment_id, metadata
  ) values (
    gen_random_uuid(), actor_id, 'shipment_status_changed', target_shipment.id,
    jsonb_build_object(
      'from_status', target_request.current_status,
      'to_status', target_request.requested_status,
      'operation', 'status_request_approved'
    )
  );

  if target_request.requested_status = 'in_transit' then
    perform public.start_shipment_tracking(target_shipment.id, target_vehicle.id, actor_id);
  elsif target_request.requested_status = 'delivered' then
    perform public.stop_shipment_tracking(target_shipment.id, target_vehicle.id, actor_id);
  end if;

  requested_label := case target_request.requested_status
    when 'loading' then 'Loading'
    when 'in_transit' then 'In transit'
    when 'delivered' then 'Delivered'
  end;
  insert into public.notifications (
    id, recipient_profile_id, notification_type, title, message, shipment_id
  ) values (
    gen_random_uuid(), driver_profile_id, 'status_approved', 'Shipment status approved',
    'Shipment ' || target_shipment.tracking_number || ' is now ' || requested_label || '.',
    target_shipment.id
  );

  return query select 'approved'::public.status_request_state, target_request.requested_status;
end;
$function$;

create function public.reject_shipment_status_request(
  target_request_id uuid,
  input_rejection_reason text default null
)
returns table (request_state public.status_request_state, requested_status public.shipment_status)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  preliminary_request public.shipment_status_requests%rowtype;
  preliminary_shipment public.shipments%rowtype;
  driver_profile_id uuid;
  target_shipment public.shipments%rowtype;
  target_request public.shipment_status_requests%rowtype;
  normalized_reason text := nullif(trim(input_rejection_reason), '');
  requested_label text;
begin
  if actor_id is null or not exists (
    select 1 from public.profiles
    where profiles.id = actor_id and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'shipment_status_resolution_access_denied';
  end if;
  if target_request_id is null or char_length(normalized_reason) > 500 then
    raise exception using errcode = '22023', message = 'shipment_status_rejection_invalid';
  end if;

  select shipment_status_requests.* into preliminary_request
  from public.shipment_status_requests where shipment_status_requests.id = target_request_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_status_request_unavailable';
  end if;
  select shipments.* into preliminary_shipment
  from public.shipments where shipments.id = preliminary_request.shipment_id;
  select drivers.profile_id into driver_profile_id
  from public.drivers where drivers.id = preliminary_request.driver_id;

  if driver_profile_id is not null then
    perform 1 from public.profiles where profiles.id = driver_profile_id for update;
  end if;
  perform 1 from public.drivers
  where drivers.id = preliminary_request.driver_id for update;
  if preliminary_shipment.vehicle_id is not null then
    perform 1 from public.vehicles where vehicles.id = preliminary_shipment.vehicle_id for update;
  end if;
  select shipments.* into target_shipment
  from public.shipments where shipments.id = preliminary_request.shipment_id for update;
  select shipment_status_requests.* into target_request
  from public.shipment_status_requests where shipment_status_requests.id = target_request_id for update;

  if not found or target_request.request_state <> 'pending' then
    raise exception using errcode = '40001', message = 'shipment_status_request_resolved';
  end if;

  update public.shipment_status_requests
  set request_state = 'rejected', resolved_at = pg_catalog.now(),
      resolved_by_profile_id = actor_id, rejection_reason = normalized_reason
  where shipment_status_requests.id = target_request.id;

  insert into public.activity_logs (
    id, actor_profile_id, action_type, status_request_id, metadata
  ) values (
    gen_random_uuid(), actor_id, 'status_request_rejected', target_request.id,
    jsonb_build_object(
      'from_status', target_request.current_status,
      'requested_status', target_request.requested_status
    )
  );

  requested_label := case target_request.requested_status
    when 'loading' then 'Loading'
    when 'in_transit' then 'In transit'
    when 'delivered' then 'Delivered'
    else initcap(replace(target_request.requested_status::text, '_', ' '))
  end;
  if driver_profile_id is not null and exists (
    select 1 from public.profiles
    where profiles.id = driver_profile_id and profiles.is_active and profiles.role = 'driver'
  ) then
    insert into public.notifications (
      id, recipient_profile_id, notification_type, title, message, shipment_id
    ) values (
      gen_random_uuid(), driver_profile_id, 'status_rejected',
      'Shipment status request rejected',
      'Shipment ' || target_shipment.tracking_number || ': ' || requested_label ||
        ' request was rejected.' || case when normalized_reason is null then '' else ' Reason: ' || normalized_reason end,
      target_request.shipment_id
    );
  end if;

  return query select 'rejected'::public.status_request_state, target_request.requested_status;
end;
$function$;

create function public.list_operations_pending_status_requests()
returns table (
  id uuid,
  tracking_number text,
  driver_name text,
  current_status public.shipment_status,
  requested_status public.shipment_status,
  requested_at timestamptz
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
    raise exception using errcode = '42501', message = 'shipment_status_request_read_access_denied';
  end if;
  return query
  select requests.id, shipments.tracking_number, profiles.full_name,
    requests.current_status, requests.requested_status, requests.requested_at
  from public.shipment_status_requests requests
  join public.shipments shipments on shipments.id = requests.shipment_id
  join public.drivers drivers on drivers.id = requests.driver_id
  join public.profiles profiles on profiles.id = drivers.profile_id
  where requests.request_state = 'pending'
  order by requests.requested_at asc, requests.id asc;
end;
$function$;

create function public.get_current_driver_status_request()
returns table (
  request_state public.status_request_state,
  current_status public.shipment_status,
  requested_status public.shipment_status,
  requested_at timestamptz,
  resolved_at timestamptz,
  rejection_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not exists (
    select 1 from public.profiles
    where profiles.id = auth.uid() and profiles.is_active and profiles.role = 'driver'
  ) then
    raise exception using errcode = '42501', message = 'shipment_status_request_read_access_denied';
  end if;
  return query
  select requests.request_state, requests.current_status, requests.requested_status,
    requests.requested_at, requests.resolved_at, requests.rejection_reason
  from public.shipment_status_requests requests
  join public.shipments shipments on shipments.id = requests.shipment_id
  join public.drivers drivers on drivers.id = requests.driver_id
  where drivers.profile_id = auth.uid()
    and shipments.driver_id = drivers.id
    and shipments.status in ('assigned', 'loading', 'in_transit')
  order by (requests.request_state = 'pending') desc,
    coalesce(requests.resolved_at, requests.requested_at) desc,
    requests.id desc
  limit 1;
end;
$function$;

revoke all on function public.start_shipment_tracking(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.stop_shipment_tracking(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.create_shipment_status_request(public.shipment_status) from public, anon;
revoke all on function public.approve_shipment_status_request(uuid) from public, anon;
revoke all on function public.reject_shipment_status_request(uuid, text) from public, anon;
revoke all on function public.list_operations_pending_status_requests() from public, anon;
revoke all on function public.get_current_driver_status_request() from public, anon;

grant execute on function public.create_shipment_status_request(public.shipment_status) to authenticated;
grant execute on function public.approve_shipment_status_request(uuid) to authenticated;
grant execute on function public.reject_shipment_status_request(uuid, text) to authenticated;
grant execute on function public.list_operations_pending_status_requests() to authenticated;
grant execute on function public.get_current_driver_status_request() to authenticated;

comment on function public.create_shipment_status_request(public.shipment_status) is
  'Driver-only narrow status-request creation function in the existing Shipment controlled-workflow category.';
comment on function public.approve_shipment_status_request(uuid) is
  'Operations-only narrow status-request approval function in the existing Shipment controlled-workflow category.';
comment on function public.reject_shipment_status_request(uuid, text) is
  'Operations-only narrow status-request rejection function in the existing Shipment controlled-workflow category.';
comment on function public.start_shipment_tracking(uuid, uuid, uuid) is
  'Internal tracking-start helper in the existing Tracking controlled-function category; not browser executable.';
comment on function public.stop_shipment_tracking(uuid, uuid, uuid) is
  'Internal tracking-stop helper in the existing Tracking controlled-function category; not browser executable.';
