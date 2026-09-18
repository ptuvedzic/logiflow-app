begin;

create extension if not exists pgtap with schema extensions;
select plan(50);

insert into auth.users (id) values
  ('18000000-0000-0000-0000-000000000001'),
  ('18000000-0000-0000-0000-000000000002'),
  ('18000000-0000-0000-0000-000000000003'),
  ('18000000-0000-0000-0000-000000000004'),
  ('18000000-0000-0000-0000-000000000005'),
  ('18000000-0000-0000-0000-000000000011'),
  ('18000000-0000-0000-0000-000000000012'),
  ('18000000-0000-0000-0000-000000000013');

insert into public.profiles (id, full_name, username, role, is_active) values
  ('18000000-0000-0000-0000-000000000001', 'C Admin', 'c-admin', 'admin', true),
  ('18000000-0000-0000-0000-000000000002', 'C Dispatcher', 'c-dispatcher', 'dispatcher', true),
  ('18000000-0000-0000-0000-000000000003', 'C Driver', 'c-driver', 'driver', true),
  ('18000000-0000-0000-0000-000000000004', 'C Inactive Admin', 'c-inactive-admin', 'admin', false),
  ('18000000-0000-0000-0000-000000000005', 'C Inactive Dispatcher', 'c-inactive-dispatcher', 'dispatcher', false),
  ('18000000-0000-0000-0000-000000000011', 'C Assigned Driver', 'c-assigned-driver', 'driver', true),
  ('18000000-0000-0000-0000-000000000012', 'C Loading Driver', 'c-loading-driver', 'driver', true),
  ('18000000-0000-0000-0000-000000000013', 'C Transit Driver', 'c-transit-driver', 'driver', true);

insert into public.drivers (id, profile_id, status) values
  ('28000000-0000-0000-0000-000000000011', '18000000-0000-0000-0000-000000000011', 'assigned'),
  ('28000000-0000-0000-0000-000000000012', '18000000-0000-0000-0000-000000000012', 'assigned'),
  ('28000000-0000-0000-0000-000000000013', '18000000-0000-0000-0000-000000000013', 'assigned');

insert into public.vehicles (id, registration, make, model, vehicle_type, status) values
  ('48000000-0000-0000-0000-000000000011', 'C-011', 'C', 'Assigned', 'truck', 'in_use'),
  ('48000000-0000-0000-0000-000000000012', 'C-012', 'C', 'Loading', 'truck', 'in_use'),
  ('48000000-0000-0000-0000-000000000013', 'C-013', 'C', 'Transit', 'truck', 'in_use');

insert into public.clients (id, company_name, status) values
  ('38000000-0000-0000-0000-000000000001', 'Pending Client', 'active'),
  ('38000000-0000-0000-0000-000000000002', 'Assigned Client', 'active'),
  ('38000000-0000-0000-0000-000000000003', 'Loading Client', 'active'),
  ('38000000-0000-0000-0000-000000000004', 'Transit Client', 'active'),
  ('38000000-0000-0000-0000-000000000005', 'Delivered Client', 'active'),
  ('38000000-0000-0000-0000-000000000006', 'Cancelled Client', 'active'),
  ('38000000-0000-0000-0000-000000000007', 'Mixed Client', 'active');

insert into public.shipments (id, tracking_number, client_id, pickup_address, delivery_address, pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status) values
  ('58000000-0000-0000-0000-000000000001', 'C-PENDING', '38000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', null, null, 1, 'pending'),
  ('58000000-0000-0000-0000-000000000002', 'C-ASSIGNED', '38000000-0000-0000-0000-000000000002', 'A', 'B', now(), now(), 'Cargo', '28000000-0000-0000-0000-000000000011', '48000000-0000-0000-0000-000000000011', 1, 'assigned'),
  ('58000000-0000-0000-0000-000000000003', 'C-LOADING', '38000000-0000-0000-0000-000000000003', 'A', 'B', now(), now(), 'Cargo', '28000000-0000-0000-0000-000000000012', '48000000-0000-0000-0000-000000000012', 1, 'loading'),
  ('58000000-0000-0000-0000-000000000004', 'C-TRANSIT', '38000000-0000-0000-0000-000000000004', 'A', 'B', now(), now(), 'Cargo', '28000000-0000-0000-0000-000000000013', '48000000-0000-0000-0000-000000000013', 1, 'in_transit'),
  ('58000000-0000-0000-0000-000000000005', 'C-DELIVERED', '38000000-0000-0000-0000-000000000005', 'A', 'B', now(), now(), 'Cargo', '28000000-0000-0000-0000-000000000011', '48000000-0000-0000-0000-000000000011', 1, 'delivered'),
  ('58000000-0000-0000-0000-000000000006', 'C-CANCELLED', '38000000-0000-0000-0000-000000000006', 'A', 'B', now(), now(), 'Cargo', null, null, 1, 'cancelled'),
  ('58000000-0000-0000-0000-000000000007', 'C-MIXED-DONE', '38000000-0000-0000-0000-000000000007', 'A', 'B', now(), now(), 'Cargo', '28000000-0000-0000-0000-000000000012', '48000000-0000-0000-0000-000000000012', 1, 'delivered'),
  ('58000000-0000-0000-0000-000000000008', 'C-MIXED-PENDING', '38000000-0000-0000-0000-000000000007', 'A', 'B', now(), now(), 'Cargo', null, null, 1, 'pending');

create function pg_temp.c1_activity_count(target_client uuid, target_action public.activity_action_type default null)
returns bigint
language sql
security definer
set search_path = pg_catalog, public
as $$
  select count(*)
  from public.activity_logs
  where client_id = target_client
    and (target_action is null or action_type = target_action);
$$;

create function pg_temp.c1_shipment_count(first_client uuid, second_client uuid)
returns bigint
language sql
security definer
set search_path = pg_catalog, public
as $$
  select count(*) from public.shipments where client_id in (first_client, second_client);
$$;

select ok((select relrowsecurity from pg_class where oid = 'public.clients'::regclass), 'Client RLS is enabled');
select table_privs_are('public', 'clients', 'authenticated', array['SELECT', 'INSERT', 'UPDATE'], 'Authenticated receives only Client read/insert/update');
select policies_are('public', 'clients', array['clients_operations_insert', 'clients_operations_select', 'clients_operations_update'], 'Only approved Client policies exist');
select ok(not has_table_privilege('anon', 'public.clients', 'SELECT') and not has_table_privilege('anon', 'public.clients', 'INSERT') and not has_table_privilege('anon', 'public.clients', 'UPDATE'), 'Anonymous has no Client privileges');
select ok(not has_table_privilege('authenticated', 'public.clients', 'DELETE'), 'Authenticated cannot delete Clients');
select ok(not has_function_privilege('authenticated', 'public.authorize_client_mutation()', 'EXECUTE') and not has_function_privilege('authenticated', 'public.record_client_activity()', 'EXECUTE'), 'Trigger functions are not callable by authenticated');

set local role authenticated;
set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000003';
select is((select count(*) from public.clients), 0::bigint, 'Driver reads no Clients');
select throws_ok($$insert into public.clients (id, company_name) values ('38000000-0000-0000-0000-000000000020', 'Denied')$$, '42501', null, 'Driver cannot create Clients');

set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000004';
select is((select count(*) from public.clients), 0::bigint, 'Inactive Admin reads no Clients');
set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000005';
select is((select count(*) from public.clients), 0::bigint, 'Inactive Dispatcher reads no Clients');

set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000001';
select is((select count(*) from public.clients), 7::bigint, 'Active Admin reads Clients');
select lives_ok($$insert into public.clients (id, company_name, email) values ('38000000-0000-0000-0000-000000000021', 'Duplicate', 'same@example.com')$$, 'Admin creates a Client');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000021', 'client_created'), 1::bigint, 'Create emits exactly one client_created');
select throws_ok($$insert into public.clients (id, company_name, status) values ('38000000-0000-0000-0000-000000000022', 'Archived', 'archived')$$, 'P0001', 'client_create_status_invalid', 'Insert cannot create archived Client');
select lives_ok($$insert into public.clients (id, company_name, email) values ('38000000-0000-0000-0000-000000000023', 'Duplicate', 'same@example.com')$$, 'Duplicate company and email are allowed');
select throws_ok($$insert into public.clients (id, company_name) values ('38000000-0000-0000-0000-000000000024', '   ')$$, '23514', null, 'Blank company name is rejected');
select throws_ok($$insert into public.clients (id, company_name, phone) values ('38000000-0000-0000-0000-000000000025', 'Blank optional', '   ')$$, '23514', null, 'Blank optional persisted field is rejected');
select lives_ok($$update public.clients set phone = '123' where id = '38000000-0000-0000-0000-000000000021'$$, 'Real business edit succeeds');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000021', 'client_updated'), 1::bigint, 'Real edit emits exactly one client_updated');
select lives_ok($$update public.clients set phone = phone where id = '38000000-0000-0000-0000-000000000021'$$, 'No-op edit is accepted safely');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000021', 'client_updated'), 1::bigint, 'No-op edit emits no client_updated');
select lives_ok($$update public.clients set updated_at = updated_at where id = '38000000-0000-0000-0000-000000000021'$$, 'Updated-at-only edit is accepted safely');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000021', 'client_updated'), 1::bigint, 'Incidental update emits no client_updated');
select lives_ok($$update public.clients set phone = 'stale' where id = '38000000-0000-0000-0000-000000000021' and updated_at = (select updated_at - interval '1 second' from public.clients where id = '38000000-0000-0000-0000-000000000021')$$, 'Stale updated_at selector is handled safely');
select is((select phone from public.clients where id = '38000000-0000-0000-0000-000000000021'), '123', 'Stale updated_at selector changes no Client');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000021', 'client_updated'), 1::bigint, 'Stale edit emits no activity');
select throws_ok($$update public.clients set status = 'archived', phone = 'combined' where id = '38000000-0000-0000-0000-000000000021'$$, 'P0001', 'client_combined_mutation_invalid', 'Combined lifecycle and business edit is rejected');

select throws_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000001'$$, 'P0001', 'client_has_active_shipment', 'Pending Shipment blocks archive');
select throws_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000002'$$, 'P0001', 'client_has_active_shipment', 'Assigned Shipment blocks archive');
select throws_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000003'$$, 'P0001', 'client_has_active_shipment', 'Loading Shipment blocks archive');
select throws_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000004'$$, 'P0001', 'client_has_active_shipment', 'In-transit Shipment blocks archive');
select throws_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000007'$$, 'P0001', 'client_has_active_shipment', 'Mixed terminal and nonterminal history blocks archive');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000001') + pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000002') + pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000003') + pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000004') + pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000007'), 0::bigint, 'Blocked archives create no activity');
select is((select count(*) from public.clients where id in ('38000000-0000-0000-0000-000000000001', '38000000-0000-0000-0000-000000000002', '38000000-0000-0000-0000-000000000003', '38000000-0000-0000-0000-000000000004', '38000000-0000-0000-0000-000000000007') and status = 'active'), 5::bigint, 'Blocked archives leave Clients active');
select lives_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000005'$$, 'Delivered history permits archive');
select lives_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000006'$$, 'Cancelled history permits archive');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000005', 'client_archived') + pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000006', 'client_archived'), 2::bigint, 'Archive emits only client_archived');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000005', 'client_updated') + pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000006', 'client_updated'), 0::bigint, 'Archive emits no client_updated');
select is(pg_temp.c1_shipment_count('38000000-0000-0000-0000-000000000005', '38000000-0000-0000-0000-000000000006'), 2::bigint, 'Historical Shipment references survive archive');
select lives_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000005' and status = 'active'$$, 'A repeated or concurrent archive selector is handled safely');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000005', 'client_archived'), 1::bigint, 'Repeated archive creates no second activity');
select lives_ok($$update public.clients set status = 'active' where id = '38000000-0000-0000-0000-000000000005'$$, 'Reactivation succeeds');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000005', 'client_reactivated'), 1::bigint, 'Reactivation emits exactly one client_reactivated');
select is(pg_temp.c1_activity_count('38000000-0000-0000-0000-000000000005', 'client_updated'), 0::bigint, 'Reactivation emits no client_updated');

set local request.jwt.claim.sub = '18000000-0000-0000-0000-000000000002';
select is((select count(*) from public.clients), 9::bigint, 'Active Dispatcher reads Clients');
select lives_ok($$insert into public.clients (id, company_name) values ('38000000-0000-0000-0000-000000000026', 'Dispatcher Client')$$, 'Dispatcher creates Client');
select lives_ok($$update public.clients set contact_person = 'Dispatcher Edit' where id = '38000000-0000-0000-0000-000000000026'$$, 'Dispatcher edits Client');
select lives_ok($$update public.clients set status = 'archived' where id = '38000000-0000-0000-0000-000000000026'$$, 'Dispatcher archives Client');
select lives_ok($$update public.clients set status = 'active' where id = '38000000-0000-0000-0000-000000000026'$$, 'Dispatcher reactivates Client');
select ok(obj_description('public.clients'::regclass) like '%Future shipment creation must lock and revalidate this row%', 'Client row-lock contract is documented for future Shipment Create');

reset role;
select * from finish();
rollback;
