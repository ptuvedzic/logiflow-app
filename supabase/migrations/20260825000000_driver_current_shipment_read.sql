grant select (
  id,
  profile_id
) on table public.drivers to authenticated;

grant select (
  id,
  driver_id,
  tracking_number,
  status,
  pickup_address,
  delivery_address
) on table public.shipments to authenticated;

create policy "drivers_select_own_active_driver_profile"
on public.drivers
for select
to authenticated
using (
  profile_id = (select auth.uid())
  and exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'driver'
  )
);

create policy "shipments_select_own_driver_assignments"
on public.shipments
for select
to authenticated
using (
  exists (
    select 1
    from public.drivers
    where drivers.id = shipments.driver_id
      and drivers.profile_id = (select auth.uid())
  )
);
