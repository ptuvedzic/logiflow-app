begin;

create extension if not exists pgtap with schema extensions;

select plan(31);

insert into auth.users (id)
values
  ('13000000-0000-0000-0000-000000000001'),
  ('13000000-0000-0000-0000-000000000002'),
  ('13000000-0000-0000-0000-000000000003'),
  ('13000000-0000-0000-0000-000000000004'),
  ('13000000-0000-0000-0000-000000000005');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('13000000-0000-0000-0000-000000000001', 'C4 Driver A', 'c4-driver-a', 'driver', true),
  ('13000000-0000-0000-0000-000000000002', 'C4 Driver B', 'c4-driver-b', 'driver', true),
  ('13000000-0000-0000-0000-000000000003', 'C4 Inactive Driver', 'c4-inactive', 'driver', false),
  ('13000000-0000-0000-0000-000000000004', 'C4 Admin', 'c4-admin', 'admin', true),
  ('13000000-0000-0000-0000-000000000005', 'C4 Dispatcher', 'c4-dispatcher', 'dispatcher', true);

insert into public.drivers (id, profile_id, status)
values
  ('23000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000001', 'assigned'),
  ('23000000-0000-0000-0000-000000000002', '13000000-0000-0000-0000-000000000002', 'available'),
  ('23000000-0000-0000-0000-000000000003', '13000000-0000-0000-0000-000000000003', 'assigned');

insert into public.clients (id, company_name)
values ('33000000-0000-0000-0000-000000000001', 'C4 Client');

insert into public.vehicles (id, registration, make, model, vehicle_type, status)
values
  ('43000000-0000-0000-0000-000000000001', 'C4-A', 'Test', 'Current', 'Truck', 'in_use'),
  ('43000000-0000-0000-0000-000000000002', 'C4-H', 'Test', 'History', 'Truck', 'available');

insert into public.shipments (
  id, tracking_number, client_id, pickup_address, delivery_address,
  pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status
)
values
  (
    '53000000-0000-0000-0000-000000000001', 'SHP-C4-A',
    '33000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo',
    '23000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', 100, 'assigned'
  ),
  (
    '53000000-0000-0000-0000-000000000002', 'SHP-C4-HISTORY',
    '33000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo',
    '23000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000002', 100, 'delivered'
  );

insert into public.messages (
  id, sender_profile_id, recipient_driver_id, shipment_id, body, sent_at
)
values
  (
    '63000000-0000-0000-0000-000000000001', '13000000-0000-0000-0000-000000000005',
    '23000000-0000-0000-0000-000000000001', null, 'Global A', '2026-08-20T08:00:00Z'
  ),
  (
    '63000000-0000-0000-0000-000000000002', '13000000-0000-0000-0000-000000000005',
    '23000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001',
    'Current A', '2026-08-20T09:00:00Z'
  ),
  (
    '63000000-0000-0000-0000-000000000003', '13000000-0000-0000-0000-000000000004',
    '23000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000002',
    'History A', '2026-08-20T10:00:00Z'
  ),
  (
    '63000000-0000-0000-0000-000000000004', '13000000-0000-0000-0000-000000000005',
    '23000000-0000-0000-0000-000000000002', null, 'Global B', '2026-08-20T11:00:00Z'
  ),
  (
    '63000000-0000-0000-0000-000000000005', '13000000-0000-0000-0000-000000000005',
    '23000000-0000-0000-0000-000000000003', null, 'Inactive', '2026-08-20T12:00:00Z'
  );

create temporary table acknowledgement_observation (
  observed_before timestamptz not null,
  acknowledged_at timestamptz,
  observed_after timestamptz not null
);

grant select, insert on table acknowledgement_observation to authenticated;

select results_eq(
  $$select count(*)::integer from pg_catalog.pg_proc where pronamespace = 'public'::regnamespace and proname = 'acknowledge_driver_message'$$,
  $$values (1)$$,
  'Exactly one acknowledgement function exists'
);

select results_eq(
  $$select pg_catalog.pg_get_function_identity_arguments(oid) from pg_catalog.pg_proc where pronamespace = 'public'::regnamespace and proname = 'acknowledge_driver_message'$$,
  $$values ('message_id uuid'::text)$$,
  'Acknowledgement accepts only message_id uuid'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select body from public.messages order by sent_at, id$$,
  $$values ('Global A'::text), ('Current A'::text), ('History A'::text)$$,
  'Driver A reads only Driver A messages'
);

select results_eq($$select body from public.messages where shipment_id is null$$, $$values ('Global A'::text)$$, 'Global message is visible');
select results_eq($$select body from public.messages where shipment_id = '53000000-0000-0000-0000-000000000001'$$, $$values ('Current A'::text)$$, 'Current shipment message is visible');
select results_eq($$select body from public.messages where shipment_id = '53000000-0000-0000-0000-000000000002'$$, $$values ('History A'::text)$$, 'Historical shipment message remains visible');
select is_empty($$select id from public.messages where id = '63000000-0000-0000-0000-000000000004'$$, 'Driver A cannot probe Driver B message');

select throws_ok($$select sender_profile_id from public.messages$$, '42501', null, 'Sender identity is not selectable');
select throws_ok($$select recipient_driver_id from public.messages$$, '42501', null, 'Recipient identity is not selectable');

insert into acknowledgement_observation
select
  pg_catalog.transaction_timestamp(),
  public.acknowledge_driver_message('63000000-0000-0000-0000-000000000001'),
  pg_catalog.clock_timestamp();

select ok(
  (select acknowledged_at is not null from acknowledgement_observation),
  'Driver A acknowledges their unread message'
);

select ok(
  (select acknowledged_at between observed_before and observed_after from acknowledgement_observation),
  'Database assigns acknowledgement timestamp within observed bounds'
);

select is(
  public.acknowledge_driver_message('63000000-0000-0000-0000-000000000001'),
  (select acknowledged_at from acknowledgement_observation),
  'Second acknowledgement preserves the original timestamp'
);

select throws_ok(
  $$select public.acknowledge_driver_message('63000000-0000-0000-0000-000000000001'::uuid, now())$$,
  '42883', null,
  'Caller cannot supply an acknowledgement timestamp'
);

select is(
  public.acknowledge_driver_message('63000000-0000-0000-0000-000000000099'),
  null,
  'Nonexistent message returns NULL'
);

select is(
  public.acknowledge_driver_message('63000000-0000-0000-0000-000000000004'),
  null,
  'Unauthorized message returns the same NULL contract'
);

select throws_ok($$update public.messages set read_at = now() where id = '63000000-0000-0000-0000-000000000002'$$, '42501', null, 'Direct read_at update is denied');
select throws_ok($$update public.messages set body = 'Changed' where id = '63000000-0000-0000-0000-000000000002'$$, '42501', null, 'Direct body update is denied');
select throws_ok($$update public.messages set recipient_driver_id = '23000000-0000-0000-0000-000000000002', sender_profile_id = '13000000-0000-0000-0000-000000000004', shipment_id = null where id = '63000000-0000-0000-0000-000000000002'$$, '42501', null, 'Direct ownership reassignment is denied');
select throws_ok($$update public.messages set sent_at = now(), id = '63000000-0000-0000-0000-000000000099' where id = '63000000-0000-0000-0000-000000000002'$$, '42501', null, 'Direct sent_at and id changes are denied');
select throws_ok($$insert into public.messages (id, sender_profile_id, recipient_driver_id, body) values ('63000000-0000-0000-0000-000000000099', '13000000-0000-0000-0000-000000000005', '23000000-0000-0000-0000-000000000001', 'Denied')$$, '42501', null, 'Message insert is denied');
select throws_ok($$delete from public.messages where id = '63000000-0000-0000-0000-000000000002'$$, '42501', null, 'Message delete is denied');

select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000002', true);
select is_empty($$select id from public.messages where id = '63000000-0000-0000-0000-000000000001'$$, 'Driver B cannot read Driver A message');
select is(public.acknowledge_driver_message('63000000-0000-0000-0000-000000000002'), null, 'Driver B cannot acknowledge Driver A message');

select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000003', true);
select is_empty($$select id from public.messages$$, 'Inactive Driver cannot read messages');
select is(public.acknowledge_driver_message('63000000-0000-0000-0000-000000000005'), null, 'Inactive Driver cannot acknowledge messages');

select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000004', true);
select is_empty($$select id from public.messages$$, 'Admin gains no Driver-message read authority');
select is(public.acknowledge_driver_message('63000000-0000-0000-0000-000000000001'), null, 'Admin gains no Driver acknowledgement authority');

select set_config('request.jwt.claim.sub', '13000000-0000-0000-0000-000000000005', true);
select is_empty($$select id from public.messages$$, 'Dispatcher gains no Driver-message read authority');
select is(public.acknowledge_driver_message('63000000-0000-0000-0000-000000000001'), null, 'Dispatcher gains no Driver acknowledgement authority');

reset role;
set local role anon;
select throws_ok($$select id from public.messages$$, '42501', null, 'Anonymous caller cannot read messages');
select throws_ok($$select public.acknowledge_driver_message('63000000-0000-0000-0000-000000000001')$$, '42501', null, 'Anonymous caller cannot execute acknowledgement');

reset role;
select * from finish();
rollback;
