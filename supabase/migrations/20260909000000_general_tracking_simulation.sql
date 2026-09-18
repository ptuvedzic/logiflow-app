alter table public.alerts
  drop constraint alerts_resolution_state_check;

alter table public.alerts
  add constraint alerts_resolution_state_check check (
    (alert_state = 'active' and resolved_at is null and resolved_by_profile_id is null)
    or (alert_state = 'resolved' and resolved_at is not null)
  );

create function public.list_tracking_simulation_shipments()
returns table (shipment_id uuid)
language sql
stable
security definer
set search_path = ''
as $function$
  select shipments.id
  from public.shipments
  join public.vehicle_locations on vehicle_locations.shipment_id = shipments.id
  where shipments.status = 'in_transit'
    and shipments.vehicle_id = vehicle_locations.vehicle_id
  order by shipments.id
  limit 50;
$function$;

create function public.simulate_tracking_step(
  target_shipment_id uuid,
  route_coordinates jsonb
)
returns table (step_result text)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  target_shipment public.shipments%rowtype;
  current_location public.vehicle_locations%rowtype;
  current_alert public.alerts%rowtype;
  route_size integer;
  total_distance_km double precision;
  previous_distance_km double precision;
  advanced_distance_km double precision;
  next_distance_km double precision;
  next_progress double precision;
  computed_latitude double precision;
  computed_longitude double precision;
  computed_heading double precision;
  next_speed numeric(6,2);
  elapsed_seconds double precision;
  latest_snapshot_at timestamptz;
  movement_occurred boolean;
  update_time timestamptz := pg_catalog.clock_timestamp();
begin
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended(target_shipment_id::text, 0)) then
    return query select 'skipped_locked'::text;
    return;
  end if;

  select shipments.* into target_shipment
  from public.shipments
  where shipments.id = target_shipment_id
  for update;

  if not found or target_shipment.status <> 'in_transit' or target_shipment.vehicle_id is null then
    return query select 'skipped_ineligible'::text;
    return;
  end if;

  select vehicle_locations.* into current_location
  from public.vehicle_locations
  where vehicle_locations.vehicle_id = target_shipment.vehicle_id
    and vehicle_locations.shipment_id = target_shipment.id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'tracking_integrity';
  end if;

  if pg_catalog.jsonb_typeof(route_coordinates) <> 'array' then
    raise exception using errcode = '22023', message = 'tracking_route_invalid';
  end if;

  route_size := pg_catalog.jsonb_array_length(route_coordinates);
  if route_size < 2 or exists (
    select 1
    from pg_catalog.jsonb_array_elements(route_coordinates) as points(point)
    where pg_catalog.jsonb_typeof(points.point) <> 'array'
       or pg_catalog.jsonb_array_length(points.point) <> 2
       or pg_catalog.jsonb_typeof(points.point -> 0) <> 'number'
       or pg_catalog.jsonb_typeof(points.point -> 1) <> 'number'
       or ((points.point ->> 0)::double precision not between -180 and 180)
       or ((points.point ->> 1)::double precision not between -90 and 90)
  ) then
    raise exception using errcode = '22023', message = 'tracking_route_invalid';
  end if;

  if pg_catalog.abs(((route_coordinates -> 0 ->> 1)::double precision) - 45.2671) > 0.00001
     or pg_catalog.abs(((route_coordinates -> 0 ->> 0)::double precision) - 19.8335) > 0.00001
     or pg_catalog.abs(((route_coordinates -> (route_size - 1) ->> 1)::double precision) - 44.7866) > 0.00001
     or pg_catalog.abs(((route_coordinates -> (route_size - 1) ->> 0)::double precision) - 20.4489) > 0.00001 then
    raise exception using errcode = '22023', message = 'tracking_route_endpoints_invalid';
  end if;

  with points as (
    select point_index::integer,
           (point ->> 0)::double precision as longitude,
           (point ->> 1)::double precision as latitude
    from pg_catalog.jsonb_array_elements(route_coordinates) with ordinality as route(point, point_index)
  ), segments as (
    select point_index,
           6371.0088 * 2 * pg_catalog.asin(pg_catalog.sqrt(
             pg_catalog.power(pg_catalog.sin(pg_catalog.radians(next_latitude - latitude) / 2), 2)
             + pg_catalog.cos(pg_catalog.radians(latitude)) * pg_catalog.cos(pg_catalog.radians(next_latitude))
             * pg_catalog.power(pg_catalog.sin(pg_catalog.radians(next_longitude - longitude) / 2), 2)
           )) as distance_km
    from (
      select *, lead(latitude) over (order by point_index) as next_latitude,
                lead(longitude) over (order by point_index) as next_longitude
      from points
    ) pairs
    where next_latitude is not null
  )
  select sum(distance_km) into total_distance_km from segments;

  if total_distance_km is null or total_distance_km <= 0 then
    raise exception using errcode = '22023', message = 'tracking_route_invalid';
  end if;

  elapsed_seconds := greatest(0, extract(epoch from update_time - current_location.updated_at));
  previous_distance_km := total_distance_km * coalesce(current_location.route_progress, 0)::double precision / 100;
  advanced_distance_km := elapsed_seconds * 60 / 3600;
  next_distance_km := least(total_distance_km, previous_distance_km + advanced_distance_km);
  next_progress := greatest(coalesce(current_location.route_progress, 0)::double precision,
                            least(100, next_distance_km / total_distance_km * 100));
  movement_occurred := next_distance_km > previous_distance_km and next_progress > coalesce(current_location.route_progress, 0);

  with points as (
    select point_index::integer,
           (point ->> 0)::double precision as longitude,
           (point ->> 1)::double precision as latitude
    from pg_catalog.jsonb_array_elements(route_coordinates) with ordinality as route(point, point_index)
  ), segments as (
    select point_index, longitude, latitude, next_longitude, next_latitude,
           6371.0088 * 2 * pg_catalog.asin(pg_catalog.sqrt(
             pg_catalog.power(pg_catalog.sin(pg_catalog.radians(next_latitude - latitude) / 2), 2)
             + pg_catalog.cos(pg_catalog.radians(latitude)) * pg_catalog.cos(pg_catalog.radians(next_latitude))
             * pg_catalog.power(pg_catalog.sin(pg_catalog.radians(next_longitude - longitude) / 2), 2)
           )) as distance_km
    from (
      select *, lead(latitude) over (order by point_index) as next_latitude,
                lead(longitude) over (order by point_index) as next_longitude
      from points
    ) pairs
    where next_latitude is not null
  ), positioned as (
    select *, coalesce(sum(distance_km) over (order by point_index rows between unbounded preceding and 1 preceding), 0) as distance_before
    from segments
  )
  select
    latitude + (next_latitude - latitude) * least(1, greatest(0, (next_distance_km - distance_before) / nullif(distance_km, 0))),
    longitude + (next_longitude - longitude) * least(1, greatest(0, (next_distance_km - distance_before) / nullif(distance_km, 0))),
    pg_catalog.mod((pg_catalog.degrees(pg_catalog.atan2(
      pg_catalog.sin(pg_catalog.radians(next_longitude - longitude)) * pg_catalog.cos(pg_catalog.radians(next_latitude)),
      pg_catalog.cos(pg_catalog.radians(latitude)) * pg_catalog.sin(pg_catalog.radians(next_latitude))
      - pg_catalog.sin(pg_catalog.radians(latitude)) * pg_catalog.cos(pg_catalog.radians(next_latitude))
      * pg_catalog.cos(pg_catalog.radians(next_longitude - longitude))
    )) + 360)::numeric, 360::numeric)::double precision
  into computed_latitude, computed_longitude, computed_heading
  from positioned
  where next_distance_km <= distance_before + distance_km or point_index = route_size - 1
  order by point_index
  limit 1;

  next_speed := case when next_progress >= 100 then 0 else 60 end;

  select alerts.* into current_alert
  from public.alerts
  where alerts.alert_type = 'stale_vehicle_location'
    and alerts.alert_state = 'active'
    and alerts.vehicle_id = current_location.vehicle_id
  for update;

  update public.vehicle_locations
  set latitude = computed_latitude,
      longitude = computed_longitude,
      speed = next_speed,
      heading = computed_heading,
      route_progress = round(next_progress::numeric, 2),
      updated_at = update_time
  where vehicle_locations.vehicle_id = current_location.vehicle_id
    and vehicle_locations.shipment_id = current_location.shipment_id
    and vehicle_locations.updated_at = current_location.updated_at;

  if not found then
    return query select 'skipped_concurrent'::text;
    return;
  end if;

  if movement_occurred then
    select max(tracking_history.recorded_at) into latest_snapshot_at
    from public.tracking_history
    where tracking_history.shipment_id = current_location.shipment_id;

    if latest_snapshot_at is null or update_time - latest_snapshot_at >= interval '60 seconds' then
      insert into public.tracking_history (
        id, vehicle_id, shipment_id, latitude, longitude, speed, heading, route_progress, recorded_at
      ) values (
        gen_random_uuid(), current_location.vehicle_id, current_location.shipment_id,
        computed_latitude, computed_longitude, next_speed, computed_heading, round(next_progress::numeric, 2), update_time
      );
    end if;
  end if;

  if current_alert.id is not null then
    update public.alerts
    set alert_state = 'resolved', resolved_at = update_time, resolved_by_profile_id = null
    where alerts.id = current_alert.id and alerts.alert_state = 'active';

    if found then
      insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
      values (gen_random_uuid(), null, 'alert_resolved', current_location.vehicle_id,
              pg_catalog.jsonb_build_object('alert_type', 'stale_vehicle_location'));
    end if;
  end if;

  return query select case when next_progress >= 100 then 'heartbeat'::text else 'advanced'::text end;
end;
$function$;

create function public.reconcile_stale_vehicle_locations()
returns table (created_count integer, resolved_count integer)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  location_row public.vehicle_locations%rowtype;
  alert_row public.alerts%rowtype;
  evaluation_time timestamptz := pg_catalog.clock_timestamp();
  created_total integer := 0;
  resolved_total integer := 0;
begin
  for location_row in
    select vehicle_locations.*
    from public.vehicle_locations
    where vehicle_locations.updated_at <= evaluation_time - interval '10 minutes'
       or exists (
         select 1 from public.alerts
         where alerts.vehicle_id = vehicle_locations.vehicle_id
           and alerts.alert_type = 'stale_vehicle_location'
           and alerts.alert_state = 'active'
       )
    order by vehicle_locations.updated_at, vehicle_locations.vehicle_id
    limit 50
    for update of vehicle_locations skip locked
  loop
    alert_row := null;
    select alerts.* into alert_row
    from public.alerts
    where alerts.vehicle_id = location_row.vehicle_id
      and alerts.alert_type = 'stale_vehicle_location'
      and alerts.alert_state = 'active'
    for update;

    if location_row.updated_at <= evaluation_time - interval '10 minutes' and alert_row.id is null then
      insert into public.alerts (id, alert_type, severity, message, vehicle_id)
      values (gen_random_uuid(), 'stale_vehicle_location', 'critical',
              'Vehicle location has not updated for more than 10 minutes.', location_row.vehicle_id);
      insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
      values (gen_random_uuid(), null, 'alert_created', location_row.vehicle_id,
              pg_catalog.jsonb_build_object('alert_type', 'stale_vehicle_location'));
      created_total := created_total + 1;
    elsif location_row.updated_at > evaluation_time - interval '10 minutes' and alert_row.id is not null then
      update public.alerts
      set alert_state = 'resolved', resolved_at = evaluation_time, resolved_by_profile_id = null
      where alerts.id = alert_row.id and alerts.alert_state = 'active';
      if found then
        insert into public.activity_logs (id, actor_profile_id, action_type, vehicle_id, metadata)
        values (gen_random_uuid(), null, 'alert_resolved', location_row.vehicle_id,
                pg_catalog.jsonb_build_object('alert_type', 'stale_vehicle_location'));
        resolved_total := resolved_total + 1;
      end if;
    end if;
  end loop;

  return query select created_total, resolved_total;
end;
$function$;

create policy vehicle_locations_operations_select
on public.vehicle_locations for select to authenticated
using (
  exists (
    select 1 from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  )
);

create policy vehicle_locations_driver_select
on public.vehicle_locations for select to authenticated
using (
  exists (
    select 1
    from public.profiles
    join public.drivers on drivers.profile_id = profiles.id
    join public.shipments on shipments.driver_id = drivers.id
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'driver'
      and shipments.id = vehicle_locations.shipment_id
      and shipments.vehicle_id = vehicle_locations.vehicle_id
      and shipments.status = 'in_transit'
  )
);

grant select on table public.vehicle_locations to authenticated;
revoke insert, update, delete on table public.vehicle_locations from anon, authenticated;

revoke all on function public.list_tracking_simulation_shipments() from public, anon, authenticated;
revoke all on function public.simulate_tracking_step(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.reconcile_stale_vehicle_locations() from public, anon, authenticated;
grant execute on function public.list_tracking_simulation_shipments() to service_role;
grant execute on function public.simulate_tracking_step(uuid, jsonb) to service_role;
grant execute on function public.reconcile_stale_vehicle_locations() to service_role;

do $block$
begin
  if not exists (
    select 1 from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'vehicle_locations'
  ) then
    alter publication supabase_realtime add table public.vehicle_locations;
  end if;
end;
$block$;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'logiflow-simulate-tracking-every-10-seconds',
  '10 seconds',
  $schedule$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/simulate-tracking',
      headers := pg_catalog.jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'scheduler_shared_secret')
      ),
      body := '{}'::jsonb
    );
  $schedule$
);

select cron.schedule(
  'logiflow-reconcile-stale-locations-every-minute',
  '* * * * *',
  $schedule$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url') || '/functions/v1/reconcile-operational-alerts',
      headers := pg_catalog.jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'scheduler_shared_secret')
      ),
      body := '{}'::jsonb
    );
  $schedule$
);
