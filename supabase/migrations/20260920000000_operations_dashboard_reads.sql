create function public.get_operations_dashboard_kpis()
returns table (
  active_shipments bigint,
  in_use_vehicles bigint,
  assigned_drivers bigint,
  active_alerts bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using
      errcode = '42501',
      message = 'operations_dashboard_read_access_denied';
  end if;

  return query
  select
    (select count(*) from public.shipments where shipments.status in ('assigned', 'loading', 'in_transit')),
    (select count(*) from public.vehicles where vehicles.status = 'in_use'),
    (select count(*) from public.drivers where drivers.status = 'assigned'),
    (select count(*) from public.alerts where alerts.alert_state = 'active');
end;
$function$;

create function public.list_operations_dashboard_pending_status_requests(preview_limit integer)
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
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using
      errcode = '42501',
      message = 'operations_dashboard_read_access_denied';
  end if;

  if preview_limit is null or preview_limit < 1 or preview_limit > 5 then
    raise exception using
      errcode = '22023',
      message = 'operations_dashboard_preview_limit_invalid';
  end if;

  return query
  select
    requests.id,
    shipments.tracking_number,
    profiles.full_name,
    requests.current_status,
    requests.requested_status,
    requests.requested_at
  from public.shipment_status_requests requests
  join public.shipments on shipments.id = requests.shipment_id
  join public.drivers on drivers.id = requests.driver_id
  join public.profiles on profiles.id = drivers.profile_id
  where requests.request_state = 'pending'
  order by requests.requested_at asc, requests.id asc
  limit preview_limit;
end;
$function$;

revoke all on function public.get_operations_dashboard_kpis() from public, anon, authenticated;
revoke all on function public.list_operations_dashboard_pending_status_requests(integer) from public, anon, authenticated;

grant execute on function public.get_operations_dashboard_kpis() to authenticated;
grant execute on function public.list_operations_dashboard_pending_status_requests(integer) to authenticated;

comment on function public.get_operations_dashboard_kpis() is
  'Read-only current operational KPI projection for active Admin and Dispatcher profiles.';
comment on function public.list_operations_dashboard_pending_status_requests(integer) is
  'Read-only bounded pending status-request preview for the Operations dashboard.';
