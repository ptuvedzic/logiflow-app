alter table public.profiles
add constraint profiles_username_trimmed_check
check (username = trim(username));

alter table public.profiles
add constraint profiles_username_auth_identifier_length_check
check (
  octet_length(lower(trim(username))) between 1 and 94
);

create function public.auth_username_local_part(username text)
returns text
language sql
stable
strict
parallel safe
set search_path = pg_catalog
as $function$
  select case
    when pg_catalog.octet_length(
      pg_catalog.lower(pg_catalog.btrim(username))
    ) between 1 and 94
    then 'u1-' || pg_catalog.encode(
      pg_catalog.convert_to(
        pg_catalog.lower(pg_catalog.btrim(username)),
        'UTF8'
      ),
      'hex'
    )
    else null
  end;
$function$;

revoke all
on function public.auth_username_local_part(text)
from public;

grant execute
on function public.auth_username_local_part(text)
to anon, authenticated;
