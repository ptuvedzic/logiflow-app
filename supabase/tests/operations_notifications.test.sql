begin;

create extension if not exists pgtap with schema extensions;
select plan(41);

insert into auth.users (id) values
  ('d1000000-0000-0000-0000-000000000001'),
  ('d1000000-0000-0000-0000-000000000002'),
  ('d1000000-0000-0000-0000-000000000003'),
  ('d1000000-0000-0000-0000-000000000004'),
  ('d1000000-0000-0000-0000-000000000005');

insert into public.profiles (id, full_name, username, role, is_active, created_at) values
  ('d1000000-0000-0000-0000-000000000001', 'S6A Admin', 's6a-admin', 'admin', true, '2026-09-13T08:00:00Z'),
  ('d1000000-0000-0000-0000-000000000002', 'S6A Dispatcher', 's6a-dispatcher', 'dispatcher', true, '2026-09-13T08:01:00Z'),
  ('d1000000-0000-0000-0000-000000000003', 'S6A Driver', 's6a-driver', 'driver', true, '2026-09-13T08:02:00Z'),
  ('d1000000-0000-0000-0000-000000000004', 'S6A Inactive', 's6a-inactive', 'dispatcher', false, '2026-09-13T08:03:00Z'),
  ('d1000000-0000-0000-0000-000000000005', 'S6A Missing Profile User', 's6a-missing', 'dispatcher', true, '2026-09-13T08:04:00Z');

insert into public.drivers (id, profile_id, status) values
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'available');

insert into public.notifications (id, recipient_profile_id, notification_type, title, message, created_at, read_at) values
  ('d6000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'status_approval_requested', 'Admin unread older', 'Stored trusted content A', '2026-01-13T09:00:00Z', null),
  ('d6000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'status_approval_requested', 'Admin read', 'Stored trusted content B', '2026-01-13T10:00:00Z', '2026-01-13T10:01:00Z'),
  ('d6000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', 'status_approval_requested', 'Admin unread newest', 'Stored trusted content C', '2026-01-13T11:00:00Z', null),
  ('d6000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000002', 'status_approval_requested', 'Dispatcher unread', 'Stored trusted content D', '2026-01-13T12:00:00Z', null),
  ('d6000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000003', 'shipment_assigned', 'Driver notification', 'Stored trusted content E', '2026-01-13T13:00:00Z', null),
  ('d6000000-0000-0000-0000-000000000006', 'd1000000-0000-0000-0000-000000000004', 'status_approval_requested', 'Inactive notification', 'Stored trusted content F', '2026-01-13T14:00:00Z', null);

delete from public.profiles where id = 'd1000000-0000-0000-0000-000000000005';

select has_function('public', 'acknowledge_notification', array['uuid'], 'Narrow notification acknowledgement exists');
select function_lang_is('public', 'acknowledge_notification', array['uuid'], 'plpgsql', 'Acknowledgement is implemented in PL/pgSQL');
select is((select prosecdef from pg_catalog.pg_proc where oid = 'public.acknowledge_notification(uuid)'::regprocedure), true, 'Acknowledgement is SECURITY DEFINER');
select is((select proconfig from pg_catalog.pg_proc where oid = 'public.acknowledge_notification(uuid)'::regprocedure), array['search_path=""'], 'Acknowledgement has an empty search_path');
select function_privs_are('public', 'acknowledge_notification', array['uuid'], 'authenticated', array['EXECUTE'], 'Authenticated receives only function execute');
select function_privs_are('public', 'acknowledge_notification', array['uuid'], 'anon', array[]::text[], 'Anonymous receives no function privilege');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000001', true);

select results_eq($$select title from public.notifications order by created_at desc, id desc$$, $$values ('Admin unread newest'::text), ('Admin read'::text), ('Admin unread older'::text)$$, 'Admin sees own notifications in deterministic order');
select is((select count(*) from public.notifications where read_at is null), 2::bigint, 'Admin unread count is own unread count');
select results_eq($$select title from public.notifications where read_at is null order by created_at desc, id desc limit 1 offset 1$$, $$values ('Admin unread older'::text)$$, 'Unread filtering and deterministic pagination work');
select results_eq($$select title from public.notifications where read_at is not null order by created_at desc, id desc$$, $$values ('Admin read'::text)$$, 'Read filtering works');
select lives_ok($$select id, notification_type, title, message, shipment_id, created_at, read_at from public.notifications$$, 'Minimum presentation columns are selectable');
select throws_ok($$select recipient_profile_id from public.notifications$$, '42501', null, 'Recipient profile identifier is not selectable');
select throws_ok($$select vehicle_id from public.notifications$$, '42501', null, 'Unused Vehicle relationship is not selectable');

create temporary table s6a_observed (before_at timestamptz, returned_at timestamptz, after_at timestamptz);
grant insert, select on table s6a_observed to authenticated;
insert into s6a_observed select clock_timestamp(), public.acknowledge_notification('d6000000-0000-0000-0000-000000000001'), clock_timestamp();
select ok((select returned_at <= after_at and returned_at > '2026-01-13T09:00:00Z'::timestamptz from s6a_observed), 'Acknowledgement uses trusted database time');
select is((select read_at from public.notifications where id = 'd6000000-0000-0000-0000-000000000001'), (select returned_at from s6a_observed), 'Acknowledgement stores returned read_at');
select is(public.acknowledge_notification('d6000000-0000-0000-0000-000000000001'), (select returned_at from s6a_observed), 'Repeated acknowledgement preserves first timestamp');
select is(public.acknowledge_notification('d6000000-0000-0000-0000-000000000004'), null, 'Cross-user acknowledgement is unavailable');
select is(public.acknowledge_notification('d6000000-0000-0000-0000-000000000099'), null, 'Nonexistent acknowledgement is indistinguishable');
select throws_ok($$select public.acknowledge_notification('d6000000-0000-0000-0000-000000000003', now())$$, '42883', null, 'Caller cannot supply a timestamp');
select throws_ok($$insert into public.notifications (id, recipient_profile_id, notification_type, title, message) values (gen_random_uuid(), auth.uid(), 'status_approval_requested', 'Spoof', 'Spoof')$$, '42501', null, 'Direct insert is denied');
select throws_ok($$update public.notifications set read_at = now()$$, '42501', null, 'Direct read_at update is denied');
select throws_ok($$update public.notifications set title = 'Spoof', message = 'Spoof'$$, '42501', null, 'Content spoofing is denied');
select throws_ok($$update public.notifications set recipient_profile_id = 'd1000000-0000-0000-0000-000000000002'$$, '42501', null, 'Recipient spoofing is denied');
select throws_ok($$update public.notifications set created_at = now()$$, '42501', null, 'Timestamp spoofing is denied');
select throws_ok($$delete from public.notifications$$, '42501', null, 'Direct delete is denied');
select is((select count(*) from public.activity_logs where actor_profile_id = 'd1000000-0000-0000-0000-000000000001'), 0::bigint, 'Acknowledgement creates no activity');
select is((select count(*) from public.alerts), 0::bigint, 'Acknowledgement creates no alert');
select is((select count(*) from public.notifications), 3::bigint, 'Acknowledgement creates no notification');

select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000002', true);
select results_eq($$select title from public.notifications$$, $$values ('Dispatcher unread'::text)$$, 'Dispatcher sees only own notification');
select is((select count(*) from public.notifications where read_at is null), 1::bigint, 'Dispatcher unread count is correct');
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000003', true);
select results_eq($$select title from public.notifications$$, $$values ('Driver notification'::text)$$, 'Driver sees only own notification');
select ok(public.acknowledge_notification('d6000000-0000-0000-0000-000000000005') is not null, 'Driver can acknowledge own notification');
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000004', true);
select is_empty($$select id from public.notifications$$, 'Inactive Operations profile is denied reads');
select is(public.acknowledge_notification('d6000000-0000-0000-0000-000000000006'), null, 'Inactive Operations profile is denied acknowledgement');
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000005', true);
select is_empty($$select id from public.notifications$$, 'Missing profile is denied reads');
select is(public.acknowledge_notification('d6000000-0000-0000-0000-000000000006'), null, 'Missing profile is denied acknowledgement');

reset role;
set local role anon;
select throws_ok($$select id from public.notifications$$, '42501', null, 'Anonymous notification read is denied');
select throws_ok($$select public.acknowledge_notification('d6000000-0000-0000-0000-000000000001')$$, '42501', null, 'Anonymous acknowledgement is denied');

reset role;
select ok(pg_get_functiondef('public.assign_pending_shipment(uuid,uuid,uuid)'::regprocedure) like '%insert into public.notifications%', 'S1 assignment notification producer remains present');
select ok(pg_get_functiondef('public.create_shipment_status_request(public.shipment_status)'::regprocedure) like '%status_approval_requested%', 'S2 Operations notification producer remains present');
select ok(pg_get_functiondef('public.cancel_shipment(uuid)'::regprocedure) like '%shipment_cancelled%', 'S3 cancellation notification producer remains present');

select * from finish();
rollback;
