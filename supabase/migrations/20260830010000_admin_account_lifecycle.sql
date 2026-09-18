create function public.set_managed_account_active_state(
  target_username text,
  requested_active boolean
)
returns table (
  account_role public.profile_role,
  account_is_active boolean
)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  target_profile public.profiles%rowtype;
  target_driver public.drivers%rowtype;
begin
  if target_username is null or trim(target_username) = '' or requested_active is null then
    raise exception using
      errcode = '22023',
      message = 'Invalid account lifecycle request.';
  end if;

  select profiles.*
  into target_profile
  from public.profiles
  where lower(profiles.username) = lower(trim(target_username))
    and profiles.role in ('dispatcher', 'driver')
  for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Managed account unavailable.';
  end if;

  if target_profile.is_active = requested_active then
    raise exception using
      errcode = '22023',
      message = case
        when requested_active then 'Account is already active.'
        else 'Account is already inactive.'
      end;
  end if;

  if target_profile.role = 'driver' then
    select drivers.*
    into target_driver
    from public.drivers
    where drivers.profile_id = target_profile.id
    for update;

    if not found then
      raise exception using
        errcode = 'P0002',
        message = 'Managed account unavailable.';
    end if;

    if not requested_active and exists (
      select 1
      from public.shipments
      where shipments.driver_id = target_driver.id
        and shipments.status in ('assigned', 'loading', 'in_transit')
      for update
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'Driver has an active shipment.';
    end if;

    update public.drivers
    set status = case
      when requested_active then 'available'::public.driver_status
      else 'inactive'::public.driver_status
    end
    where id = target_driver.id;
  end if;

  update public.profiles
  set is_active = requested_active
  where id = target_profile.id;

  return query
  select target_profile.role, requested_active;
end;
$function$;

revoke all
on function public.set_managed_account_active_state(text, boolean)
from public, anon, authenticated;

grant execute
on function public.set_managed_account_active_state(text, boolean)
to service_role;

create function public.list_managed_accounts(
  search_query text default null,
  role_filter public.profile_role default null,
  active_filter boolean default null,
  page_offset integer default 0,
  page_limit integer default 10
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $function$
  with matching as (
    select
      profiles.full_name,
      profiles.username,
      profiles.role,
      profiles.is_active,
      profiles.created_at
    from public.profiles
    where profiles.role in ('dispatcher', 'driver')
      and (role_filter is null or profiles.role = role_filter)
      and (active_filter is null or profiles.is_active = active_filter)
      and (
        search_query is null
        or position(lower(search_query) in lower(profiles.full_name)) > 0
        or position(lower(search_query) in lower(profiles.username)) > 0
      )
  ),
  paged as (
    select matching.*
    from matching
    order by matching.created_at desc, matching.username asc
    offset greatest(page_offset, 0)
    limit least(greatest(page_limit, 1), 10)
  )
  select jsonb_build_object(
    'accounts', coalesce(
      (select jsonb_agg(to_jsonb(paged) order by paged.created_at desc, paged.username asc) from paged),
      '[]'::jsonb
    ),
    'total_count', (select count(*) from matching)
  );
$function$;

revoke all
on function public.list_managed_accounts(text, public.profile_role, boolean, integer, integer)
from public, anon, authenticated;

grant execute
on function public.list_managed_accounts(text, public.profile_role, boolean, integer, integer)
to service_role;

create function public.resolve_managed_account(target_username text)
returns table (
  account_id uuid,
  account_username text,
  account_role public.profile_role,
  account_is_active boolean
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    profiles.id,
    profiles.username,
    profiles.role,
    profiles.is_active
  from public.profiles
  where target_username is not null
    and trim(target_username) <> ''
    and lower(profiles.username) = lower(trim(target_username))
    and profiles.role in ('dispatcher', 'driver');
$function$;

revoke all
on function public.resolve_managed_account(text)
from public, anon, authenticated;

grant execute
on function public.resolve_managed_account(text)
to service_role;
