create function public.provision_account_profile(
  auth_user_id uuid,
  full_name text,
  username text,
  provisioned_role text,
  driver_id uuid default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  if provisioned_role not in ('dispatcher', 'driver') then
    raise exception using
      errcode = '22023',
      message = 'Unsupported account role.';
  end if;

  if provisioned_role = 'driver' and driver_id is null then
    raise exception using
      errcode = '22023',
      message = 'Driver ID is required for a Driver account.';
  end if;

  if provisioned_role = 'dispatcher' and driver_id is not null then
    raise exception using
      errcode = '22023',
      message = 'Driver ID is not permitted for a Dispatcher account.';
  end if;

  insert into public.profiles (
    id,
    full_name,
    username,
    role,
    is_active
  )
  values (
    auth_user_id,
    full_name,
    username,
    provisioned_role::public.profile_role,
    true
  );

  if provisioned_role = 'driver' then
    insert into public.drivers (
      id,
      profile_id,
      phone,
      status
    )
    values (
      driver_id,
      auth_user_id,
      null,
      'available'
    );
  end if;
end;
$function$;

revoke all
on function public.provision_account_profile(uuid, text, text, text, uuid)
from public, anon, authenticated;

grant execute
on function public.provision_account_profile(uuid, text, text, text, uuid)
to service_role;

grant execute
on function public.auth_username_local_part(text)
to service_role;
