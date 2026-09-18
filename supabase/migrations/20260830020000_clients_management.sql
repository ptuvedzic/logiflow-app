create function public.authorize_client_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  actor_id uuid := auth.uid();
begin
  if actor_id is null and current_user in ('postgres', 'service_role') then
    return new;
  end if;

  if actor_id is null or not exists (
    select 1
    from public.profiles profile
    where profile.id = actor_id
      and profile.is_active
      and profile.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'client_access_denied';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'active' then
      raise exception using errcode = 'P0001', message = 'client_create_status_invalid';
    end if;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.company_name is distinct from old.company_name
      or new.contact_person is distinct from old.contact_person
      or new.phone is distinct from old.phone
      or new.email is distinct from old.email
      or new.address is distinct from old.address
      or new.notes is distinct from old.notes then
      raise exception using errcode = 'P0001', message = 'client_combined_mutation_invalid';
    end if;

    if not (
      (old.status = 'active' and new.status = 'archived')
      or (old.status = 'archived' and new.status = 'active')
    ) then
      raise exception using errcode = 'P0001', message = 'client_lifecycle_conflict';
    end if;

    if old.status = 'active' and new.status = 'archived' and exists (
      select 1
      from public.shipments shipment
      where shipment.client_id = old.id
        and shipment.status in ('pending', 'assigned', 'loading', 'in_transit')
    ) then
      raise exception using errcode = 'P0001', message = 'client_has_active_shipment';
    end if;

    return new;
  end if;

  if new.company_name is not distinct from old.company_name
    and new.contact_person is not distinct from old.contact_person
    and new.phone is not distinct from old.phone
    and new.email is not distinct from old.email
    and new.address is not distinct from old.address
    and new.notes is not distinct from old.notes then
    return null;
  end if;

  return new;
end;
$$;

create function public.record_client_activity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  actor_id uuid := auth.uid();
  activity_type public.activity_action_type;
begin
  if actor_id is null and current_user in ('postgres', 'service_role') then
    return new;
  end if;

  if actor_id is null or not exists (
    select 1
    from public.profiles profile
    where profile.id = actor_id
      and profile.is_active
      and profile.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'client_access_denied';
  end if;

  if tg_op = 'INSERT' then
    activity_type := 'client_created';
  elsif new.status is distinct from old.status then
    activity_type := case
      when new.status = 'archived' then 'client_archived'::public.activity_action_type
      else 'client_reactivated'::public.activity_action_type
    end;
  else
    activity_type := 'client_updated';
  end if;

  insert into public.activity_logs (id, actor_profile_id, action_type, client_id)
  values (gen_random_uuid(), actor_id, activity_type, new.id);

  return new;
end;
$$;

revoke all on function public.authorize_client_mutation() from public, anon, authenticated;
revoke all on function public.record_client_activity() from public, anon, authenticated;

create trigger clients_00_authorize_mutation
before insert or update on public.clients
for each row execute function public.authorize_client_mutation();

create trigger clients_record_activity
after insert or update on public.clients
for each row execute function public.record_client_activity();

grant select, insert, update on table public.clients to authenticated;

create policy clients_operations_select
on public.clients
for select
to authenticated
using (
  exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.role in ('admin', 'dispatcher')
  )
);

create policy clients_operations_insert
on public.clients
for insert
to authenticated
with check (
  status = 'active'
  and exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.role in ('admin', 'dispatcher')
  )
);

create policy clients_operations_update
on public.clients
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.role in ('admin', 'dispatcher')
  )
)
with check (
  exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.role in ('admin', 'dispatcher')
  )
);

comment on table public.clients is
  'Client lifecycle serialization point. Future shipment creation must lock and revalidate this row and require status = active before inserting a shipment.';
