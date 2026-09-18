begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id) values
  ('12000000-0000-0000-0000-000000000001'),
  ('12000000-0000-0000-0000-000000000002'),
  ('12000000-0000-0000-0000-000000000003'),
  ('12000000-0000-0000-0000-000000000004');
insert into public.profiles (id, full_name, username, role, is_active) values
  ('12000000-0000-0000-0000-000000000001', 'Vehicle Admin', 'vehicle-admin', 'admin', true),
  ('12000000-0000-0000-0000-000000000002', 'Vehicle Dispatcher', 'vehicle-dispatcher', 'dispatcher', true),
  ('12000000-0000-0000-0000-000000000003', 'Vehicle Driver', 'vehicle-driver', 'driver', true),
  ('12000000-0000-0000-0000-000000000004', 'Inactive Admin', 'vehicle-inactive', 'admin', false);
insert into public.drivers (id, profile_id, status) values
  ('22000000-0000-0000-0000-000000000003', '12000000-0000-0000-0000-000000000003', 'available');
insert into public.clients (id, company_name) values
  ('32000000-0000-0000-0000-000000000001', 'Vehicle Test Client');
insert into public.vehicles (id, registration, make, model, vehicle_type, vin, mileage, status) values
  ('42000000-0000-0000-0000-000000000001', 'BG-100-AA', 'Volvo', 'FH', 'Truck', null, 1000, 'available'),
  ('42000000-0000-0000-0000-000000000002', 'NS-200-BB', 'Mercedes', 'Sprinter', 'Van', 'VinCase', 2000, 'maintenance'),
  ('42000000-0000-0000-0000-000000000003', 'NI-300-CC', 'Scania', 'R', 'Truck', null, 3000, 'out_of_service'),
  ('42000000-0000-0000-0000-000000000004', 'SU-400-DD', 'MAN', 'TGX', 'Truck', null, 4000, 'archived'),
  ('42000000-0000-0000-0000-000000000005', 'KG-500-EE', 'DAF', 'XF', 'Truck', null, 5000, 'in_use');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select registration from public.list_operations_vehicles('', 'all', 'all', 1)$$,
  $$values ('BG-100-AA'::text), ('KG-500-EE'::text), ('NI-300-CC'::text), ('NS-200-BB'::text), ('SU-400-DD'::text)$$,
  'Admin list uses case-insensitive registration order'
);
select results_eq(
  $$select registration from public.list_operations_vehicles('sPrIn', 'all', 'all', 1)$$,
  $$values ('NS-200-BB'::text)$$,
  'List searches model case-insensitively'
);
select results_eq(
  $$select registration from public.list_operations_vehicles('', 'maintenance', 'Van', 1)$$,
  $$values ('NS-200-BB'::text)$$,
  'List applies status and type filters'
);
select results_eq(
  $$select vehicle_type from public.list_operations_vehicle_types()$$,
  $$values ('Truck'::text), ('Van'::text)$$,
  'Type options are distinct and deterministic'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000002', true);
select results_eq(
  $$select count(*) from public.list_operations_vehicles('', 'all', 'all', 1)$$,
  $$values (5::bigint)$$,
  'Dispatcher can list Vehicles'
);
select throws_ok(
  $$select public.create_vehicle('DENIED', 'Make', 'Model', 'Truck')$$,
  'P0001', 'vehicle_mutation_access_denied', 'Dispatcher cannot create Vehicles'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select * from public.list_operations_vehicles('', 'all', 'all', 1)$$,
  'P0001', 'vehicle_read_access_denied', 'Driver cannot call Operations list'
);
select throws_ok(
  $$select mileage from public.vehicles$$,
  '42501', null, 'Driver C2 mileage remains unavailable'
);
select throws_ok(
  $$insert into public.vehicles (id, registration, make, model, vehicle_type, status) values (gen_random_uuid(), 'DIRECT', 'M', 'M', 'T', 'available')$$,
  '42501', null, 'Direct authenticated Vehicle insert remains denied'
);
select throws_ok(
  $$delete from public.vehicles where id = '42000000-0000-0000-0000-000000000001'::uuid$$,
  '42501', null, 'Authenticated Vehicle delete remains denied'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000004', true);
select throws_ok(
  $$select * from public.list_operations_vehicle_types()$$,
  'P0001', 'vehicle_read_access_denied', 'Inactive profile cannot read Operations Vehicles'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.create_vehicle('  BG-NEW  ', '  Iveco ', ' S-Way ', ' Truck ', '  MixedVin  ', 123, ' Diesel ', '2025-01-01')$$,
  'Admin creates a normalized Vehicle'
);
reset role;
select results_eq(
  $$select registration, make, model, vehicle_type, vin, mileage, fuel_type, first_registration_date, status from public.vehicles where registration = 'BG-NEW'$$,
  $$values ('BG-NEW'::text, 'Iveco'::text, 'S-Way'::text, 'Truck'::text, 'MixedVin'::text, 123, 'Diesel'::text, '2025-01-01'::date, 'available'::public.vehicle_status)$$,
  'Create persists exact normalized fields and available status'
);
select results_eq(
  $$select action_type, metadata from public.activity_logs join public.vehicles on vehicles.id = activity_logs.vehicle_id where vehicles.registration = 'BG-NEW'$$,
  $$values ('vehicle_created'::public.activity_action_type, '{"status":"available"}'::jsonb)$$,
  'Create records exact activity metadata'
);
select lives_ok(
  $$select public.create_vehicle('NULL-VIN-1', 'M', 'A', 'Truck', '   ')$$,
  'Empty VIN normalizes to null'
);
select lives_ok(
  $$select public.create_vehicle('NULL-VIN-2', 'M', 'B', 'Truck', null)$$,
  'Multiple null VINs are allowed'
);
select lives_ok(
  $$select public.create_vehicle('CASE-VIN', 'M', 'C', 'Truck', 'vINcASE')$$,
  'VIN uniqueness remains case-sensitive'
);
select throws_ok(
  $$select public.create_vehicle('bg-new', 'M', 'D', 'Truck')$$,
  '23505', null, 'Registration uniqueness is case-insensitive'
);
select throws_ok(
  $$select public.create_vehicle('DUP-VIN', 'M', 'D', 'Truck', 'MixedVin')$$,
  '23505', null, 'VIN duplicates are rejected case-sensitively'
);
select throws_ok(
  $$select public.create_vehicle(repeat('R', 33), 'M', 'D', 'Truck')$$,
  'P0001', 'vehicle_validation_failed', 'Registration maximum length is enforced'
);
select throws_ok(
  $$select public.create_vehicle('LONG-VIN', 'M', 'D', 'Truck', repeat('V', 65))$$,
  'P0001', 'vehicle_validation_failed', 'VIN maximum length is enforced'
);

select results_eq(
  $$select public.update_vehicle_master_data(id, updated_at, ' BG-100-AA ', 'Volvo', 'FH', 'Truck', null, null, null) from public.vehicles where id = '42000000-0000-0000-0000-000000000001'$$,
  $$values ('noop'::text)$$,
  'Normalized master-data no-op is explicit'
);
select results_eq(
  $$select count(*) from public.activity_logs where vehicle_id = '42000000-0000-0000-0000-000000000001'$$,
  $$values (0::bigint)$$,
  'Master-data no-op creates no activity'
);
select results_eq(
  $$select public.update_vehicle_master_data(id, updated_at, registration, 'Volvo Trucks', model, vehicle_type, vin, 'Diesel', first_registration_date) from public.vehicles where id = '42000000-0000-0000-0000-000000000001'$$,
  $$values ('updated'::text)$$,
  'Real master-data edit succeeds'
);
select results_eq(
  $$select metadata from public.activity_logs where vehicle_id = '42000000-0000-0000-0000-000000000001'$$,
  $$values ('{"changed_fields":["make","fuel_type"]}'::jsonb)$$,
  'Edit activity contains stable changed field names only'
);
select throws_ok(
  $$select public.update_vehicle_master_data('42000000-0000-0000-0000-000000000001', '2000-01-01', 'X', 'X', 'X', 'X')$$,
  'P0001', 'vehicle_stale', 'Stale edit is rejected'
);
select throws_ok(
  $$select public.update_vehicle_master_data('42000000-0000-0000-0000-000000000001', null, 'X', 'X', 'X', 'X')$$,
  'P0001', 'vehicle_stale', 'Missing edit version cannot bypass optimistic concurrency'
);

select results_eq(
  $$select public.update_vehicle_mileage(id, updated_at, mileage) from public.vehicles where id = '42000000-0000-0000-0000-000000000002'$$,
  $$values ('noop'::text)$$,
  'Equal mileage is a no-op'
);
select throws_ok(
  $$select public.update_vehicle_mileage(id, updated_at, mileage - 1) from public.vehicles where id = '42000000-0000-0000-0000-000000000002'$$,
  'P0001', 'vehicle_mileage_decrease', 'Mileage decrease is rejected'
);
select throws_ok(
  $$select public.update_vehicle_mileage('42000000-0000-0000-0000-000000000002', null, 2500)$$,
  'P0001', 'vehicle_stale', 'Missing mileage version cannot bypass optimistic concurrency'
);
select results_eq(
  $$select public.update_vehicle_mileage(id, updated_at, 2500) from public.vehicles where id = '42000000-0000-0000-0000-000000000002'$$,
  $$values ('updated'::text)$$,
  'Mileage increase succeeds'
);
select results_eq(
  $$select metadata from public.activity_logs where vehicle_id = '42000000-0000-0000-0000-000000000002' and action_type = 'vehicle_updated'$$,
  $$values ('{"field":"mileage","from":2000,"to":2500,"unit":"km"}'::jsonb)$$,
  'Mileage activity metadata is exact'
);

select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000001', 'mark_maintenance')$$,
  $$values ('maintenance'::public.vehicle_status)$$,
  'Available Vehicle may enter maintenance'
);
select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000001', 'mark_out_of_service')$$,
  $$values ('out_of_service'::public.vehicle_status)$$,
  'Maintenance Vehicle may become out of service'
);
select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000001', 'mark_available')$$,
  $$values ('available'::public.vehicle_status)$$,
  'Out-of-service Vehicle may become available'
);
select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000003', 'archive')$$,
  $$values ('archived'::public.vehicle_status)$$,
  'Vehicle may be archived'
);
select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000004', 'reactivate')$$,
  $$values ('available'::public.vehicle_status)$$,
  'Archived Vehicle may be reactivated'
);
select throws_ok(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000005', 'mark_available')$$,
  'P0001', 'vehicle_transition_invalid', 'Manual transition from in-use is rejected'
);
select throws_ok(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000004', 'unknown')$$,
  'P0001', 'vehicle_transition_invalid', 'Unknown lifecycle operation is rejected'
);

insert into public.vehicles (id, registration, make, model, vehicle_type, status) values
  ('42000000-0000-0000-0000-000000000006', 'DELIVERED-HISTORY', 'M', 'D', 'Truck', 'available'),
  ('42000000-0000-0000-0000-000000000007', 'CANCELLED-HISTORY', 'M', 'C', 'Truck', 'available');
insert into public.shipments (id, tracking_number, client_id, pickup_address, delivery_address, pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status) values
  ('52000000-0000-0000-0000-000000000006', 'SHP-MDV1-DELIVERED', '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now() + interval '1 day', 'Cargo', '22000000-0000-0000-0000-000000000003', '42000000-0000-0000-0000-000000000006', 10, 'delivered'),
  ('52000000-0000-0000-0000-000000000007', 'SHP-MDV1-CANCELLED', '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now() + interval '1 day', 'Cargo', '22000000-0000-0000-0000-000000000003', '42000000-0000-0000-0000-000000000007', 10, 'cancelled');
select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000006', 'archive')$$,
  $$values ('archived'::public.vehicle_status)$$,
  'Delivered Shipment history does not block lifecycle'
);
select results_eq(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000007', 'archive')$$,
  $$values ('archived'::public.vehicle_status)$$,
  'Cancelled Shipment history does not block lifecycle'
);

insert into public.shipments (id, tracking_number, client_id, pickup_address, delivery_address, pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status, delayed)
values ('52000000-0000-0000-0000-000000000001', 'SHP-MDV1-ACTIVE', '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now() + interval '1 day', 'Cargo', '22000000-0000-0000-0000-000000000003', '42000000-0000-0000-0000-000000000005', 10, 'in_transit', true);
select throws_ok(
  $$select public.change_vehicle_operational_status('42000000-0000-0000-0000-000000000005', 'archive')$$,
  'P0001', 'vehicle_active_shipment', 'Active Shipment blocks lifecycle before transition evaluation'
);
select results_eq(
  $$select public.update_vehicle_mileage(id, updated_at, 5100) from public.vehicles where id = '42000000-0000-0000-0000-000000000005'$$,
  $$values ('updated'::text)$$,
  'Active Shipment does not block mileage increase'
);

select is((select prosecdef from pg_proc where oid = 'public.create_vehicle(text,text,text,text,text,integer,text,date)'::regprocedure), true, 'Create function is SECURITY DEFINER');
select is((select proconfig from pg_proc where oid = 'public.change_vehicle_operational_status(uuid,text)'::regprocedure), array['search_path=""']::text[], 'Lifecycle function has fixed empty search path');
select ok(has_function_privilege('authenticated', 'public.create_vehicle(text,text,text,text,text,integer,text,date)', 'EXECUTE'), 'Authenticated role has narrow create execute permission');
select ok(not has_function_privilege('anon', 'public.create_vehicle(text,text,text,text,text,integer,text,date)', 'EXECUTE'), 'Anonymous role cannot execute create');

reset role;
set local role anon;
select throws_ok(
  $$select * from public.list_operations_vehicles('', 'all', 'all', 1)$$,
  '42501', null, 'Anonymous cannot execute Operations read RPC'
);
select throws_ok(
  $$select public.create_vehicle('ANON', 'M', 'M', 'T')$$,
  '42501', null, 'Anonymous cannot execute mutation RPC'
);

reset role;
select * from finish();
rollback;
