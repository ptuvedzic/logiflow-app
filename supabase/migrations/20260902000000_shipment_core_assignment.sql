create function public.create_pending_shipment(
  input_client_id uuid,
  input_pickup_address text,
  input_delivery_address text,
  input_pickup_at timestamptz,
  input_expected_delivery_at timestamptz,
  input_cargo_type text,
  input_price numeric
)
returns table (id uuid, tracking_number text)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  shipment_id uuid := gen_random_uuid();
  utc_year text := to_char(current_timestamp at time zone 'UTC', 'YYYY');
  next_number bigint;
  generated_tracking_number text;
begin
  if actor_id is null or not exists (
    select 1 from public.profiles
    where profiles.id = actor_id and profiles.is_active and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'shipment_mutation_access_denied';
  end if;

  input_pickup_address := trim(input_pickup_address);
  input_delivery_address := trim(input_delivery_address);
  input_cargo_type := trim(input_cargo_type);
  if input_client_id is null or input_pickup_address is null or input_pickup_address = ''
    or input_delivery_address is null or input_delivery_address = ''
    or input_pickup_at is null or input_expected_delivery_at is null
    or input_expected_delivery_at < input_pickup_at
    or input_cargo_type is null or input_cargo_type = ''
    or input_price is null or input_price < 0 then
    raise exception using errcode = '22023', message = 'shipment_validation_failed';
  end if;

  perform 1 from public.clients
  where clients.id = input_client_id and clients.status = 'active'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'shipment_client_unavailable';
  end if;

  loop
    select coalesce(max(split_part(shipments.tracking_number, '-', 3)::bigint), 0) + 1
    into next_number
    from public.shipments
    where shipments.tracking_number ~ ('^SHP-' || utc_year || '-[0-9]+$');
    generated_tracking_number := 'SHP-' || utc_year || '-' ||
      case when next_number >= 100 then next_number::text else lpad(next_number::text, 3, '0') end;
    begin
      insert into public.shipments (
        id, tracking_number, client_id, pickup_address, delivery_address,
        pickup_at, expected_delivery_at, cargo_type, price, status, delayed,
        driver_id, vehicle_id
      ) values (
        shipment_id, generated_tracking_number, input_client_id,
        input_pickup_address, input_delivery_address, input_pickup_at,
        input_expected_delivery_at, input_cargo_type, input_price,
        'pending', false, null, null
      );
      exit;
    exception when unique_violation then
      if not exists (
        select 1 from public.shipments
        where shipments.tracking_number = generated_tracking_number
      ) then
        raise;
      end if;
    end;
  end loop;

  insert into public.activity_logs (id, actor_profile_id, action_type, shipment_id, metadata)
  values (gen_random_uuid(), actor_id, 'shipment_created', shipment_id, jsonb_build_object('status', 'pending'));
  return query select shipment_id, generated_tracking_number;
end;
$function$;

create function public.assign_pending_shipment(
  target_shipment_id uuid,
  target_driver_id uuid,
  target_vehicle_id uuid
)
returns table (id uuid, tracking_number text)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  preliminary_client_id uuid;
  target_profile_id uuid;
  locked_shipment public.shipments%rowtype;
  locked_driver public.drivers%rowtype;
  locked_vehicle public.vehicles%rowtype;
begin
  if actor_id is null or not exists (
    select 1 from public.profiles
    where profiles.id = actor_id and profiles.is_active and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'shipment_mutation_access_denied';
  end if;
  if target_shipment_id is null or target_driver_id is null or target_vehicle_id is null then
    raise exception using errcode = '22023', message = 'shipment_assignment_invalid';
  end if;

  select shipments.client_id into preliminary_client_id
  from public.shipments where shipments.id = target_shipment_id;
  if not found then raise exception using errcode = 'P0002', message = 'shipment_unavailable'; end if;
  select drivers.profile_id into target_profile_id
  from public.drivers where drivers.id = target_driver_id;
  if not found then raise exception using errcode = 'P0002', message = 'shipment_driver_unavailable'; end if;

  perform 1 from public.clients
  where clients.id = preliminary_client_id and clients.status = 'active' for update;
  if not found then raise exception using errcode = 'P0002', message = 'shipment_client_unavailable'; end if;

  perform 1 from public.profiles
  where profiles.id = target_profile_id and profiles.role = 'driver' and profiles.is_active for update;
  if not found then raise exception using errcode = 'P0002', message = 'shipment_driver_unavailable'; end if;

  select drivers.* into locked_driver from public.drivers
  where drivers.id = target_driver_id and drivers.profile_id = target_profile_id for update;
  if not found or locked_driver.status <> 'available' then
    raise exception using errcode = 'P0002', message = 'shipment_driver_unavailable';
  end if;

  select vehicles.* into locked_vehicle from public.vehicles
  where vehicles.id = target_vehicle_id for update;
  if not found or locked_vehicle.status <> 'available' then
    raise exception using errcode = 'P0002', message = 'shipment_vehicle_unavailable';
  end if;

  select shipments.* into locked_shipment from public.shipments
  where shipments.id = target_shipment_id for update;
  if not found or locked_shipment.client_id <> preliminary_client_id
    or locked_shipment.status <> 'pending' or locked_shipment.driver_id is not null
    or locked_shipment.vehicle_id is not null then
    raise exception using errcode = '40001', message = 'shipment_assignment_stale';
  end if;

  if exists (select 1 from public.shipments where driver_id = target_driver_id and status in ('assigned','loading','in_transit')) then
    raise exception using errcode = 'P0001', message = 'shipment_driver_unavailable';
  end if;
  if exists (select 1 from public.shipments where vehicle_id = target_vehicle_id and status in ('assigned','loading','in_transit')) then
    raise exception using errcode = 'P0001', message = 'shipment_vehicle_unavailable';
  end if;

  update public.shipments set driver_id = target_driver_id, vehicle_id = target_vehicle_id, status = 'assigned'
  where shipments.id = target_shipment_id;
  update public.drivers set status = 'assigned' where drivers.id = target_driver_id;
  update public.vehicles set status = 'in_use' where vehicles.id = target_vehicle_id;
  insert into public.activity_logs (id, actor_profile_id, action_type, shipment_id, metadata)
  values (gen_random_uuid(), actor_id, 'shipment_assigned', target_shipment_id,
    jsonb_build_object('driver_status', 'assigned', 'vehicle_status', 'in_use'));
  insert into public.notifications (id, recipient_profile_id, notification_type, title, message, shipment_id)
  values (gen_random_uuid(), target_profile_id, 'shipment_assigned', 'New shipment assigned',
    'Shipment ' || locked_shipment.tracking_number || ' has been assigned to you.', target_shipment_id);
  return query select target_shipment_id, locked_shipment.tracking_number;
exception when unique_violation then
  if sqlerrm like '%shipments_active_driver_key%' then
    raise exception using errcode = 'P0001', message = 'shipment_driver_unavailable';
  elsif sqlerrm like '%shipments_active_vehicle_key%' then
    raise exception using errcode = 'P0001', message = 'shipment_vehicle_unavailable';
  else raise;
  end if;
end;
$function$;

create function public.list_operations_shipments(search_text text default '', status_filter text default 'all', delayed_filter text default 'all', requested_page integer default 1)
returns table (id uuid, tracking_number text, client_company text, pickup_address text, delivery_address text,
  driver_name text, vehicle_registration text, status public.shipment_status, delayed boolean, total_count bigint)
language plpgsql stable security definer set search_path = '' as $function$
declare normalized_search text := trim(coalesce(search_text, '')); begin
  if not exists (select 1 from public.profiles actor where actor.id = auth.uid() and actor.is_active and actor.role in ('admin','dispatcher')) then raise exception using errcode='42501', message='shipment_read_access_denied'; end if;
  if char_length(normalized_search) > 100 or requested_page is null or requested_page < 1
    or status_filter is null or status_filter not in ('all','pending','assigned','loading','in_transit','delivered','cancelled')
    or delayed_filter is null or delayed_filter not in ('all','delayed') then raise exception using errcode='22023', message='shipment_list_invalid'; end if;
  return query select s.id, s.tracking_number, c.company_name, s.pickup_address, s.delivery_address,
    p.full_name, v.registration, s.status, s.delayed, count(*) over ()
  from public.shipments s join public.clients c on c.id=s.client_id
  left join public.drivers d on d.id=s.driver_id left join public.profiles p on p.id=d.profile_id
  left join public.vehicles v on v.id=s.vehicle_id
  where (normalized_search='' or s.tracking_number ilike '%'||normalized_search||'%' or c.company_name ilike '%'||normalized_search||'%')
    and (status_filter='all' or s.status=status_filter::public.shipment_status)
    and (delayed_filter='all' or s.delayed)
  order by s.created_at desc, s.id desc limit 10 offset ((requested_page-1)*10);
end;$function$;

create function public.list_active_shipment_clients() returns table (id uuid, company_name text)
language sql stable security definer set search_path = '' as $function$
  select c.id,c.company_name from public.clients c
  where c.status='active' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','dispatcher'))
  order by lower(c.company_name),c.id
$function$;
create function public.list_eligible_shipment_drivers() returns table (id uuid, display_name text)
language sql stable security definer set search_path = '' as $function$
  select d.id,p.full_name from public.drivers d join public.profiles p on p.id=d.profile_id
  where d.status='available' and p.is_active and p.role='driver'
    and exists(select 1 from public.profiles a where a.id=auth.uid() and a.is_active and a.role in ('admin','dispatcher'))
    and not exists(select 1 from public.shipments s where s.driver_id=d.id and s.status in ('assigned','loading','in_transit'))
  order by lower(p.full_name),d.id
$function$;
create function public.list_eligible_shipment_vehicles() returns table (id uuid, registration text, make text, model text)
language sql stable security definer set search_path = '' as $function$
  select v.id,v.registration,v.make,v.model from public.vehicles v
  where v.status='available'
    and exists(select 1 from public.profiles p where p.id=auth.uid() and p.is_active and p.role in ('admin','dispatcher'))
    and not exists(select 1 from public.shipments s where s.vehicle_id=v.id and s.status in ('assigned','loading','in_transit'))
  order by lower(v.registration),v.id
$function$;

revoke all on function public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric) from public,anon;
revoke all on function public.assign_pending_shipment(uuid,uuid,uuid) from public,anon;
revoke all on function public.list_operations_shipments(text,text,text,integer) from public,anon;
revoke all on function public.list_active_shipment_clients() from public,anon;
revoke all on function public.list_eligible_shipment_drivers() from public,anon;
revoke all on function public.list_eligible_shipment_vehicles() from public,anon;
grant execute on function public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric) to authenticated;
grant execute on function public.assign_pending_shipment(uuid,uuid,uuid) to authenticated;
grant execute on function public.list_operations_shipments(text,text,text,integer) to authenticated;
grant execute on function public.list_active_shipment_clients() to authenticated;
grant execute on function public.list_eligible_shipment_drivers() to authenticated;
grant execute on function public.list_eligible_shipment_vehicles() to authenticated;
comment on function public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric) is 'Narrow pending-Shipment creation function in the existing Shipment controlled-workflow category.';
comment on function public.assign_pending_shipment(uuid,uuid,uuid) is 'Narrow initial-assignment function in the existing Shipment controlled-workflow category. Locks Client, Driver Profile, Driver, Vehicle, Shipment.';
