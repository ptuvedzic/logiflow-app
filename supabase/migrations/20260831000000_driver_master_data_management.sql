do $$
begin
  if exists (
    select 1
    from public.drivers
    where phone is not null
      and (trim(phone) = '' or char_length(trim(phone)) > 32)
  ) then
    raise exception 'Existing Driver phone data violates the MD-D1 phone contract.';
  end if;
end;
$$;

alter table public.drivers
  drop constraint drivers_phone_nonblank_check,
  add constraint drivers_phone_contract_check check (
    phone is null
    or (trim(phone) <> '' and char_length(trim(phone)) <= 32)
  );

create function public.current_active_profile_role()
returns public.profile_role
language sql
stable
security definer
set search_path = ''
as $function$
  select profiles.role
  from public.profiles
  where profiles.id = (select auth.uid())
    and profiles.is_active
$function$;

revoke all on function public.current_active_profile_role() from public, anon;
grant execute on function public.current_active_profile_role() to authenticated;

grant select (phone, status, updated_at) on table public.drivers to authenticated;
grant update (phone) on table public.drivers to authenticated;

create policy drivers_operations_select
on public.drivers
for select
to authenticated
using (
  (select public.current_active_profile_role()) in ('admin', 'dispatcher')
);

create policy profiles_operations_driver_select
on public.profiles
for select
to authenticated
using (
  role = 'driver'
  and (select public.current_active_profile_role()) in ('admin', 'dispatcher')
);

create policy drivers_admin_phone_update
on public.drivers
for update
to authenticated
using (
  (select public.current_active_profile_role()) = 'admin'
  and exists (
    select 1
    from public.profiles target_profile
    where target_profile.id = drivers.profile_id
      and target_profile.role = 'driver'
      and target_profile.is_active
  )
)
with check (
  (select public.current_active_profile_role()) = 'admin'
  and exists (
    select 1
    from public.profiles target_profile
    where target_profile.id = drivers.profile_id
      and target_profile.role = 'driver'
      and target_profile.is_active
  )
);

create function public.authorize_driver_phone_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null and current_user in ('postgres', 'service_role') then
    new.phone := nullif(trim(new.phone), '');
    return new;
  end if;

  if (select public.current_active_profile_role()) is distinct from 'admin'::public.profile_role
    or not exists (
      select 1
      from public.profiles target_profile
      where target_profile.id = old.profile_id
        and target_profile.role = 'driver'
        and target_profile.is_active
    ) then
    raise exception using errcode = '42501', message = 'driver_phone_access_denied';
  end if;

  if new.id is distinct from old.id
    or new.profile_id is distinct from old.profile_id
    or new.status is distinct from old.status
    or new.created_at is distinct from old.created_at then
    raise exception using errcode = '42501', message = 'driver_protected_field_update_denied';
  end if;

  new.phone := nullif(trim(new.phone), '');

  if new.phone is not distinct from old.phone then
    return null;
  end if;

  return new;
end;
$function$;

revoke all on function public.authorize_driver_phone_update() from public, anon, authenticated;

create trigger drivers_authorize_phone_update
before update of phone on public.drivers
for each row execute function public.authorize_driver_phone_update();

create function public.change_driver_operational_status(
  target_driver_id uuid,
  requested_operation text
)
returns public.driver_status
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  target_profile_id uuid;
  target_profile public.profiles%rowtype;
  target_driver public.drivers%rowtype;
  blocking_shipment_id uuid;
  next_status public.driver_status;
begin
  if actor_id is null or not exists (
    select 1
    from public.profiles actor_profile
    where actor_profile.id = actor_id
      and actor_profile.is_active
      and actor_profile.role = 'admin'
  ) then
    raise exception using errcode = '42501', message = 'driver_status_access_denied';
  end if;

  if target_driver_id is null
    or requested_operation is null
    or requested_operation not in ('mark_off_duty', 'mark_available', 'archive', 'reactivate') then
    raise exception using errcode = '22023', message = 'driver_status_operation_invalid';
  end if;

  select drivers.profile_id
  into target_profile_id
  from public.drivers
  where drivers.id = target_driver_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'driver_target_unavailable';
  end if;

  select profiles.*
  into target_profile
  from public.profiles
  where profiles.id = target_profile_id
  for update;

  if not found
    or target_profile.role <> 'driver'
    or not target_profile.is_active then
    raise exception using errcode = 'P0002', message = 'driver_target_unavailable';
  end if;

  select drivers.*
  into target_driver
  from public.drivers
  where drivers.id = target_driver_id
    and drivers.profile_id = target_profile.id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'driver_target_unavailable';
  end if;

  if not exists (
    select 1
    from public.profiles actor_profile
    where actor_profile.id = actor_id
      and actor_profile.is_active
      and actor_profile.role = 'admin'
  ) then
    raise exception using errcode = '42501', message = 'driver_status_access_denied';
  end if;

  select shipments.id
  into blocking_shipment_id
  from public.shipments
  where shipments.driver_id = target_driver.id
    and shipments.status in ('assigned', 'loading', 'in_transit')
  limit 1
  for update;

  if blocking_shipment_id is not null then
    raise exception using errcode = 'P0001', message = 'driver_status_active_shipment';
  end if;

  next_status := case requested_operation
    when 'mark_off_duty' then
      case when target_driver.status = 'available' then 'off_duty'::public.driver_status end
    when 'mark_available' then
      case when target_driver.status = 'off_duty' then 'available'::public.driver_status end
    when 'archive' then
      case when target_driver.status in ('available', 'off_duty') then 'archived'::public.driver_status end
    when 'reactivate' then
      case when target_driver.status = 'archived' then 'available'::public.driver_status end
  end;

  if next_status is null then
    raise exception using errcode = 'P0001', message = 'driver_status_transition_invalid';
  end if;

  update public.drivers
  set status = next_status
  where id = target_driver.id;

  insert into public.activity_logs (
    id,
    actor_profile_id,
    action_type,
    driver_id,
    metadata
  ) values (
    gen_random_uuid(),
    actor_id,
    'driver_status_changed',
    target_driver.id,
    jsonb_build_object(
      'from_status', target_driver.status,
      'to_status', next_status,
      'operation', requested_operation
    )
  );

  return next_status;
end;
$function$;

revoke all on function public.change_driver_operational_status(uuid, text) from public, anon;
grant execute on function public.change_driver_operational_status(uuid, text) to authenticated;

comment on function public.change_driver_operational_status(uuid, text) is
  'Admin-only Driver operational transition. Locks profile, Driver, then blocking Shipment and records one activity atomically.';
