begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

insert into auth.users (id)
values
  ('10000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002'),
  ('10000000-0000-0000-0000-000000000003'),
  ('10000000-0000-0000-0000-000000000004');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('10000000-0000-0000-0000-000000000001', 'Driver A', 'driver-a', 'driver', true),
  ('10000000-0000-0000-0000-000000000002', 'Driver B', 'driver-b', 'driver', true),
  ('10000000-0000-0000-0000-000000000003', 'Inactive Driver', 'inactive-driver', 'driver', false),
  ('10000000-0000-0000-0000-000000000004', 'Dispatcher', 'dispatcher', 'dispatcher', true);

insert into public.drivers (id, profile_id, status)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'assigned'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'assigned'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'assigned');

insert into public.clients (id, company_name)
values ('30000000-0000-0000-0000-000000000001', 'C1 Test Client');

insert into public.vehicles (id, registration, make, model, vehicle_type, status)
values
  ('40000000-0000-0000-0000-000000000001', 'C1-A', 'Test', 'One', 'Truck', 'in_use'),
  ('40000000-0000-0000-0000-000000000002', 'C1-B', 'Test', 'Two', 'Truck', 'in_use'),
  ('40000000-0000-0000-0000-000000000003', 'C1-C', 'Test', 'Three', 'Truck', 'in_use'),
  ('40000000-0000-0000-0000-000000000004', 'C1-H', 'Test', 'Four', 'Truck', 'available');

insert into public.shipments (
  id,
  tracking_number,
  client_id,
  pickup_address,
  delivery_address,
  pickup_at,
  expected_delivery_at,
  cargo_type,
  driver_id,
  vehicle_id,
  price,
  status
)
values
  (
    '50000000-0000-0000-0000-000000000001', 'SHP-C1-A',
    '30000000-0000-0000-0000-000000000001', 'Pickup A', 'Delivery A',
    '2026-08-25T08:00:00Z', '2026-08-25T12:00:00Z', 'Test cargo',
    '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001',
    100, 'assigned'
  ),
  (
    '50000000-0000-0000-0000-000000000002', 'SHP-C1-B',
    '30000000-0000-0000-0000-000000000001', 'Pickup B', 'Delivery B',
    '2026-08-25T08:00:00Z', '2026-08-25T12:00:00Z', 'Test cargo',
    '20000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002',
    200, 'in_transit'
  ),
  (
    '50000000-0000-0000-0000-000000000003', 'SHP-C1-INACTIVE',
    '30000000-0000-0000-0000-000000000001', 'Pickup C', 'Delivery C',
    '2026-08-25T08:00:00Z', '2026-08-25T12:00:00Z', 'Test cargo',
    '20000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003',
    300, 'loading'
  ),
  (
    '50000000-0000-0000-0000-000000000004', 'SHP-C1-B-HISTORY',
    '30000000-0000-0000-0000-000000000001', 'Pickup History', 'Delivery History',
    '2026-08-20T08:00:00Z', '2026-08-20T12:00:00Z', 'Test cargo',
    '20000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000004',
    400, 'delivered'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $$select id from public.drivers order by id$$,
  $$values ('20000000-0000-0000-0000-000000000001'::uuid)$$,
  'Driver A reads only their own Driver row'
);

select results_eq(
  $$select tracking_number from public.shipments order by tracking_number$$,
  $$values ('SHP-C1-A'::text)$$,
  'Driver A reads only shipments assigned to Driver A'
);

select is_empty(
  $$select id from public.shipments where tracking_number in ('SHP-C1-B', 'SHP-C1-B-HISTORY')$$,
  'Driver A cannot read Driver B active or historical shipments'
);

select throws_ok(
  $$select price from public.shipments$$,
  '42501',
  null,
  'Driver cannot read ungranted commercial columns'
);

select throws_ok(
  $$update public.shipments set pickup_address = 'Changed' where tracking_number = 'SHP-C1-A'$$,
  '42501',
  null,
  'Driver cannot update shipments'
);

select throws_ok(
  $$delete from public.shipments where tracking_number = 'SHP-C1-A'$$,
  '42501',
  null,
  'Driver cannot delete shipments'
);

select throws_ok(
  $$insert into public.shipments (id, tracking_number, client_id, pickup_address, delivery_address, pickup_at, expected_delivery_at, cargo_type, price) values ('50000000-0000-0000-0000-000000000099', 'SHP-C1-DENIED', '30000000-0000-0000-0000-000000000001', 'Pickup', 'Delivery', now(), now(), 'Cargo', 0)$$,
  '42501',
  null,
  'Driver cannot insert shipments'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);

select is_empty(
  $$select id from public.drivers$$,
  'Inactive Driver cannot read their Driver row'
);

select is_empty(
  $$select id from public.shipments$$,
  'Inactive Driver cannot read assigned shipments'
);

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);

select is(
  (select count(*) from public.drivers),
  3::bigint,
  'Active Dispatcher can read Operations Driver master-data rows'
);

select is_empty(
  $$select id from public.shipments$$,
  'Dispatcher cannot read shipments through the Driver policy'
);

reset role;
set local role anon;

select throws_ok(
  $$select id from public.shipments$$,
  '42501',
  null,
  'Anonymous users cannot read shipments'
);

reset role;
select * from finish();
rollback;
