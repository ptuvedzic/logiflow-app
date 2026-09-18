begin;

create extension if not exists pgtap with schema extensions;

select plan(32);

insert into auth.users (id)
values
  ('17000000-0000-0000-0000-000000000001'),
  ('17000000-0000-0000-0000-000000000002'),
  ('17000000-0000-0000-0000-000000000003'),
  ('17000000-0000-0000-0000-000000000004'),
  ('17000000-0000-0000-0000-000000000005'),
  ('17000000-0000-0000-0000-000000000006'),
  ('17000000-0000-0000-0000-000000000007');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('17000000-0000-0000-0000-000000000001', 'A2 Admin', 'a2-admin', 'admin', true),
  ('17000000-0000-0000-0000-000000000002', 'A2 Dispatcher', 'a2-dispatcher', 'dispatcher', true),
  ('17000000-0000-0000-0000-000000000003', 'A2 Driver', 'a2-driver', 'driver', true),
  ('17000000-0000-0000-0000-000000000004', 'A2 Assigned', 'a2-assigned', 'driver', true),
  ('17000000-0000-0000-0000-000000000005', 'A2 Loading', 'a2-loading', 'driver', true),
  ('17000000-0000-0000-0000-000000000006', 'A2 Transit', 'a2-transit', 'driver', true),
  ('17000000-0000-0000-0000-000000000007', 'A2 Atomic', 'a2-atomic', 'driver', true);

insert into public.drivers (id, profile_id, status)
values
  ('27000000-0000-0000-0000-000000000003', '17000000-0000-0000-0000-000000000003', 'off_duty'),
  ('27000000-0000-0000-0000-000000000004', '17000000-0000-0000-0000-000000000004', 'assigned'),
  ('27000000-0000-0000-0000-000000000005', '17000000-0000-0000-0000-000000000005', 'assigned'),
  ('27000000-0000-0000-0000-000000000006', '17000000-0000-0000-0000-000000000006', 'assigned'),
  ('27000000-0000-0000-0000-000000000007', '17000000-0000-0000-0000-000000000007', 'available');

insert into public.clients (id, company_name, contact_person, phone, email, address, notes, status)
values ('37000000-0000-0000-0000-000000000001', 'A2 Client', null, null, null, 'A2 Address', null, 'active');

insert into public.vehicles (id, make, model, registration, vin, mileage, vehicle_type, fuel_type, first_registration_date, status)
values
  ('47000000-0000-0000-0000-000000000004', 'A2', 'Assigned', 'A2-004', null, 0, 'truck', null, null, 'in_use'),
  ('47000000-0000-0000-0000-000000000005', 'A2', 'Loading', 'A2-005', null, 0, 'truck', null, null, 'in_use'),
  ('47000000-0000-0000-0000-000000000006', 'A2', 'Transit', 'A2-006', null, 0, 'truck', null, null, 'in_use');

insert into public.shipments (
  id, tracking_number, client_id, pickup_address, delivery_address, pickup_at,
  expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status
)
values
  ('57000000-0000-0000-0000-000000000004', 'A2-ASSIGNED', '37000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '27000000-0000-0000-0000-000000000004', '47000000-0000-0000-0000-000000000004', 1, 'assigned'),
  ('57000000-0000-0000-0000-000000000005', 'A2-LOADING', '37000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '27000000-0000-0000-0000-000000000005', '47000000-0000-0000-0000-000000000005', 1, 'loading'),
  ('57000000-0000-0000-0000-000000000006', 'A2-TRANSIT', '37000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', '27000000-0000-0000-0000-000000000006', '47000000-0000-0000-0000-000000000006', 1, 'in_transit');

select function_privs_are(
  'public', 'set_managed_account_active_state', array['text', 'boolean'],
  'service_role', array['EXECUTE'],
  'Only service_role can execute the lifecycle function'
);

set local role service_role;
select is(
  (public.list_managed_accounts() ->> 'total_count')::integer,
  6,
  'Managed account list excludes the Admin profile'
);
select is(
  (public.list_managed_accounts('A2 DRIVER') ->> 'total_count')::integer,
  1,
  'Managed account search is case-insensitive across names'
);
select is(
  (public.list_managed_accounts(role_filter => 'dispatcher') ->> 'total_count')::integer,
  1,
  'Managed account role filter returns only Dispatchers'
);
select is(
  jsonb_array_length(public.list_managed_accounts(page_limit => 2) -> 'accounts'),
  2,
  'Managed account list honors bounded pagination'
);
select ok(
  not jsonb_path_exists(public.list_managed_accounts(), '$.accounts[*].id')
  and not jsonb_path_exists(public.list_managed_accounts(), '$.accounts[*].driver_status'),
  'Managed account list exposes neither identifiers nor Driver operational status'
);
reset role;

select function_privs_are(
  'public', 'resolve_managed_account', array['text'],
  'service_role', array['EXECUTE'],
  'Only service_role can resolve a managed account target'
);

select function_privs_are(
  'public', 'list_managed_accounts', array['text', 'profile_role', 'boolean', 'integer', 'integer'],
  'service_role', array['EXECUTE'],
  'Only service_role can execute the account list function'
);

set local role authenticated;
select throws_ok(
  $$select public.set_managed_account_active_state('a2-dispatcher', false)$$,
  '42501', null, 'Authenticated users cannot execute lifecycle changes'
);
reset role;

set local role anon;
select throws_ok(
  $$select public.set_managed_account_active_state('a2-dispatcher', false)$$,
  '42501', null, 'Anonymous users cannot execute lifecycle changes'
);
reset role;

set local role service_role;
select throws_ok(
  $$select public.set_managed_account_active_state('a2-admin', false)$$,
  'P0002', 'Managed account unavailable.', 'Admin targets are rejected'
);
select throws_ok(
  $$select public.set_managed_account_active_state('a2-missing', false)$$,
  'P0002', 'Managed account unavailable.', 'Missing targets are rejected'
);
select lives_ok(
  $$select public.set_managed_account_active_state(' A2-Dispatcher ', false)$$,
  'Dispatcher deactivation normalizes the username'
);
reset role;

select is((select is_active from public.profiles where username = 'a2-dispatcher'), false, 'Dispatcher is inactive');

set local role service_role;
select throws_ok(
  $$select public.set_managed_account_active_state('a2-dispatcher', false)$$,
  '22023', 'Account is already inactive.', 'Already-inactive state is rejected'
);
select lives_ok(
  $$select public.set_managed_account_active_state('a2-dispatcher', true)$$,
  'Dispatcher reactivation succeeds'
);
select throws_ok(
  $$select public.set_managed_account_active_state('a2-dispatcher', true)$$,
  '22023', 'Account is already active.', 'Already-active state is rejected'
);
select lives_ok(
  $$select public.set_managed_account_active_state('a2-driver', false)$$,
  'Eligible Driver deactivation succeeds'
);
reset role;

select results_eq(
  $$select p.is_active, d.status from public.profiles p join public.drivers d on d.profile_id = p.id where p.username = 'a2-driver'$$,
  $$values (false, 'inactive'::public.driver_status)$$,
  'Driver profile and operational status become inactive atomically'
);

set local role service_role;
select lives_ok(
  $$select public.set_managed_account_active_state('a2-driver', true)$$,
  'Driver reactivation succeeds'
);
reset role;

select results_eq(
  $$select p.is_active, d.status from public.profiles p join public.drivers d on d.profile_id = p.id where p.username = 'a2-driver'$$,
  $$values (true, 'available'::public.driver_status)$$,
  'Driver reactivation sets the canonical available state'
);

set local role service_role;
select throws_ok($$select public.set_managed_account_active_state('a2-assigned', false)$$, 'P0001', 'Driver has an active shipment.', 'Assigned Driver deactivation is blocked');
select throws_ok($$select public.set_managed_account_active_state('a2-loading', false)$$, 'P0001', 'Driver has an active shipment.', 'Loading Driver deactivation is blocked');
select throws_ok($$select public.set_managed_account_active_state('a2-transit', false)$$, 'P0001', 'Driver has an active shipment.', 'In-transit Driver deactivation is blocked');
reset role;

select is_empty(
  $$select p.id from public.profiles p join public.drivers d on d.profile_id = p.id where p.username in ('a2-assigned', 'a2-loading', 'a2-transit') and (not p.is_active or d.status <> 'assigned')$$,
  'Blocked Drivers remain active and assigned'
);
select is((select count(*) from public.shipments where tracking_number like 'A2-%'), 3::bigint, 'Blocked lifecycle requests do not mutate shipments');
select is((select count(*) from public.vehicles where registration like 'A2-%' and status = 'in_use'), 3::bigint, 'Blocked lifecycle requests do not mutate vehicles');

create function public.a2_force_driver_failure()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception using errcode = 'P0001', message = 'Forced A2 failure.';
end;
$$;
create trigger a2_force_driver_failure before update on public.drivers
for each row when (old.profile_id = '17000000-0000-0000-0000-000000000007'::uuid)
execute function public.a2_force_driver_failure();

set local role service_role;
select throws_ok(
  $$select public.set_managed_account_active_state('a2-atomic', false)$$,
  'P0001', 'Forced A2 failure.', 'Forced Driver failure is surfaced'
);
reset role;

select results_eq(
  $$select p.is_active, d.status from public.profiles p join public.drivers d on d.profile_id = p.id where p.username = 'a2-atomic'$$,
  $$values (true, 'available'::public.driver_status)$$,
  'Forced failure leaves profile and Driver unchanged'
);

select is_empty(
  $$select id from public.activity_logs where actor_profile_id in (select id from public.profiles where username like 'a2-%')$$,
  'Lifecycle changes create no activity rows'
);
select is_empty(
  $$select id from public.notifications where recipient_profile_id in (select id from public.profiles where username like 'a2-%')$$,
  'Lifecycle changes create no notifications'
);

select ok(
  not has_function_privilege('authenticated', 'public.set_managed_account_active_state(text, boolean)', 'EXECUTE')
  and not has_function_privilege('anon', 'public.set_managed_account_active_state(text, boolean)', 'EXECUTE'),
  'Public application roles retain no lifecycle execution privilege'
);

select * from finish();
rollback;
