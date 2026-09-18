begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id) values
  ('19000000-0000-0000-0000-000000000001'), ('19000000-0000-0000-0000-000000000002'),
  ('19000000-0000-0000-0000-000000000003'), ('19000000-0000-0000-0000-000000000004'),
  ('19000000-0000-0000-0000-000000000005'), ('19000000-0000-0000-0000-000000000006'),
  ('19000000-0000-0000-0000-000000000007'), ('19000000-0000-0000-0000-000000000008'),
  ('19000000-0000-0000-0000-000000000009'), ('19000000-0000-0000-0000-000000000010'),
  ('19000000-0000-0000-0000-000000000011'), ('19000000-0000-0000-0000-000000000012'),
  ('19000000-0000-0000-0000-000000000013');

insert into public.profiles (id, full_name, username, role, is_active) values
  ('19000000-0000-0000-0000-000000000001', 'D Admin', 'd-admin', 'admin', true),
  ('19000000-0000-0000-0000-000000000002', 'D Dispatcher', 'd-dispatcher', 'dispatcher', true),
  ('19000000-0000-0000-0000-000000000003', 'D Driver', 'd-driver', 'driver', true),
  ('19000000-0000-0000-0000-000000000004', 'D Inactive Admin', 'd-inactive-admin', 'admin', false),
  ('19000000-0000-0000-0000-000000000005', 'D Inactive Dispatcher', 'd-inactive-dispatcher', 'dispatcher', false),
  ('19000000-0000-0000-0000-000000000006', 'D Inactive Driver', 'd-inactive-driver', 'driver', false),
  ('19000000-0000-0000-0000-000000000007', 'D Off Duty', 'd-off-duty', 'driver', true),
  ('19000000-0000-0000-0000-000000000008', 'D Archived', 'd-archived', 'driver', true),
  ('19000000-0000-0000-0000-000000000009', 'D Assigned', 'd-assigned', 'driver', true),
  ('19000000-0000-0000-0000-000000000010', 'D Loading', 'd-loading', 'driver', true),
  ('19000000-0000-0000-0000-000000000011', 'D Transit', 'd-transit', 'driver', true),
  ('19000000-0000-0000-0000-000000000012', 'D Delivered', 'd-delivered', 'driver', true),
  ('19000000-0000-0000-0000-000000000013', 'D Cancelled', 'd-cancelled', 'driver', true);

insert into public.drivers (id, profile_id, phone, status) values
  ('29000000-0000-0000-0000-000000000003', '19000000-0000-0000-0000-000000000003', null, 'available'),
  ('29000000-0000-0000-0000-000000000006', '19000000-0000-0000-0000-000000000006', null, 'inactive'),
  ('29000000-0000-0000-0000-000000000007', '19000000-0000-0000-0000-000000000007', null, 'off_duty'),
  ('29000000-0000-0000-0000-000000000008', '19000000-0000-0000-0000-000000000008', null, 'archived'),
  ('29000000-0000-0000-0000-000000000009', '19000000-0000-0000-0000-000000000009', null, 'assigned'),
  ('29000000-0000-0000-0000-000000000010', '19000000-0000-0000-0000-000000000010', null, 'assigned'),
  ('29000000-0000-0000-0000-000000000011', '19000000-0000-0000-0000-000000000011', null, 'assigned'),
  ('29000000-0000-0000-0000-000000000012', '19000000-0000-0000-0000-000000000012', null, 'available'),
  ('29000000-0000-0000-0000-000000000013', '19000000-0000-0000-0000-000000000013', null, 'available');

insert into public.clients (id, company_name) values ('39000000-0000-0000-0000-000000000001', 'D Client');
insert into public.vehicles (id, registration, make, model, vehicle_type, status) values
  ('49000000-0000-0000-0000-000000000009', 'D-009', 'D', 'Assigned', 'truck', 'in_use'),
  ('49000000-0000-0000-0000-000000000010', 'D-010', 'D', 'Loading', 'truck', 'in_use'),
  ('49000000-0000-0000-0000-000000000011', 'D-011', 'D', 'Transit', 'truck', 'in_use'),
  ('49000000-0000-0000-0000-000000000012', 'D-012', 'D', 'Delivered', 'truck', 'available'),
  ('49000000-0000-0000-0000-000000000013', 'D-013', 'D', 'Cancelled', 'truck', 'available');
insert into public.shipments (id, tracking_number, client_id, pickup_address, delivery_address, pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status) values
  ('59000000-0000-0000-0000-000000000009', 'D-ASSIGNED', '39000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '29000000-0000-0000-0000-000000000009', '49000000-0000-0000-0000-000000000009', 1, 'assigned'),
  ('59000000-0000-0000-0000-000000000010', 'D-LOADING', '39000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '29000000-0000-0000-0000-000000000010', '49000000-0000-0000-0000-000000000010', 1, 'loading'),
  ('59000000-0000-0000-0000-000000000011', 'D-TRANSIT', '39000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '29000000-0000-0000-0000-000000000011', '49000000-0000-0000-0000-000000000011', 1, 'in_transit'),
  ('59000000-0000-0000-0000-000000000012', 'D-DELIVERED', '39000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '29000000-0000-0000-0000-000000000012', '49000000-0000-0000-0000-000000000012', 1, 'delivered'),
  ('59000000-0000-0000-0000-000000000013', 'D-CANCELLED', '39000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '29000000-0000-0000-0000-000000000013', '49000000-0000-0000-0000-000000000013', 1, 'cancelled');

create function pg_temp.d1_activity_count(target_driver uuid) returns bigint language sql security definer set search_path = pg_catalog, public as $$ select count(*) from public.activity_logs where driver_id = target_driver and action_type = 'driver_status_changed' $$;
create function pg_temp.d1_phone(target_driver uuid) returns text language sql security definer set search_path = pg_catalog, public as $$ select phone from public.drivers where id = target_driver $$;
create function pg_temp.d1_status(target_driver uuid) returns public.driver_status language sql security definer set search_path = pg_catalog, public as $$ select status from public.drivers where id = target_driver $$;
create function pg_temp.d1_updated(target_driver uuid) returns timestamptz language sql security definer set search_path = pg_catalog, public as $$ select updated_at from public.drivers where id = target_driver $$;
create function pg_temp.d1_metadata_is_exact(first_driver uuid, second_driver uuid) returns boolean language sql security definer set search_path = pg_catalog, public as $$ select not exists (select 1 from public.activity_logs where driver_id in (first_driver, second_driver) and (metadata - 'from_status' - 'to_status' - 'operation') <> '{}'::jsonb) $$;

select ok((select relrowsecurity from pg_class where oid = 'public.drivers'::regclass), 'Driver RLS remains enabled');
select ok(not has_table_privilege('anon', 'public.drivers', 'SELECT'), 'Anonymous cannot read Drivers');
select ok(not has_table_privilege('authenticated', 'public.drivers', 'DELETE'), 'Authenticated cannot delete Drivers');
select ok(not has_column_privilege('authenticated', 'public.drivers', 'status', 'UPDATE'), 'Driver status has no direct authenticated update grant');
select function_privs_are('public', 'change_driver_operational_status', array['uuid', 'text'], 'authenticated', array['EXECUTE'], 'Only authenticated receives status-function execution');

set local role anon;
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'archive')$$, '42501', null, 'Anonymous cannot execute status changes');
set local role authenticated;
set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000099';
select is((select count(*) from public.drivers), 0::bigint, 'Missing profile reads no Drivers');
set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000004';
select is((select count(*) from public.drivers), 0::bigint, 'Inactive Admin reads no Drivers');
set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000005';
select is((select count(*) from public.drivers), 0::bigint, 'Inactive Dispatcher reads no Drivers');
set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000003';
select is((select count(*) from public.drivers), 1::bigint, 'Driver retains own-row read');
select is((select count(*) from public.drivers where id <> '29000000-0000-0000-0000-000000000003'), 0::bigint, 'Driver gains no Operations-wide read');
select lives_ok($$update public.drivers set phone = 'denied' where id = '29000000-0000-0000-0000-000000000003'$$, 'Driver phone update is safely denied as zero rows');
select is(pg_temp.d1_phone('29000000-0000-0000-0000-000000000003'), null, 'Driver cannot edit own phone');

set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000001';
select is((select count(*) from public.drivers), 9::bigint, 'Active Admin reads all Drivers');
select lives_ok($$update public.drivers set phone = '  +381 (11) 555-0100  ' where id = '29000000-0000-0000-0000-000000000003'$$, 'Admin phone edit succeeds');
select is(pg_temp.d1_phone('29000000-0000-0000-0000-000000000003'), '+381 (11) 555-0100', 'Phone is trimmed and formatting retained');
select lives_ok($$update public.drivers set phone = '   ' where id = '29000000-0000-0000-0000-000000000003'$$, 'Blank phone update succeeds');
select is(pg_temp.d1_phone('29000000-0000-0000-0000-000000000003'), null, 'Blank phone normalizes to null');
select lives_ok($$update public.drivers set phone = repeat('1', 32) where id = '29000000-0000-0000-0000-000000000003'$$, 'Exactly 32 phone characters are accepted');
select throws_ok($$update public.drivers set phone = repeat('1', 33) where id = '29000000-0000-0000-0000-000000000003'$$, '23514', null, 'More than 32 phone characters are rejected');
select lives_ok($$update public.drivers set phone = '+381/11 555-0100 ext. 2' where id = '29000000-0000-0000-0000-000000000003'$$, 'Ordinary phone formatting is accepted');
select lives_ok($$update public.drivers set phone = '+381/11 555-0100 ext. 2' where id = '29000000-0000-0000-0000-000000000007'$$, 'Duplicate phones are accepted');

reset role;
alter table public.drivers disable trigger drivers_set_updated_at;
update public.drivers set updated_at = now() - interval '1 day' where id = '29000000-0000-0000-0000-000000000012';
alter table public.drivers enable trigger drivers_set_updated_at;
set local role authenticated;
set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000001';
create temporary table d1_before as select updated_at, status, profile_id from public.drivers where id = '29000000-0000-0000-0000-000000000012';
select lives_ok($$update public.drivers set phone = '+381 64 555 0100' where id = '29000000-0000-0000-0000-000000000012'$$, 'Legitimate phone edit remains compatible with updated_at trigger');
select ok(pg_temp.d1_updated('29000000-0000-0000-0000-000000000012') > (select updated_at from d1_before), 'Phone edit advances updated_at');
select results_eq($$select status, profile_id from public.drivers where id = '29000000-0000-0000-0000-000000000012'$$, $$select status, profile_id from d1_before$$, 'Phone edit changes no protected Driver column');
create temporary table d1_noop as select updated_at from public.drivers where id = '29000000-0000-0000-0000-000000000003';
select lives_ok($$update public.drivers set phone = '  +381 64 555 0100  ' where id = '29000000-0000-0000-0000-000000000003'$$, 'Normalized no-op is accepted');
select is(pg_temp.d1_updated('29000000-0000-0000-0000-000000000003'), (select updated_at from d1_noop), 'Normalized no-op preserves updated_at regardless of trigger order');
select is(pg_temp.d1_activity_count('29000000-0000-0000-0000-000000000003'), 0::bigint, 'Phone edits emit no activity');
select lives_ok($$update public.drivers set phone = 'stale' where id = '29000000-0000-0000-0000-000000000003' and updated_at < (select updated_at from d1_noop)$$, 'Stale conditional phone update is safely accepted as zero rows');
select is(pg_temp.d1_phone('29000000-0000-0000-0000-000000000003'), '+381 64 555 0100', 'Stale phone update preserves newer data');
select lives_ok($$update public.drivers set phone = 'active shipment allowed' where id = '29000000-0000-0000-0000-000000000009'$$, 'Phone edit is allowed during active Shipment');
select lives_ok($$update public.drivers set phone = 'inactive denied' where id = '29000000-0000-0000-0000-000000000006'$$, 'Inactive target update is safely denied as zero rows');
select is(pg_temp.d1_phone('29000000-0000-0000-0000-000000000006'), null, 'Inactive target remains unchanged');
select throws_ok($$update public.drivers set status = 'archived' where id = '29000000-0000-0000-0000-000000000003'$$, '42501', null, 'Direct authenticated status mutation is denied');

select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'mark_off_duty')$$, 'available to off-duty succeeds');
select is(pg_temp.d1_status('29000000-0000-0000-0000-000000000003'), 'off_duty'::public.driver_status, 'Mark off duty stores off_duty');
select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'mark_available')$$, 'off-duty to available succeeds');
select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'archive')$$, 'available to archived succeeds');
select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'reactivate')$$, 'archived to available succeeds');
select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000007', 'archive')$$, 'off-duty to archived succeeds');
select is(pg_temp.d1_activity_count('29000000-0000-0000-0000-000000000003'), 4::bigint, 'Four successful transitions emit four activities');
select is(pg_temp.d1_activity_count('29000000-0000-0000-0000-000000000007'), 1::bigint, 'Off-duty archive emits one activity');
select ok(pg_temp.d1_metadata_is_exact('29000000-0000-0000-0000-000000000003', '29000000-0000-0000-0000-000000000007'), 'Activity metadata has exactly the approved keys');

select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'mark_available')$$, 'P0001', 'driver_status_transition_invalid', 'Same-state transition is rejected');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000006', 'mark_available')$$, 'P0002', 'driver_target_unavailable', 'Inactive-profile Driver action is rejected');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000008', 'mark_off_duty')$$, 'P0001', 'driver_status_transition_invalid', 'Archived to off-duty is rejected');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'unknown')$$, '22023', 'driver_status_operation_invalid', 'Unknown operation is rejected');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000009', 'archive')$$, 'P0001', 'driver_status_active_shipment', 'Assigned Shipment blocks status action');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000010', 'archive')$$, 'P0001', 'driver_status_active_shipment', 'Loading Shipment blocks status action');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000011', 'archive')$$, 'P0001', 'driver_status_active_shipment', 'In-transit Shipment blocks status action');
select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000012', 'archive')$$, 'Delivered Shipment does not block archive');
select lives_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000013', 'archive')$$, 'Cancelled Shipment does not block archive');

set local request.jwt.claim.sub = '19000000-0000-0000-0000-000000000002';
select is((select count(*) from public.drivers), 9::bigint, 'Active Dispatcher reads Drivers');
select lives_ok($$update public.drivers set phone = 'dispatcher denied' where id = '29000000-0000-0000-0000-000000000003'$$, 'Dispatcher phone update is denied as zero rows');
select throws_ok($$select public.change_driver_operational_status('29000000-0000-0000-0000-000000000003', 'archive')$$, '42501', 'driver_status_access_denied', 'Dispatcher status action is denied');

reset role;
select is((select count(*) from public.notifications where driver_id between '29000000-0000-0000-0000-000000000003' and '29000000-0000-0000-0000-000000000013'), 0::bigint, 'MD-D1 creates no notifications');
select is((select count(*) from public.alerts where driver_id between '29000000-0000-0000-0000-000000000003' and '29000000-0000-0000-0000-000000000013'), 0::bigint, 'MD-D1 creates no alerts');
select is((select count(*) from public.shipments where tracking_number like 'D-%'), 5::bigint, 'Status actions preserve Shipments');
select is((select count(*) from public.vehicles where registration like 'D-%'), 5::bigint, 'Status actions preserve Vehicles');

set local role service_role;
select lives_ok($$select public.set_managed_account_active_state('d-off-duty', false)$$, 'A2 still deactivates an eligible Driver');
reset role;
select results_eq($$select p.is_active, d.status from public.profiles p join public.drivers d on d.profile_id = p.id where p.username = 'd-off-duty'$$, $$values (false, 'inactive'::public.driver_status)$$, 'A2 deactivation still synchronizes profile and Driver');
set local role service_role;
select lives_ok($$select public.set_managed_account_active_state('d-off-duty', true)$$, 'A2 still reactivates Driver');
reset role;
select results_eq($$select p.is_active, d.status from public.profiles p join public.drivers d on d.profile_id = p.id where p.username = 'd-off-duty'$$, $$values (true, 'available'::public.driver_status)$$, 'A2 reactivation still sets available');

select * from finish();
rollback;
