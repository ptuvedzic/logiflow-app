create function public.reconcile_vehicle_maintenance_alerts(
  target_vehicle_id uuid,
  lifecycle_actor_profile_id uuid default null
)
returns table (created_count integer, resolved_count integer, updated_count integer)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  target_vehicle public.vehicles%rowtype;
  date_record public.maintenance_records%rowtype;
  mileage_record public.maintenance_records%rowtype;
  current_alert public.alerts%rowtype;
  evaluation_date date := current_date;
  evaluation_time timestamptz := pg_catalog.clock_timestamp();
  date_remaining integer;
  mileage_remaining integer;
  condition_active boolean;
  expected_message text;
  current_type public.alert_type;
  created_total integer := 0;
  resolved_total integer := 0;
  updated_total integer := 0;
begin
  if lifecycle_actor_profile_id is null then
    if current_user not in ('postgres', 'service_role') then
      raise exception using errcode = '42501', message = 'maintenance_alert_access_denied';
    end if;
  elsif lifecycle_actor_profile_id is distinct from (select auth.uid())
    or not exists (
      select 1 from public.profiles
      where profiles.id = lifecycle_actor_profile_id
        and profiles.is_active
        and profiles.role = 'admin'
    ) then
    raise exception using errcode = '42501', message = 'maintenance_alert_access_denied';
  end if;

  select vehicles.* into target_vehicle
  from public.vehicles
  where vehicles.id = target_vehicle_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'maintenance_vehicle_not_found';
  end if;

  select maintenance_records.* into date_record
  from public.maintenance_records
  where maintenance_records.vehicle_id = target_vehicle.id
    and maintenance_records.next_service_date is not null
  order by maintenance_records.service_date desc,
           maintenance_records.created_at desc,
           maintenance_records.id desc
  limit 1;

  select maintenance_records.* into mileage_record
  from public.maintenance_records
  where maintenance_records.vehicle_id = target_vehicle.id
    and maintenance_records.next_service_mileage is not null
  order by maintenance_records.service_date desc,
           maintenance_records.created_at desc,
           maintenance_records.id desc
  limit 1;

  perform 1
  from public.maintenance_records
  where maintenance_records.id in (date_record.id, mileage_record.id)
  order by maintenance_records.id
  for update;

  foreach current_type in array array['maintenance_due_date', 'maintenance_due_mileage']::public.alert_type[]
  loop
    current_alert := null;
    if (
      select count(*)
      from public.alerts
      where alerts.vehicle_id = target_vehicle.id
        and alerts.alert_type = current_type
        and alerts.alert_state = 'active'
    ) > 1 then
      raise exception using errcode = 'P0001', message = 'maintenance_alert_integrity';
    end if;

    select alerts.* into current_alert
    from public.alerts
    where alerts.vehicle_id = target_vehicle.id
      and alerts.alert_type = current_type
      and alerts.alert_state = 'active'
    order by alerts.id
    for update;

    if current_type = 'maintenance_due_date' then
      date_remaining := case when date_record.id is null then null
        else date_record.next_service_date - evaluation_date end;
      condition_active := date_remaining is not null and date_remaining <= 14;
      expected_message := case
        when not condition_active then null
        when date_remaining > 0 then 'Vehicle maintenance is due by ' || date_record.next_service_date::text || '.'
        else 'Vehicle maintenance is overdue since ' || date_record.next_service_date::text || '.'
      end;
    else
      mileage_remaining := case when mileage_record.id is null then null
        else mileage_record.next_service_mileage - target_vehicle.mileage end;
      condition_active := mileage_remaining is not null and mileage_remaining <= 1000;
      expected_message := case
        when not condition_active then null
        when mileage_remaining > 0 then 'Vehicle maintenance is due in ' || mileage_remaining::text || ' km.'
        else 'Vehicle maintenance is overdue by ' || pg_catalog.abs(mileage_remaining)::text || ' km.'
      end;
    end if;

    if condition_active and current_alert.id is null then
      insert into public.alerts (id, alert_type, severity, message, vehicle_id, created_at)
      values (gen_random_uuid(), current_type, 'warning', expected_message, target_vehicle.id, evaluation_time);
      insert into public.activity_logs (
        id, actor_profile_id, action_type, vehicle_id, metadata, occurred_at
      ) values (
        gen_random_uuid(), lifecycle_actor_profile_id, 'alert_created', target_vehicle.id,
        pg_catalog.jsonb_build_object('alert_type', current_type), evaluation_time
      );
      created_total := created_total + 1;
    elsif condition_active and current_alert.id is not null
      and current_alert.message is distinct from expected_message then
      update public.alerts set message = expected_message where alerts.id = current_alert.id;
      updated_total := updated_total + 1;
    elsif not condition_active and current_alert.id is not null then
      update public.alerts
      set alert_state = 'resolved', resolved_at = evaluation_time,
          resolved_by_profile_id = lifecycle_actor_profile_id
      where alerts.id = current_alert.id and alerts.alert_state = 'active';
      if found then
        insert into public.activity_logs (
          id, actor_profile_id, action_type, vehicle_id, metadata, occurred_at
        ) values (
          gen_random_uuid(), lifecycle_actor_profile_id, 'alert_resolved', target_vehicle.id,
          pg_catalog.jsonb_build_object('alert_type', current_type), evaluation_time
        );
        resolved_total := resolved_total + 1;
      end if;
    end if;
  end loop;

  return query select created_total, resolved_total, updated_total;
end;
$function$;

create function public.list_maintenance_alert_vehicle_ids(after_vehicle_id uuid default null)
returns table (vehicle_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception using errcode = '42501', message = 'maintenance_alert_access_denied';
  end if;
  return query
  select vehicles.id
  from public.vehicles
  where after_vehicle_id is null or vehicles.id > after_vehicle_id
  order by vehicles.id
  limit 50;
end;
$function$;

create or replace function public.create_maintenance_record(
  target_vehicle_id uuid, input_service_type text, input_service_date date,
  input_mileage_at_service integer, input_workshop text default null,
  input_cost numeric default null, input_notes text default null,
  input_next_service_date date default null, input_next_service_mileage integer default null
)
returns uuid language plpgsql volatile security definer set search_path = '' as $function$
declare
  actor_id uuid := (select auth.uid()); actor_role public.profile_role;
  target_vehicle public.vehicles%rowtype; maintenance_id uuid := gen_random_uuid();
  normalized_service_type text := trim(input_service_type);
  normalized_workshop text := nullif(trim(input_workshop), '');
  normalized_notes text := nullif(trim(input_notes), '');
  normalized_cost numeric := round(input_cost, 2); mileage_updated boolean := false;
begin
  select profiles.role into actor_role from public.profiles where profiles.id = actor_id and profiles.is_active for update;
  if actor_role is distinct from 'admin' then raise exception using errcode='P0001',message='maintenance_mutation_access_denied'; end if;
  if normalized_service_type is null or normalized_service_type = '' or input_service_date is null
    or input_service_date > current_date or input_mileage_at_service is null or input_mileage_at_service < 0
    or input_cost is distinct from normalized_cost or normalized_cost < 0 or normalized_cost >= 10000000000
    or (input_next_service_date is not null and input_next_service_date <= input_service_date)
    or (input_next_service_mileage is not null and input_next_service_mileage <= input_mileage_at_service)
  then raise exception using errcode='P0001',message='maintenance_validation_failed'; end if;
  select * into target_vehicle from public.vehicles where id=target_vehicle_id for update;
  if not found then raise exception using errcode='P0001',message='maintenance_vehicle_not_found'; end if;
  insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service,workshop,cost,notes,next_service_date,next_service_mileage)
  values(maintenance_id,target_vehicle.id,normalized_service_type,input_service_date,input_mileage_at_service,normalized_workshop,normalized_cost,normalized_notes,input_next_service_date,input_next_service_mileage);
  if input_mileage_at_service > target_vehicle.mileage then update public.vehicles set mileage=input_mileage_at_service where id=target_vehicle.id; mileage_updated:=true; end if;
  insert into public.activity_logs(id,actor_profile_id,action_type,maintenance_record_id,metadata)
  values(gen_random_uuid(),actor_id,'maintenance_record_created',maintenance_id,pg_catalog.jsonb_build_object('vehicle_mileage_updated',mileage_updated));
  perform * from public.reconcile_vehicle_maintenance_alerts(target_vehicle.id, actor_id);
  return maintenance_id;
end;
$function$;

create or replace function public.update_maintenance_record(
  target_maintenance_record_id uuid, expected_updated_at timestamptz,
  input_service_type text, input_service_date date, input_mileage_at_service integer,
  input_workshop text default null, input_cost numeric default null,
  input_notes text default null, input_next_service_date date default null,
  input_next_service_mileage integer default null
)
returns text language plpgsql volatile security definer set search_path = '' as $function$
declare
  actor_id uuid := (select auth.uid()); actor_role public.profile_role; discovered_vehicle_id uuid;
  target_vehicle public.vehicles%rowtype; target_record public.maintenance_records%rowtype;
  normalized_service_type text := trim(input_service_type); normalized_workshop text := nullif(trim(input_workshop),'');
  normalized_notes text := nullif(trim(input_notes),''); normalized_cost numeric := round(input_cost,2);
  changed_fields text[] := array[]::text[]; mileage_updated boolean := false;
begin
  select profiles.role into actor_role from public.profiles where profiles.id=actor_id and profiles.is_active for update;
  if actor_role is distinct from 'admin' then raise exception using errcode='P0001',message='maintenance_mutation_access_denied'; end if;
  if normalized_service_type is null or normalized_service_type='' or input_service_date is null
    or input_service_date > current_date or input_mileage_at_service is null or input_mileage_at_service < 0
    or input_cost is distinct from normalized_cost or normalized_cost < 0 or normalized_cost >= 10000000000
    or (input_next_service_date is not null and input_next_service_date <= input_service_date)
    or (input_next_service_mileage is not null and input_next_service_mileage <= input_mileage_at_service)
  then raise exception using errcode='P0001',message='maintenance_validation_failed'; end if;
  select maintenance_records.vehicle_id into discovered_vehicle_id from public.maintenance_records where maintenance_records.id=target_maintenance_record_id;
  if not found then raise exception using errcode='P0001',message='maintenance_record_not_found'; end if;
  select * into target_vehicle from public.vehicles where id=discovered_vehicle_id for update;
  if not found then raise exception using errcode='P0001',message='maintenance_vehicle_not_found'; end if;
  select * into target_record from public.maintenance_records where id=target_maintenance_record_id for update;
  if not found then raise exception using errcode='P0001',message='maintenance_record_not_found'; end if;
  if target_record.vehicle_id is distinct from discovered_vehicle_id then raise exception using errcode='P0001',message='maintenance_record_vehicle_changed'; end if;
  if target_record.updated_at is distinct from expected_updated_at then raise exception using errcode='P0001',message='maintenance_record_stale'; end if;
  if target_record.service_type is distinct from normalized_service_type then changed_fields:=array_append(changed_fields,'service_type'); end if;
  if target_record.service_date is distinct from input_service_date then changed_fields:=array_append(changed_fields,'service_date'); end if;
  if target_record.mileage_at_service is distinct from input_mileage_at_service then changed_fields:=array_append(changed_fields,'mileage_at_service'); end if;
  if target_record.workshop is distinct from normalized_workshop then changed_fields:=array_append(changed_fields,'workshop'); end if;
  if target_record.cost is distinct from normalized_cost then changed_fields:=array_append(changed_fields,'cost'); end if;
  if target_record.notes is distinct from normalized_notes then changed_fields:=array_append(changed_fields,'notes'); end if;
  if target_record.next_service_date is distinct from input_next_service_date then changed_fields:=array_append(changed_fields,'next_service_date'); end if;
  if target_record.next_service_mileage is distinct from input_next_service_mileage then changed_fields:=array_append(changed_fields,'next_service_mileage'); end if;
  if cardinality(changed_fields)=0 then return 'noop'; end if;
  update public.maintenance_records set service_type=normalized_service_type,service_date=input_service_date,mileage_at_service=input_mileage_at_service,
    workshop=normalized_workshop,cost=normalized_cost,notes=normalized_notes,next_service_date=input_next_service_date,next_service_mileage=input_next_service_mileage
  where id=target_record.id;
  if input_mileage_at_service > target_vehicle.mileage then update public.vehicles set mileage=input_mileage_at_service where id=target_vehicle.id; mileage_updated:=true; end if;
  insert into public.activity_logs(id,actor_profile_id,action_type,maintenance_record_id,metadata)
  values(gen_random_uuid(),actor_id,'maintenance_record_updated',target_record.id,pg_catalog.jsonb_build_object('changed_fields',to_jsonb(changed_fields),'vehicle_mileage_updated',mileage_updated));
  perform * from public.reconcile_vehicle_maintenance_alerts(target_vehicle.id, actor_id);
  return 'updated';
end;
$function$;

create or replace function public.update_vehicle_mileage(target_vehicle_id uuid, expected_updated_at timestamptz, new_mileage integer)
returns text language plpgsql security definer set search_path = '' as $function$
declare actor_id uuid := (select auth.uid()); current_vehicle public.vehicles%rowtype;
begin
  if not exists(select 1 from public.profiles where id=actor_id and is_active and role='admin') then raise exception using errcode='P0001',message='vehicle_mutation_access_denied'; end if;
  if new_mileage is null or new_mileage < 0 then raise exception using errcode='P0001',message='vehicle_validation_failed'; end if;
  select * into current_vehicle from public.vehicles where id=target_vehicle_id for update;
  if not found then raise exception using errcode='P0001',message='vehicle_not_found'; end if;
  if current_vehicle.updated_at is distinct from expected_updated_at then raise exception using errcode='P0001',message='vehicle_stale'; end if;
  if new_mileage < current_vehicle.mileage then raise exception using errcode='P0001',message='vehicle_mileage_decrease'; end if;
  if new_mileage=current_vehicle.mileage then return 'noop'; end if;
  update public.vehicles set mileage=new_mileage where id=target_vehicle_id;
  insert into public.activity_logs(id,actor_profile_id,action_type,vehicle_id,metadata)
  values(gen_random_uuid(),actor_id,'vehicle_updated',target_vehicle_id,pg_catalog.jsonb_build_object('field','mileage','from',current_vehicle.mileage,'to',new_mileage,'unit','km'));
  perform * from public.reconcile_vehicle_maintenance_alerts(target_vehicle_id, actor_id);
  return 'updated';
end;
$function$;

revoke all on function public.reconcile_vehicle_maintenance_alerts(uuid, uuid) from public, anon, authenticated;
revoke all on function public.list_maintenance_alert_vehicle_ids(uuid) from public, anon, authenticated;
grant execute on function public.reconcile_vehicle_maintenance_alerts(uuid, uuid) to service_role;
grant execute on function public.list_maintenance_alert_vehicle_ids(uuid) to service_role;

select cron.unschedule('logiflow-reconcile-stale-locations-every-minute');
select cron.schedule(
  'logiflow-reconcile-stale-locations-every-minute', '* * * * *',
  $schedule$select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='project_url') || '/functions/v1/reconcile-operational-alerts',
    headers := pg_catalog.jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='scheduler_shared_secret')),
    body := '{"job":"stale_vehicle_locations"}'::jsonb
  );$schedule$
);

select cron.schedule(
  'logiflow-reconcile-maintenance-daily', '0 2 * * *',
  $schedule$select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='project_url') || '/functions/v1/reconcile-operational-alerts',
    headers := pg_catalog.jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='scheduler_shared_secret')),
    body := '{"job":"maintenance"}'::jsonb
  );$schedule$
);
