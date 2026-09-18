grant select (
  vehicle_id
) on table public.shipments to authenticated;

grant select (
  id,
  registration,
  make,
  model,
  vehicle_type,
  status
) on table public.vehicles to authenticated;

create policy "vehicles_select_own_current_assignment"
on public.vehicles
for select
to authenticated
using (
  exists (
    select 1
    from public.shipments
    join public.drivers
      on drivers.id = shipments.driver_id
    join public.profiles
      on profiles.id = drivers.profile_id
    where shipments.vehicle_id = vehicles.id
      and shipments.status in ('assigned', 'loading', 'in_transit')
      and drivers.profile_id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'driver'
  )
);
