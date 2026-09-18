alter table public.vehicles
  add constraint vehicles_registration_length_check
    check (char_length(trim(registration)) <= 32),
  add constraint vehicles_vin_length_check
    check (vin is null or char_length(trim(vin)) <= 64);

create function public.list_operations_vehicles(
  search_text text default '',
  status_filter text default 'all',
  type_filter text default 'all',
  requested_page integer default 1
)
returns table (
  id uuid,
  registration text,
  make text,
  model text,
  vehicle_type text,
  mileage integer,
  status public.vehicle_status,
  total_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_search text := trim(coalesce(search_text, ''));
  normalized_type text := trim(coalesce(type_filter, 'all'));
  actor_role public.profile_role;
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = (select auth.uid()) and profiles.is_active;

  if actor_role is null or actor_role not in ('admin', 'dispatcher') then
    raise exception using errcode = 'P0001', message = 'vehicle_read_access_denied';
  end if;
  if char_length(normalized_search) > 100 or requested_page is null or requested_page < 1 then
    raise exception using errcode = 'P0001', message = 'vehicle_list_invalid';
  end if;
  if status_filter is null or status_filter not in ('all', 'available', 'in_use', 'maintenance', 'out_of_service', 'archived') then
    raise exception using errcode = 'P0001', message = 'vehicle_list_invalid';
  end if;

  return query
  select
    vehicles.id,
    vehicles.registration,
    vehicles.make,
    vehicles.model,
    vehicles.vehicle_type,
    vehicles.mileage,
    vehicles.status,
    count(*) over () as total_count
  from public.vehicles
  where
    (normalized_search = '' or vehicles.registration ilike '%' || normalized_search || '%' or vehicles.model ilike '%' || normalized_search || '%')
    and (status_filter = 'all' or vehicles.status = status_filter::public.vehicle_status)
    and (normalized_type = 'all' or vehicles.vehicle_type = normalized_type)
  order by lower(vehicles.registration), vehicles.id
  limit 10
  offset ((requested_page - 1) * 10);
end;
$$;

create function public.list_operations_vehicle_types()
returns table (vehicle_type text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_role public.profile_role;
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = (select auth.uid()) and profiles.is_active;
  if actor_role is null or actor_role not in ('admin', 'dispatcher') then
    raise exception using errcode = 'P0001', message = 'vehicle_read_access_denied';
  end if;
  return query
  select distinct_types.vehicle_type
  from (select distinct vehicles.vehicle_type from public.vehicles) as distinct_types
  order by lower(distinct_types.vehicle_type), distinct_types.vehicle_type;
end;
$$;

create function public.get_operations_vehicle_for_edit(target_vehicle_id uuid)
returns table (
  id uuid,
  registration text,
  make text,
  model text,
  vehicle_type text,
  vin text,
  mileage integer,
  fuel_type text,
  first_registration_date date,
  status public.vehicle_status,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_role public.profile_role;
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = (select auth.uid()) and profiles.is_active;
  if actor_role is distinct from 'admin' then
    raise exception using errcode = 'P0001', message = 'vehicle_read_access_denied';
  end if;
  return query
  select vehicles.id, vehicles.registration, vehicles.make, vehicles.model,
    vehicles.vehicle_type, vehicles.vin, vehicles.mileage, vehicles.fuel_type,
    vehicles.first_registration_date, vehicles.status, vehicles.updated_at
  from public.vehicles
  where vehicles.id = target_vehicle_id;
end;
$$;

create function public.create_vehicle(
  input_registration text,
  input_make text,
  input_model text,
  input_vehicle_type text,
  input_vin text default null,
  input_mileage integer default 0,
  input_fuel_type text default null,
  input_first_registration_date date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  vehicle_id uuid := gen_random_uuid();
  registration_value text := trim(input_registration);
  make_value text := trim(input_make);
  model_value text := trim(input_model);
  type_value text := trim(input_vehicle_type);
  vin_value text := nullif(trim(input_vin), '');
  fuel_value text := nullif(trim(input_fuel_type), '');
begin
  if not exists (select 1 from public.profiles where id = actor_id and is_active and role = 'admin') then
    raise exception using errcode = 'P0001', message = 'vehicle_mutation_access_denied';
  end if;
  if registration_value is null or registration_value = '' or char_length(registration_value) > 32
    or make_value is null or make_value = '' or model_value is null or model_value = '' or type_value is null or type_value = ''
    or (vin_value is not null and char_length(vin_value) > 64)
    or input_mileage is null or input_mileage < 0 then
    raise exception using errcode = 'P0001', message = 'vehicle_validation_failed';
  end if;

  insert into public.vehicles (id, registration, make, model, vehicle_type, vin, mileage, fuel_type, first_registration_date, status)
  values (vehicle_id, registration_value, make_value, model_value, type_value, vin_value, input_mileage, fuel_value, input_first_registration_date, 'available');

  insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
  values (gen_random_uuid(), actor_id, 'vehicle_created', vehicle_id, jsonb_build_object('status', 'available'));
  return vehicle_id;
end;
$$;

create function public.update_vehicle_master_data(
  target_vehicle_id uuid,
  expected_updated_at timestamptz,
  input_registration text,
  input_make text,
  input_model text,
  input_vehicle_type text,
  input_vin text default null,
  input_fuel_type text default null,
  input_first_registration_date date default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  current_vehicle public.vehicles%rowtype;
  registration_value text := trim(input_registration);
  make_value text := trim(input_make);
  model_value text := trim(input_model);
  type_value text := trim(input_vehicle_type);
  vin_value text := nullif(trim(input_vin), '');
  fuel_value text := nullif(trim(input_fuel_type), '');
  changed_fields text[] := array[]::text[];
begin
  if not exists (select 1 from public.profiles where id = actor_id and is_active and role = 'admin') then
    raise exception using errcode = 'P0001', message = 'vehicle_mutation_access_denied';
  end if;
  if registration_value is null or registration_value = '' or char_length(registration_value) > 32
    or make_value is null or make_value = '' or model_value is null or model_value = '' or type_value is null or type_value = ''
    or (vin_value is not null and char_length(vin_value) > 64) then
    raise exception using errcode = 'P0001', message = 'vehicle_validation_failed';
  end if;

  select * into current_vehicle from public.vehicles where id = target_vehicle_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'vehicle_not_found'; end if;
  if current_vehicle.updated_at is distinct from expected_updated_at then raise exception using errcode = 'P0001', message = 'vehicle_stale'; end if;

  if current_vehicle.registration is distinct from registration_value then changed_fields := array_append(changed_fields, 'registration'); end if;
  if current_vehicle.make is distinct from make_value then changed_fields := array_append(changed_fields, 'make'); end if;
  if current_vehicle.model is distinct from model_value then changed_fields := array_append(changed_fields, 'model'); end if;
  if current_vehicle.vehicle_type is distinct from type_value then changed_fields := array_append(changed_fields, 'vehicle_type'); end if;
  if current_vehicle.vin is distinct from vin_value then changed_fields := array_append(changed_fields, 'vin'); end if;
  if current_vehicle.fuel_type is distinct from fuel_value then changed_fields := array_append(changed_fields, 'fuel_type'); end if;
  if current_vehicle.first_registration_date is distinct from input_first_registration_date then changed_fields := array_append(changed_fields, 'first_registration_date'); end if;
  if cardinality(changed_fields) = 0 then return 'noop'; end if;

  update public.vehicles set registration = registration_value, make = make_value, model = model_value,
    vehicle_type = type_value, vin = vin_value, fuel_type = fuel_value,
    first_registration_date = input_first_registration_date
  where id = target_vehicle_id;
  insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
  values (gen_random_uuid(), actor_id, 'vehicle_updated', target_vehicle_id, jsonb_build_object('changed_fields', to_jsonb(changed_fields)));
  return 'updated';
end;
$$;

create function public.update_vehicle_mileage(target_vehicle_id uuid, expected_updated_at timestamptz, new_mileage integer)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  current_vehicle public.vehicles%rowtype;
begin
  if not exists (select 1 from public.profiles where id = actor_id and is_active and role = 'admin') then
    raise exception using errcode = 'P0001', message = 'vehicle_mutation_access_denied';
  end if;
  if new_mileage is null or new_mileage < 0 then raise exception using errcode = 'P0001', message = 'vehicle_validation_failed'; end if;
  select * into current_vehicle from public.vehicles where id = target_vehicle_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'vehicle_not_found'; end if;
  if current_vehicle.updated_at is distinct from expected_updated_at then raise exception using errcode = 'P0001', message = 'vehicle_stale'; end if;
  if new_mileage < current_vehicle.mileage then raise exception using errcode = 'P0001', message = 'vehicle_mileage_decrease'; end if;
  if new_mileage = current_vehicle.mileage then return 'noop'; end if;
  update public.vehicles set mileage = new_mileage where id = target_vehicle_id;
  insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
  values (gen_random_uuid(), actor_id, 'vehicle_updated', target_vehicle_id,
    jsonb_build_object('field', 'mileage', 'from', current_vehicle.mileage, 'to', new_mileage, 'unit', 'km'));
  return 'updated';
end;
$$;

create function public.change_vehicle_operational_status(target_vehicle_id uuid, requested_operation text)
returns public.vehicle_status
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  current_status public.vehicle_status;
  target_status public.vehicle_status;
  action public.activity_action_type;
begin
  if not exists (select 1 from public.profiles where id = actor_id and is_active and role = 'admin') then
    raise exception using errcode = 'P0001', message = 'vehicle_mutation_access_denied';
  end if;
  select status into current_status from public.vehicles where id = target_vehicle_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'vehicle_not_found'; end if;

  perform 1 from public.shipments
  where vehicle_id = target_vehicle_id and status in ('assigned', 'loading', 'in_transit')
  order by id for update;
  if found then raise exception using errcode = 'P0001', message = 'vehicle_active_shipment'; end if;
  if current_status = 'in_use' then raise exception using errcode = 'P0001', message = 'vehicle_transition_invalid'; end if;

  target_status := case
    when requested_operation = 'mark_maintenance' and current_status = 'available' then 'maintenance'
    when requested_operation = 'mark_available' and current_status in ('maintenance', 'out_of_service') then 'available'
    when requested_operation = 'mark_out_of_service' and current_status in ('available', 'maintenance') then 'out_of_service'
    when requested_operation = 'archive' and current_status in ('available', 'maintenance', 'out_of_service') then 'archived'
    when requested_operation = 'reactivate' and current_status = 'archived' then 'available'
    else null
  end::public.vehicle_status;
  if target_status is null then raise exception using errcode = 'P0001', message = 'vehicle_transition_invalid'; end if;

  update public.vehicles set status = target_status where id = target_vehicle_id;
  action := (case when requested_operation = 'archive' then 'vehicle_archived' else 'vehicle_status_changed' end)::public.activity_action_type;
  insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
  values (gen_random_uuid(), actor_id, action, target_vehicle_id,
    jsonb_build_object('from_status', current_status, 'to_status', target_status, 'operation', requested_operation));
  return target_status;
end;
$$;

revoke all on function public.list_operations_vehicles(text, text, text, integer) from public, anon;
revoke all on function public.list_operations_vehicle_types() from public, anon;
revoke all on function public.get_operations_vehicle_for_edit(uuid) from public, anon;
revoke all on function public.create_vehicle(text, text, text, text, text, integer, text, date) from public, anon;
revoke all on function public.update_vehicle_master_data(uuid, timestamptz, text, text, text, text, text, text, date) from public, anon;
revoke all on function public.update_vehicle_mileage(uuid, timestamptz, integer) from public, anon;
revoke all on function public.change_vehicle_operational_status(uuid, text) from public, anon;

grant execute on function public.list_operations_vehicles(text, text, text, integer) to authenticated;
grant execute on function public.list_operations_vehicle_types() to authenticated;
grant execute on function public.get_operations_vehicle_for_edit(uuid) to authenticated;
grant execute on function public.create_vehicle(text, text, text, text, text, integer, text, date) to authenticated;
grant execute on function public.update_vehicle_master_data(uuid, timestamptz, text, text, text, text, text, text, date) to authenticated;
grant execute on function public.update_vehicle_mileage(uuid, timestamptz, integer) to authenticated;
grant execute on function public.change_vehicle_operational_status(uuid, text) to authenticated;
