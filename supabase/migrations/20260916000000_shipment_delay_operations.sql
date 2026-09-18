drop function public.list_operations_shipments(text, text, text, integer);

create function public.list_operations_shipments(search_text text default '', status_filter text default 'all', delayed_filter text default 'all', requested_page integer default 1)
returns table (id uuid, tracking_number text, client_company text, pickup_address text, delivery_address text,
  driver_name text, vehicle_registration text, status public.shipment_status, delayed boolean, updated_at timestamptz, total_count bigint)
language plpgsql stable security definer set search_path = '' as $function$
declare normalized_search text := trim(coalesce(search_text, '')); begin
  if not exists (select 1 from public.profiles actor where actor.id = auth.uid() and actor.is_active and actor.role in ('admin','dispatcher')) then raise exception using errcode='42501', message='shipment_read_access_denied'; end if;
  if char_length(normalized_search) > 100 or requested_page is null or requested_page < 1
    or status_filter is null or status_filter not in ('all','pending','assigned','loading','in_transit','delivered','cancelled')
    or delayed_filter is null or delayed_filter not in ('all','delayed') then raise exception using errcode='22023', message='shipment_list_invalid'; end if;
  return query select s.id, s.tracking_number, c.company_name, s.pickup_address, s.delivery_address,
    p.full_name, v.registration, s.status, s.delayed, s.updated_at, count(*) over ()
  from public.shipments s join public.clients c on c.id=s.client_id
  left join public.drivers d on d.id=s.driver_id left join public.profiles p on p.id=d.profile_id
  left join public.vehicles v on v.id=s.vehicle_id
  where (normalized_search='' or s.tracking_number ilike '%'||normalized_search||'%' or c.company_name ilike '%'||normalized_search||'%')
    and (status_filter='all' or s.status=status_filter::public.shipment_status)
    and (delayed_filter='all' or s.delayed)
  order by s.created_at desc, s.id desc limit 10 offset ((requested_page-1)*10);
end;$function$;

revoke all on function public.list_operations_shipments(text,text,text,integer) from public, anon;
grant execute on function public.list_operations_shipments(text,text,text,integer) to authenticated;

create function public.set_shipment_delayed(
  target_shipment_id uuid,
  target_delayed boolean,
  expected_updated_at timestamptz
)
returns table (mutation_result text, shipment_id uuid, delayed boolean, updated_at timestamptz)
language plpgsql volatile security definer set search_path = '' as $function$
declare
  actor_id uuid := auth.uid();
  preliminary_shipment public.shipments%rowtype;
  driver_profile_id uuid;
  target_driver public.drivers%rowtype;
  target_shipment public.shipments%rowtype;
  target_alert public.alerts%rowtype;
  mutation_time timestamptz := pg_catalog.transaction_timestamp();
  alert_message text;
begin
  if actor_id is null or not exists (
    select 1 from public.profiles where profiles.id=actor_id and profiles.is_active
      and profiles.role in ('admin','dispatcher')
  ) then raise exception using errcode='42501', message='shipment_delay_access_denied'; end if;
  if target_shipment_id is null or target_delayed is null or expected_updated_at is null then
    raise exception using errcode='22023', message='shipment_delay_invalid';
  end if;

  select shipments.* into preliminary_shipment from public.shipments
  where shipments.id=target_shipment_id;
  if not found then raise exception using errcode='P0002', message='shipment_delay_unavailable'; end if;
  if preliminary_shipment.status <> 'in_transit' then raise exception using errcode='P0001', message='shipment_delay_status_invalid'; end if;

  if target_delayed and not preliminary_shipment.delayed then
    select drivers.profile_id into driver_profile_id from public.drivers
    where drivers.id=preliminary_shipment.driver_id;
    if not found then raise exception using errcode='P0001', message='shipment_delay_integrity'; end if;
    perform 1 from public.profiles where profiles.id=driver_profile_id
      and profiles.is_active and profiles.role='driver' FOR UPDATE;
    if not found then raise exception using errcode='P0001', message='shipment_delay_integrity'; end if;
    select drivers.* into target_driver from public.drivers
    where drivers.id=preliminary_shipment.driver_id and drivers.profile_id=driver_profile_id FOR UPDATE;
    if not found then raise exception using errcode='P0001', message='shipment_delay_integrity'; end if;
  end if;

  select shipments.* into target_shipment from public.shipments
  where shipments.id=target_shipment_id FOR UPDATE;
  if not found then raise exception using errcode='P0002', message='shipment_delay_unavailable'; end if;
  if target_shipment.status <> 'in_transit' then raise exception using errcode='P0001', message='shipment_delay_status_invalid'; end if;
  if target_shipment.updated_at <> expected_updated_at then raise exception using errcode='40001', message='shipment_delay_stale'; end if;
  if target_shipment.delayed = target_delayed then
    return query select 'noop'::text, target_shipment.id, target_shipment.delayed, target_shipment.updated_at;
    return;
  end if;
  if target_delayed and (
    target_shipment.driver_id is distinct from target_driver.id or target_driver.profile_id is distinct from driver_profile_id
  ) then raise exception using errcode='P0001', message='shipment_delay_integrity'; end if;

  select alerts.* into target_alert from public.alerts
  where alerts.alert_type='shipment_delayed' and alerts.alert_state='active'
    and alerts.shipment_id=target_shipment.id FOR UPDATE;

  if target_delayed then
    if target_alert.id is not null then raise exception using errcode='P0001', message='shipment_delay_integrity'; end if;
    alert_message := 'Shipment ' || target_shipment.tracking_number || ' has been marked as delayed.';
    update public.shipments set delayed=true where shipments.id=target_shipment.id
      returning shipments.updated_at into target_shipment.updated_at;
    insert into public.alerts (id,alert_type,severity,message,alert_state,shipment_id,created_at)
    values (gen_random_uuid(),'shipment_delayed','warning',alert_message,'active',target_shipment.id,mutation_time);
    insert into public.activity_logs (id,actor_profile_id,action_type,shipment_id,metadata,occurred_at) values
      (gen_random_uuid(),actor_id,'shipment_delayed',target_shipment.id,'{"delayed":true}'::jsonb,mutation_time),
      (gen_random_uuid(),actor_id,'alert_created',target_shipment.id,'{"alert_type":"shipment_delayed"}'::jsonb,mutation_time);
    insert into public.notifications (id,recipient_profile_id,notification_type,title,message,shipment_id,created_at,read_at)
    values (gen_random_uuid(),driver_profile_id,'shipment_delayed','Shipment delayed',alert_message,target_shipment.id,mutation_time,null);
  else
    if target_alert.id is null or target_alert.vehicle_id is not null or target_alert.driver_id is not null
      or target_alert.document_id is not null or target_alert.severity <> 'warning' then
      raise exception using errcode='P0001', message='shipment_delay_integrity';
    end if;
    update public.shipments set delayed=false where shipments.id=target_shipment.id
      returning shipments.updated_at into target_shipment.updated_at;
    update public.alerts set alert_state='resolved', resolved_at=mutation_time, resolved_by_profile_id=actor_id
    where alerts.id=target_alert.id;
    insert into public.activity_logs (id,actor_profile_id,action_type,shipment_id,metadata,occurred_at)
    values (gen_random_uuid(),actor_id,'alert_resolved',target_shipment.id,'{"alert_type":"shipment_delayed"}'::jsonb,mutation_time);
  end if;
  return query select 'updated'::text, target_shipment.id, target_delayed, target_shipment.updated_at;
end;$function$;

revoke all on function public.set_shipment_delayed(uuid,boolean,timestamptz) from public, anon;
grant execute on function public.set_shipment_delayed(uuid,boolean,timestamptz) to authenticated;
comment on function public.set_shipment_delayed(uuid,boolean,timestamptz) is 'Narrow manual delayed-state mutation in the existing Shipment controlled-workflow category.';

grant select (delayed) on table public.shipments to authenticated;

drop policy activity_logs_dispatcher_shipment_select on public.activity_logs;
create policy activity_logs_dispatcher_shipment_select on public.activity_logs for select to authenticated using (
  (select public.current_active_profile_role())='dispatcher' and (
    (shipment_id is not null and driver_id is null and client_id is null and document_id is null
      and status_request_id is null and maintenance_record_id is null and expense_id is null
      and vehicle_id is null and action_type in (
        'shipment_created','shipment_updated','shipment_assigned','shipment_status_changed','shipment_cancelled',
        'tracking_started','tracking_stopped','shipment_delayed','alert_created','alert_resolved'
      ))
    or (status_request_id is not null and shipment_id is null and vehicle_id is null and driver_id is null
      and client_id is null and document_id is null and maintenance_record_id is null and expense_id is null
      and action_type in ('status_request_created','status_request_approved','status_request_rejected'))
  )
);

create or replace function public.approve_shipment_status_request(target_request_id uuid)
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
  target_delay_alert public.alerts%rowtype;
  mutation_time timestamptz := pg_catalog.transaction_timestamp();
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
    if target_shipment.delayed then
      select alerts.* into target_delay_alert from public.alerts
      where alerts.alert_type = 'shipment_delayed' and alerts.alert_state = 'active'
        and alerts.shipment_id = target_shipment.id for update;
      if not found or target_delay_alert.vehicle_id is not null or target_delay_alert.driver_id is not null
        or target_delay_alert.document_id is not null or target_delay_alert.severity <> 'warning' then
        raise exception using errcode = 'P0001', message = 'shipment_delay_integrity';
      end if;
    end if;
  end if;

  update public.shipments
  set status = target_request.requested_status,
      delayed = case when target_request.requested_status = 'delivered' then false else delayed end
  where shipments.id = target_shipment.id;

  if target_request.requested_status = 'delivered' and target_shipment.delayed then
    update public.alerts set alert_state='resolved', resolved_at=mutation_time, resolved_by_profile_id=actor_id
    where alerts.id=target_delay_alert.id;
    insert into public.activity_logs (id,actor_profile_id,action_type,shipment_id,metadata,occurred_at)
    values (gen_random_uuid(),actor_id,'alert_resolved',target_shipment.id,'{"alert_type":"shipment_delayed"}'::jsonb,mutation_time);
  end if;

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

create or replace function public.cancel_shipment(target_shipment_id uuid)
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
  target_delay_alert public.alerts%rowtype;
  mutation_time timestamptz := pg_catalog.transaction_timestamp();
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
    if target_shipment.delayed then
      select alerts.* into target_delay_alert from public.alerts
      where alerts.alert_type='shipment_delayed' and alerts.alert_state='active'
        and alerts.shipment_id=target_shipment.id for update;
      if not found or target_delay_alert.vehicle_id is not null or target_delay_alert.driver_id is not null
        or target_delay_alert.document_id is not null or target_delay_alert.severity <> 'warning' then
        raise exception using errcode='P0001', message='shipment_delay_integrity';
      end if;
    end if;
  end if;

  update public.shipments
  set status = 'cancelled', delayed = false
  where shipments.id = target_shipment.id;

  if target_shipment.delayed then
    update public.alerts set alert_state='resolved', resolved_at=mutation_time, resolved_by_profile_id=actor_id
    where alerts.id=target_delay_alert.id;
    insert into public.activity_logs (id,actor_profile_id,action_type,shipment_id,metadata,occurred_at)
    values (gen_random_uuid(),actor_id,'alert_resolved',target_shipment.id,'{"alert_type":"shipment_delayed"}'::jsonb,mutation_time);
  end if;

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
