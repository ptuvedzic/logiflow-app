grant select (
  id,
  body,
  sent_at,
  read_at,
  shipment_id
) on table public.messages to authenticated;

create policy "messages_select_own_active_driver_recipient"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.drivers
    join public.profiles
      on profiles.id = drivers.profile_id
    where drivers.id = messages.recipient_driver_id
      and drivers.profile_id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'driver'
  )
);

create function public.acknowledge_driver_message(message_id uuid)
returns timestamptz
language sql
volatile
security definer
set search_path = ''
as $function$
  with caller_driver as (
    select public.drivers.id
    from public.drivers
    join public.profiles
      on public.profiles.id = public.drivers.profile_id
    where public.drivers.profile_id = (select auth.uid())
      and public.profiles.is_active
      and public.profiles.role = 'driver'
  )
  update public.messages
  set read_at = coalesce(
    public.messages.read_at,
    pg_catalog.statement_timestamp()
  )
  from caller_driver
  where public.messages.id = $1
    and public.messages.recipient_driver_id = caller_driver.id
  returning public.messages.read_at;
$function$;

revoke all
on function public.acknowledge_driver_message(uuid)
from public, anon, authenticated;

grant execute
on function public.acknowledge_driver_message(uuid)
to authenticated;
