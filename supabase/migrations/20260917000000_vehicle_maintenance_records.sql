create function public.list_operations_maintenance(
  search_text text default '',
  vehicle_filter uuid default null,
  service_date_from date default null,
  service_date_to date default null,
  requested_page integer default 1
)
returns table (
  id uuid,
  vehicle_registration text,
  service_type text,
  service_date date,
  mileage_at_service integer,
  workshop text,
  cost numeric,
  next_service_date date,
  next_service_mileage integer,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_search text := trim(coalesce(search_text, ''));
  actor_role public.profile_role;
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = (select auth.uid()) and profiles.is_active;

  if actor_role is null or actor_role not in ('admin', 'dispatcher') then
    raise exception using errcode = 'P0001', message = 'maintenance_read_access_denied';
  end if;
  if char_length(normalized_search) > 100 or requested_page is null or requested_page < 1
    or (service_date_from is not null and service_date_to is not null and service_date_from > service_date_to) then
    raise exception using errcode = 'P0001', message = 'maintenance_list_invalid';
  end if;

  return query
  select maintenance_records.id, vehicles.registration, maintenance_records.service_type,
    maintenance_records.service_date, maintenance_records.mileage_at_service,
    maintenance_records.workshop, maintenance_records.cost,
    maintenance_records.next_service_date, maintenance_records.next_service_mileage,
    count(*) over () as total_count
  from public.maintenance_records
  join public.vehicles on vehicles.id = maintenance_records.vehicle_id
  where (normalized_search = ''
      or vehicles.registration ilike '%' || normalized_search || '%'
      or maintenance_records.service_type ilike '%' || normalized_search || '%'
      or maintenance_records.workshop ilike '%' || normalized_search || '%')
    and (vehicle_filter is null or maintenance_records.vehicle_id = vehicle_filter)
    and (service_date_from is null or maintenance_records.service_date >= service_date_from)
    and (service_date_to is null or maintenance_records.service_date <= service_date_to)
  order by maintenance_records.service_date desc, maintenance_records.created_at desc, maintenance_records.id desc
  limit 10 offset ((requested_page - 1) * 10);
end;
$$;

create function public.list_maintenance_vehicle_options()
returns table (id uuid, registration text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor_role public.profile_role;
begin
  select profiles.role into actor_role from public.profiles
  where profiles.id = (select auth.uid()) and profiles.is_active;
  if actor_role is null or actor_role not in ('admin', 'dispatcher') then
    raise exception using errcode = 'P0001', message = 'maintenance_read_access_denied';
  end if;
  return query select vehicles.id, vehicles.registration from public.vehicles
    order by lower(vehicles.registration), vehicles.id;
end;
$$;

create function public.get_operations_maintenance_for_edit(target_maintenance_record_id uuid)
returns table (
  id uuid, vehicle_id uuid, vehicle_registration text, service_type text,
  service_date date, mileage_at_service integer, workshop text, cost numeric,
  notes text, next_service_date date, next_service_mileage integer,
  created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor_role public.profile_role;
begin
  select profiles.role into actor_role from public.profiles
  where profiles.id = (select auth.uid()) and profiles.is_active;
  if actor_role is distinct from 'admin' then
    raise exception using errcode = 'P0001', message = 'maintenance_read_access_denied';
  end if;
  return query
  select maintenance_records.id, maintenance_records.vehicle_id, vehicles.registration,
    maintenance_records.service_type, maintenance_records.service_date,
    maintenance_records.mileage_at_service, maintenance_records.workshop,
    maintenance_records.cost, maintenance_records.notes,
    maintenance_records.next_service_date, maintenance_records.next_service_mileage,
    maintenance_records.created_at, maintenance_records.updated_at
  from public.maintenance_records
  join public.vehicles on vehicles.id = maintenance_records.vehicle_id
  where maintenance_records.id = target_maintenance_record_id;
end;
$$;

create function public.create_maintenance_record(
  target_vehicle_id uuid,
  input_service_type text,
  input_service_date date,
  input_mileage_at_service integer,
  input_workshop text default null,
  input_cost numeric default null,
  input_notes text default null,
  input_next_service_date date default null,
  input_next_service_mileage integer default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_role public.profile_role;
  target_vehicle public.vehicles%rowtype;
  maintenance_id uuid := gen_random_uuid();
  normalized_service_type text := trim(input_service_type);
  normalized_workshop text := nullif(trim(input_workshop), '');
  normalized_notes text := nullif(trim(input_notes), '');
  normalized_cost numeric := round(input_cost, 2);
  mileage_updated boolean := false;
begin
  select profiles.role into actor_role from public.profiles
  where profiles.id = actor_id and profiles.is_active for update;
  if actor_role is distinct from 'admin' then
    raise exception using errcode = 'P0001', message = 'maintenance_mutation_access_denied';
  end if;
  if normalized_service_type is null or normalized_service_type = '' or input_service_date is null
    or input_service_date > current_date or input_mileage_at_service is null or input_mileage_at_service < 0
    or input_cost is distinct from normalized_cost or normalized_cost < 0 or normalized_cost >= 10000000000
    or (input_next_service_date is not null and input_next_service_date <= input_service_date)
    or (input_next_service_mileage is not null and input_next_service_mileage <= input_mileage_at_service) then
    raise exception using errcode = 'P0001', message = 'maintenance_validation_failed';
  end if;

  select * into target_vehicle from public.vehicles where id = target_vehicle_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'maintenance_vehicle_not_found'; end if;

  insert into public.maintenance_records (
    id, vehicle_id, service_type, service_date, mileage_at_service, workshop,
    cost, notes, next_service_date, next_service_mileage
  ) values (
    maintenance_id, target_vehicle.id, normalized_service_type, input_service_date,
    input_mileage_at_service, normalized_workshop, normalized_cost, normalized_notes,
    input_next_service_date, input_next_service_mileage
  );
  if input_mileage_at_service > target_vehicle.mileage then
    update public.vehicles set mileage = input_mileage_at_service where id = target_vehicle.id;
    mileage_updated := true;
  end if;
  insert into public.activity_logs (id, actor_profile_id, action_type, maintenance_record_id, metadata)
  values (gen_random_uuid(), actor_id, 'maintenance_record_created', maintenance_id,
    jsonb_build_object('vehicle_mileage_updated', mileage_updated));
  return maintenance_id;
end;
$$;

create function public.update_maintenance_record(
  target_maintenance_record_id uuid,
  expected_updated_at timestamptz,
  input_service_type text,
  input_service_date date,
  input_mileage_at_service integer,
  input_workshop text default null,
  input_cost numeric default null,
  input_notes text default null,
  input_next_service_date date default null,
  input_next_service_mileage integer default null
)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_role public.profile_role;
  discovered_vehicle_id uuid;
  target_vehicle public.vehicles%rowtype;
  target_record public.maintenance_records%rowtype;
  normalized_service_type text := trim(input_service_type);
  normalized_workshop text := nullif(trim(input_workshop), '');
  normalized_notes text := nullif(trim(input_notes), '');
  normalized_cost numeric := round(input_cost, 2);
  changed_fields text[] := array[]::text[];
  mileage_updated boolean := false;
begin
  select profiles.role into actor_role from public.profiles
  where profiles.id = actor_id and profiles.is_active for update;
  if actor_role is distinct from 'admin' then
    raise exception using errcode = 'P0001', message = 'maintenance_mutation_access_denied';
  end if;
  if normalized_service_type is null or normalized_service_type = '' or input_service_date is null
    or input_service_date > current_date or input_mileage_at_service is null or input_mileage_at_service < 0
    or input_cost is distinct from normalized_cost or normalized_cost < 0 or normalized_cost >= 10000000000
    or (input_next_service_date is not null and input_next_service_date <= input_service_date)
    or (input_next_service_mileage is not null and input_next_service_mileage <= input_mileage_at_service) then
    raise exception using errcode = 'P0001', message = 'maintenance_validation_failed';
  end if;

  select maintenance_records.vehicle_id into discovered_vehicle_id
  from public.maintenance_records where maintenance_records.id = target_maintenance_record_id;
  if not found then raise exception using errcode = 'P0001', message = 'maintenance_record_not_found'; end if;
  select * into target_vehicle from public.vehicles where id = discovered_vehicle_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'maintenance_vehicle_not_found'; end if;
  select * into target_record from public.maintenance_records
  where id = target_maintenance_record_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'maintenance_record_not_found'; end if;
  if target_record.vehicle_id is distinct from discovered_vehicle_id then
    raise exception using errcode = 'P0001', message = 'maintenance_record_vehicle_changed';
  end if;
  if target_record.updated_at is distinct from expected_updated_at then
    raise exception using errcode = 'P0001', message = 'maintenance_record_stale';
  end if;

  if target_record.service_type is distinct from normalized_service_type then changed_fields := array_append(changed_fields, 'service_type'); end if;
  if target_record.service_date is distinct from input_service_date then changed_fields := array_append(changed_fields, 'service_date'); end if;
  if target_record.mileage_at_service is distinct from input_mileage_at_service then changed_fields := array_append(changed_fields, 'mileage_at_service'); end if;
  if target_record.workshop is distinct from normalized_workshop then changed_fields := array_append(changed_fields, 'workshop'); end if;
  if target_record.cost is distinct from normalized_cost then changed_fields := array_append(changed_fields, 'cost'); end if;
  if target_record.notes is distinct from normalized_notes then changed_fields := array_append(changed_fields, 'notes'); end if;
  if target_record.next_service_date is distinct from input_next_service_date then changed_fields := array_append(changed_fields, 'next_service_date'); end if;
  if target_record.next_service_mileage is distinct from input_next_service_mileage then changed_fields := array_append(changed_fields, 'next_service_mileage'); end if;
  if cardinality(changed_fields) = 0 then return 'noop'; end if;

  update public.maintenance_records set service_type = normalized_service_type,
    service_date = input_service_date, mileage_at_service = input_mileage_at_service,
    workshop = normalized_workshop, cost = normalized_cost, notes = normalized_notes,
    next_service_date = input_next_service_date, next_service_mileage = input_next_service_mileage
  where id = target_record.id;
  if input_mileage_at_service > target_vehicle.mileage then
    update public.vehicles set mileage = input_mileage_at_service where id = target_vehicle.id;
    mileage_updated := true;
  end if;
  insert into public.activity_logs (id, actor_profile_id, action_type, maintenance_record_id, metadata)
  values (gen_random_uuid(), actor_id, 'maintenance_record_updated', target_record.id,
    jsonb_build_object('changed_fields', to_jsonb(changed_fields), 'vehicle_mileage_updated', mileage_updated));
  return 'updated';
end;
$$;

revoke all on function public.list_operations_maintenance(text, uuid, date, date, integer) from public, anon;
revoke all on function public.list_maintenance_vehicle_options() from public, anon;
revoke all on function public.get_operations_maintenance_for_edit(uuid) from public, anon;
revoke all on function public.create_maintenance_record(uuid, text, date, integer, text, numeric, text, date, integer) from public, anon;
revoke all on function public.update_maintenance_record(uuid, timestamptz, text, date, integer, text, numeric, text, date, integer) from public, anon;

grant execute on function public.list_operations_maintenance(text, uuid, date, date, integer) to authenticated;
grant execute on function public.list_maintenance_vehicle_options() to authenticated;
grant execute on function public.get_operations_maintenance_for_edit(uuid) to authenticated;
grant execute on function public.create_maintenance_record(uuid, text, date, integer, text, numeric, text, date, integer) to authenticated;
grant execute on function public.update_maintenance_record(uuid, timestamptz, text, date, integer, text, numeric, text, date, integer) to authenticated;

comment on function public.create_maintenance_record(uuid, text, date, integer, text, numeric, text, date, integer)
is 'Narrow Maintenance-category creation with monotonic Vehicle mileage synchronization.';
comment on function public.update_maintenance_record(uuid, timestamptz, text, date, integer, text, numeric, text, date, integer)
is 'Narrow Maintenance-category historical correction with optimistic concurrency and monotonic Vehicle mileage synchronization.';
