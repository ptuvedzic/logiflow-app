create function public.get_admin_reports(report_from date, report_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  belgrade_today date := (pg_catalog.now() at time zone 'Europe/Belgrade')::date;
  period_start timestamptz;
  period_end timestamptz;
  bucket_granularity text;
  report_result jsonb;
begin
  if not exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'admin'
  ) then
    raise exception using errcode = '42501', message = 'admin_reports_access_denied';
  end if;

  if report_from is null
    or report_to is null
    or report_from > report_to
    or report_to > belgrade_today
    or report_to - report_from > 365
  then
    raise exception using errcode = '22023', message = 'admin_reports_date_invalid';
  end if;

  period_start := report_from::timestamp at time zone 'Europe/Belgrade';
  period_end := (report_to + 1)::timestamp at time zone 'Europe/Belgrade';
  bucket_granularity := case
    when report_to - report_from <= 30 then 'day'
    when report_to - report_from <= 91 then 'week'
    else 'month'
  end;

  with
  delivered_shipments as materialized (
    select
      shipments.id,
      shipments.client_id,
      shipments.driver_id,
      shipments.price,
      requests.resolved_at
    from public.shipment_status_requests requests
    join public.shipments on shipments.id = requests.shipment_id
    where requests.request_state = 'approved'
      and requests.requested_status = 'delivered'
      and requests.resolved_at >= period_start
      and requests.resolved_at < period_end
      and shipments.status = 'delivered'
  ),
  delivered_finances as materialized (
    select
      delivered_shipments.id,
      delivered_shipments.client_id,
      delivered_shipments.driver_id,
      delivered_shipments.price as revenue,
      coalesce(sum(expenses.amount), 0::numeric) as expenses
    from delivered_shipments
    left join public.expenses on expenses.shipment_id = delivered_shipments.id
    group by delivered_shipments.id, delivered_shipments.client_id,
      delivered_shipments.driver_id, delivered_shipments.price
  ),
  pickup_shipments as materialized (
    select shipments.id, shipments.status, shipments.delayed, shipments.pickup_at
    from public.shipments
    where shipments.pickup_at >= period_start
      and shipments.pickup_at < period_end
  ),
  shipment_statuses as (
    select
      statuses.status,
      count(pickup_shipments.id)::bigint as shipment_count,
      pg_catalog.array_position(pg_catalog.enum_range(null::public.shipment_status), statuses.status) as status_order
    from pg_catalog.unnest(pg_catalog.enum_range(null::public.shipment_status)) statuses(status)
    left join pickup_shipments on pickup_shipments.status = statuses.status
    group by statuses.status
  ),
  bucket_starts as (
    select bucket_start::date as bucket_start
    from pg_catalog.generate_series(
      case bucket_granularity
        when 'day' then report_from::timestamp
        when 'week' then pg_catalog.date_trunc('week', report_from::timestamp)
        else pg_catalog.date_trunc('month', report_from::timestamp)
      end,
      report_to::timestamp,
      case bucket_granularity
        when 'day' then interval '1 day'
        when 'week' then interval '1 week'
        else interval '1 month'
      end
    ) bucket_start
  ),
  shipment_volume as (
    select
      greatest(bucket_starts.bucket_start, report_from) as bucket_start,
      least(
        case bucket_granularity
          when 'day' then bucket_starts.bucket_start
          when 'week' then bucket_starts.bucket_start + 6
          else (bucket_starts.bucket_start + interval '1 month - 1 day')::date
        end,
        report_to
      ) as bucket_end,
      count(pickup_shipments.id)::bigint as shipment_count
    from bucket_starts
    left join pickup_shipments on
      case bucket_granularity
        when 'day' then (pickup_shipments.pickup_at at time zone 'Europe/Belgrade')::date = bucket_starts.bucket_start
        when 'week' then pg_catalog.date_trunc('week', pickup_shipments.pickup_at at time zone 'Europe/Belgrade')::date = bucket_starts.bucket_start
        else pg_catalog.date_trunc('month', pickup_shipments.pickup_at at time zone 'Europe/Belgrade')::date = bucket_starts.bucket_start
      end
    group by bucket_starts.bucket_start
    order by bucket_starts.bucket_start
  ),
  vehicle_statuses as (
    select statuses.status, count(vehicles.id)::bigint as vehicle_count,
      pg_catalog.array_position(pg_catalog.enum_range(null::public.vehicle_status), statuses.status) as status_order
    from pg_catalog.unnest(pg_catalog.enum_range(null::public.vehicle_status)) statuses(status)
    left join public.vehicles on vehicles.status = statuses.status
    group by statuses.status
  ),
  driver_statuses as (
    select statuses.status, count(drivers.id)::bigint as driver_count,
      pg_catalog.array_position(pg_catalog.enum_range(null::public.driver_status), statuses.status) as status_order
    from pg_catalog.unnest(pg_catalog.enum_range(null::public.driver_status)) statuses(status)
    left join public.drivers on drivers.status = statuses.status
    group by statuses.status
  ),
  driver_completions as (
    select
      drivers.id,
      profiles.full_name,
      count(delivered_finances.id)::bigint as completed_shipments
    from delivered_finances
    join public.drivers on drivers.id = delivered_finances.driver_id
    join public.profiles on profiles.id = drivers.profile_id
    group by drivers.id, profiles.full_name
    order by count(delivered_finances.id) desc, pg_catalog.lower(profiles.full_name), drivers.id
    limit 100
  ),
  client_results as (
    select
      clients.id,
      clients.company_name,
      count(delivered_finances.id)::bigint as completed_shipments,
      sum(delivered_finances.revenue)::numeric as revenue
    from delivered_finances
    join public.clients on clients.id = delivered_finances.client_id
    group by clients.id, clients.company_name
    order by sum(delivered_finances.revenue) desc,
      count(delivered_finances.id) desc, pg_catalog.lower(clients.company_name), clients.id
    limit 100
  ),
  fleet_totals as (
    select
      count(*) filter (where vehicles.status = 'available')::bigint as available_vehicles,
      count(*) filter (where vehicles.status = 'in_use')::bigint as in_use_vehicles
    from public.vehicles
  ),
  maintenance_totals as (
    select
      count(*)::bigint as maintenance_records,
      count(distinct maintenance_records.vehicle_id)::bigint as vehicles_serviced,
      count(maintenance_records.cost)::bigint as costed_records,
      coalesce(sum(maintenance_records.cost), 0::numeric) as recorded_cost
    from public.maintenance_records
    where maintenance_records.service_date between report_from and report_to
  )
  select pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object(
      'from', report_from,
      'to', report_to,
      'bucket_granularity', bucket_granularity
    ),
    'financial', pg_catalog.jsonb_build_object(
      'completed_shipments', (select count(*) from delivered_finances),
      'revenue', (select coalesce(sum(revenue), 0::numeric) from delivered_finances),
      'total_expenses', (select coalesce(sum(expenses), 0::numeric) from delivered_finances),
      'profit', (select coalesce(sum(revenue - expenses), 0::numeric) from delivered_finances)
    ),
    'shipments', pg_catalog.jsonb_build_object(
      'scheduled_shipments', (select count(*) from pickup_shipments),
      'completed_shipments', (select count(*) from delivered_shipments),
      'delayed_shipments', (select count(*) from pickup_shipments where delayed),
      'statuses', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'status', status, 'count', shipment_count
      ) order by status_order), '[]'::jsonb) from shipment_statuses),
      'volume', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'bucket_start', bucket_start, 'bucket_end', bucket_end, 'count', shipment_count
      ) order by bucket_start), '[]'::jsonb) from shipment_volume)
    ),
    'fleet', pg_catalog.jsonb_build_object(
      'available_vehicles', (select available_vehicles from fleet_totals),
      'in_use_vehicles', (select in_use_vehicles from fleet_totals),
      'serviceable_vehicles', (select available_vehicles + in_use_vehicles from fleet_totals),
      'utilization_percent', (select case
        when available_vehicles + in_use_vehicles = 0 then null
        else pg_catalog.round(in_use_vehicles::numeric * 100 / (available_vehicles + in_use_vehicles), 2)
      end from fleet_totals),
      'statuses', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'status', status, 'count', vehicle_count
      ) order by status_order), '[]'::jsonb) from vehicle_statuses),
      'maintenance', (select pg_catalog.jsonb_build_object(
        'records', maintenance_records,
        'vehicles_serviced', vehicles_serviced,
        'costed_records', costed_records,
        'recorded_cost', recorded_cost
      ) from maintenance_totals)
    ),
    'drivers', pg_catalog.jsonb_build_object(
      'statuses', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'status', status, 'count', driver_count
      ) order by status_order), '[]'::jsonb) from driver_statuses),
      'completions', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'driver_id', id, 'driver_name', full_name, 'completed_shipments', completed_shipments
      ) order by completed_shipments desc, pg_catalog.lower(full_name), id), '[]'::jsonb) from driver_completions)
    ),
    'clients', (select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'client_id', id, 'company_name', company_name,
      'completed_shipments', completed_shipments, 'revenue', revenue
    ) order by revenue desc, completed_shipments desc, pg_catalog.lower(company_name), id), '[]'::jsonb) from client_results)
  ) into report_result;

  return report_result;
end;
$function$;

revoke all on function public.get_admin_reports(date, date) from public, anon, authenticated;
grant execute on function public.get_admin_reports(date, date) to authenticated;

comment on function public.get_admin_reports(date, date) is
  'Read-only Admin Reports snapshot. Delivered finance uses approved delivered request resolution time and all retained Shipment expenses.';
