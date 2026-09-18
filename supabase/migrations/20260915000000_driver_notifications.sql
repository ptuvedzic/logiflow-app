create policy notifications_driver_select_own
on public.notifications
for select
to authenticated
using (
  recipient_profile_id = (select auth.uid())
  and (select public.current_active_profile_role()) = 'driver'
);

create or replace function public.acknowledge_notification(notification_id uuid)
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  actor_role public.profile_role;
  actor_is_active boolean;
  acknowledged_at timestamptz;
begin
  select profiles.role, profiles.is_active
  into actor_role, actor_is_active
  from public.profiles
  where profiles.id = actor_id
  for update;

  if actor_is_active is distinct from true
    or actor_role not in ('admin', 'dispatcher', 'driver') then
    return null;
  end if;

  select notifications.read_at
  into acknowledged_at
  from public.notifications
  where notifications.id = notification_id
    and notifications.recipient_profile_id = actor_id
  for update;

  if not found then
    return null;
  end if;

  if acknowledged_at is null then
    acknowledged_at := pg_catalog.statement_timestamp();

    update public.notifications
    set read_at = acknowledged_at
    where notifications.id = notification_id;
  end if;

  return acknowledged_at;
end;
$function$;

revoke all
on function public.acknowledge_notification(uuid)
from public, anon, authenticated;

grant execute
on function public.acknowledge_notification(uuid)
to authenticated;
