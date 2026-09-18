begin;

create extension if not exists pgtap with schema extensions;

select plan(21);

insert into auth.users (id)
values
  ('11000000-0000-0000-0000-000000000001'),
  ('11000000-0000-0000-0000-000000000002'),
  ('11000000-0000-0000-0000-000000000003'),
  ('11000000-0000-0000-0000-000000000004'),
  ('11000000-0000-0000-0000-000000000005'),
  ('11000000-0000-0000-0000-000000000006'),
  ('11000000-0000-0000-0000-000000000007');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('11000000-0000-0000-0000-000000000001', 'C2 Driver A', 'c2-driver-a', 'driver', true),
  ('11000000-0000-0000-0000-000000000002', 'C2 Driver B', 'c2-driver-b', 'driver', true),
  ('11000000-0000-0000-0000-000000000003', 'C2 No Current Driver', 'c2-no-current', 'driver', true),
  ('11000000-0000-0000-0000-000000000004', 'C2 History Driver', 'c2-history', 'driver', true),
  ('11000000-0000-0000-0000-000000000005', 'C2 Inactive Driver', 'c2-inactive', 'driver', false),
  ('11000000-0000-0000-0000-000000000006', 'C2 Admin', 'c2-admin', 'admin', true),
  ('11000000-0000-0000-0000-000000000007', 'C2 Dispatcher', 'c2-dispatcher', 'dispatcher', true);

insert into public.drivers (id, profile_id, status)
values
  ('21000000-0000-0000-0000-000000000001', '11000000-0000-0000-0000-000000000001', 'assigned'),
  ('21000000-0000-0000-0000-000000000002', '11000000-0000-0000-0000-000000000002', 'assigned'),
  ('21000000-0000-0000-0000-000000000003', '11000000-0000-0000-0000-000000000003', 'available'),
  ('21000000-0000-0000-0000-000000000004', '11000000-0000-0000-0000-000000000004', 'available'),
  ('21000000-0000-0000-0000-000000000005', '11000000-0000-0000-0000-000000000005', 'assigned');

insert into public.clients (id, company_name)
values ('31000000-0000-0000-0000-000000000001', 'C2 Test Client');

insert into public.vehicles (id, registration, make, model, vehicle_type, status)
values
  ('41000000-0000-0000-0000-000000000001', 'C2-A', 'Make A', 'Model A', 'Truck', 'in_use'),
  ('41000000-0000-0000-0000-000000000002', 'C2-B', 'Make B', 'Model B', 'Van', 'in_use'),
  ('41000000-0000-0000-0000-000000000003', 'C2-H-D', 'Make H', 'Delivered', 'Truck', 'available'),
  ('41000000-0000-0000-0000-000000000004', 'C2-H-C', 'Make H', 'Cancelled', 'Truck', 'available'),
  ('41000000-0000-0000-0000-000000000005', 'C2-I', 'Make I', 'Inactive', 'Truck', 'in_use');

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
    '51000000-0000-0000-0000-000000000001', 'SHP-C2-A',
    '31000000-0000-0000-0000-000000000001', 'Pickup A', 'Delivery A',
    '2026-08-26T08:00:00Z', '2026-08-26T12:00:00Z', 'Cargo A',
    '21000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001',
    100, 'assigned'
  ),
  (
    '51000000-0000-0000-0000-000000000002', 'SHP-C2-B',
    '31000000-0000-0000-0000-000000000001', 'Pickup B', 'Delivery B',
    '2026-08-26T08:00:00Z', '2026-08-26T12:00:00Z', 'Cargo B',
    '21000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000002',
    200, 'in_transit'
  ),
  (
    '51000000-0000-0000-0000-000000000003', 'SHP-C2-HISTORY-D',
    '31000000-0000-0000-0000-000000000001', 'Pickup History', 'Delivery History',
    '2026-08-20T08:00:00Z', '2026-08-20T12:00:00Z', 'Cargo History',
    '21000000-0000-0000-0000-000000000004', '41000000-0000-0000-0000-000000000003',
    300, 'delivered'
  ),
  (
    '51000000-0000-0000-0000-000000000004', 'SHP-C2-HISTORY-C',
    '31000000-0000-0000-0000-000000000001', 'Pickup Cancelled', 'Delivery Cancelled',
    '2026-08-21T08:00:00Z', '2026-08-21T12:00:00Z', 'Cargo Cancelled',
    '21000000-0000-0000-0000-000000000004', '41000000-0000-0000-0000-000000000004',
    400, 'cancelled'
  ),
  (
    '51000000-0000-0000-0000-000000000005', 'SHP-C2-INACTIVE',
    '31000000-0000-0000-0000-000000000001', 'Pickup Inactive', 'Delivery Inactive',
    '2026-08-26T08:00:00Z', '2026-08-26T12:00:00Z', 'Cargo Inactive',
    '21000000-0000-0000-0000-000000000005', '41000000-0000-0000-0000-000000000005',
    500, 'loading'
  );

set local role authenticated;
select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select results_eq(
  $$select registration from public.vehicles order by registration$$,
  $$values ('C2-A'::text)$$,
  'Driver A reads only the Vehicle on their current shipment'
);

select results_eq(
  $$select registration, make, model, vehicle_type, status from public.vehicles$$,
  $$values ('C2-A'::text, 'Make A'::text, 'Model A'::text, 'Truck'::text, 'in_use'::public.vehicle_status)$$,
  'Driver A reads all and only the granted presentation columns for Vehicle A'
);

select is_empty(
  $$select id from public.vehicles where id = '41000000-0000-0000-0000-000000000002'::uuid$$,
  'Direct Vehicle ID probing cannot bypass RLS'
);

select throws_ok(
  $$select vin from public.vehicles$$,
  '42501',
  null,
  'Driver cannot read VIN'
);

select throws_ok(
  $$select mileage, fuel_type, first_registration_date, created_at, updated_at from public.vehicles$$,
  '42501',
  null,
  'Driver cannot read other sensitive or unrelated Vehicle columns'
);

select throws_ok(
  $$insert into public.vehicles (id, registration, make, model, vehicle_type, status) values ('41000000-0000-0000-0000-000000000099', 'C2-DENIED', 'Denied', 'Denied', 'Truck', 'available')$$,
  '42501',
  null,
  'Driver cannot insert Vehicles'
);

select throws_ok(
  $$update public.vehicles set model = 'Changed' where id = '41000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Driver cannot update Vehicles'
);

select throws_ok(
  $$delete from public.vehicles where id = '41000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Driver cannot delete Vehicles'
);

select throws_ok(
  $$select price from public.shipments$$,
  '42501',
  null,
  'Driver remains denied unrelated shipment commercial columns'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000002', true);

select results_eq(
  $$select registration from public.vehicles order by registration$$,
  $$values ('C2-B'::text)$$,
  'Driver B reads only Vehicle B'
);

select is_empty(
  $$select id from public.vehicles where id = '41000000-0000-0000-0000-000000000001'::uuid$$,
  'Driver B cannot probe Vehicle A by ID'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000003', true);

select is_empty(
  $$select id from public.vehicles$$,
  'Driver with no current shipment reads no Vehicle'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000004', true);

select is_empty(
  $$select id from public.vehicles$$,
  'Driver with delivered and cancelled history only reads no Vehicle'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000005', true);

select is_empty(
  $$select id from public.vehicles$$,
  'Inactive Driver reads no Vehicle'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000006', true);

select is_empty(
  $$select id from public.vehicles$$,
  'Admin reads no Vehicle through the C2 Driver policy'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000007', true);

select is_empty(
  $$select id from public.vehicles$$,
  'Dispatcher reads no Vehicle through the C2 Driver policy'
);

select set_config('request.jwt.claim.sub', '11000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select tracking_number from public.shipments order by tracking_number$$,
  $$values ('SHP-C2-A'::text)$$,
  'C1 shipment row isolation remains effective for Driver A'
);

select is_empty(
  $$select vehicle_id from public.shipments where tracking_number = 'SHP-C2-B'$$,
  'The supplemental vehicle_id grant does not weaken C1 row isolation'
);

reset role;
set local role anon;

select throws_ok(
  $$select id from public.vehicles$$,
  '42501',
  null,
  'Anonymous users cannot read Vehicles'
);

select throws_ok(
  $$select vehicle_id from public.shipments$$,
  '42501',
  null,
  'Anonymous users do not receive the supplemental shipment grant'
);

select throws_ok(
  $$select registration from public.vehicles where id = '41000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Anonymous direct Vehicle probing remains denied'
);

reset role;
select * from finish();
rollback;
