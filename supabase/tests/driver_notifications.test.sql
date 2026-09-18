begin;

create extension if not exists pgtap with schema extensions;
select plan(51);

insert into auth.users (id) values
  ('f1000000-0000-0000-0000-000000000001'),
  ('f1000000-0000-0000-0000-000000000002'),
  ('f1000000-0000-0000-0000-000000000003'),
  ('f1000000-0000-0000-0000-000000000004'),
  ('f1000000-0000-0000-0000-000000000005'),
  ('f1000000-0000-0000-0000-000000000006');

insert into public.profiles (id, full_name, username, role, is_active, created_at) values
  ('f1000000-0000-0000-0000-000000000001', 'N1 Driver One', 'n1-driver-one', 'driver', true, '2026-09-15T08:00:00Z'),
  ('f1000000-0000-0000-0000-000000000002', 'N1 Driver Two', 'n1-driver-two', 'driver', true, '2026-09-15T08:01:00Z'),
  ('f1000000-0000-0000-0000-000000000003', 'N1 Admin', 'n1-admin', 'admin', true, '2026-09-15T08:02:00Z'),
  ('f1000000-0000-0000-0000-000000000004', 'N1 Dispatcher', 'n1-dispatcher', 'dispatcher', true, '2026-09-15T08:03:00Z'),
  ('f1000000-0000-0000-0000-000000000005', 'N1 Inactive Driver', 'n1-inactive', 'driver', false, '2026-09-15T08:04:00Z');

insert into public.drivers (id, profile_id, status) values
  ('f2000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'available'),
  ('f2000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000002', 'available'),
  ('f2000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000005', 'available');

insert into public.notifications (id, recipient_profile_id, notification_type, title, message, created_at, read_at) values
  ('f6000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'shipment_assigned', 'Assigned', 'Assignment copy', '2026-09-12T09:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000001', 'status_approved', 'Approved', 'Approval copy', '2026-09-12T10:00:00Z', '2026-09-12T10:01:00Z'),
  ('f6000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000001', 'status_rejected', 'Rejected', 'Rejection copy', '2026-09-12T11:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000001', 'shipment_cancelled', 'Cancelled', 'Cancellation copy', '2026-09-12T12:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000005', 'f1000000-0000-0000-0000-000000000001', 'new_dispatcher_message', 'Message', 'Generic message copy', '2026-09-12T13:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000006', 'f1000000-0000-0000-0000-000000000001', 'status_approval_requested', 'Unexpected own Operations type', 'Neutral copy', '2026-09-12T14:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000007', 'f1000000-0000-0000-0000-000000000002', 'shipment_assigned', 'Other Driver', 'Other copy', '2026-09-12T15:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000008', 'f1000000-0000-0000-0000-000000000003', 'status_approval_requested', 'Admin Operations', 'Admin copy', '2026-09-12T16:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000009', 'f1000000-0000-0000-0000-000000000004', 'status_approval_requested', 'Dispatcher Operations', 'Dispatcher copy', '2026-09-12T17:00:00Z', null),
  ('f6000000-0000-0000-0000-000000000010', 'f1000000-0000-0000-0000-000000000005', 'shipment_assigned', 'Inactive Driver', 'Inactive copy', '2026-09-12T18:00:00Z', null);

select policies_are('public', 'notifications', array['notifications_driver_select_own', 'notifications_operations_select_own'], 'Notifications has separate Driver and Operations SELECT policies');
select policy_roles_are('public', 'notifications', 'notifications_driver_select_own', array['authenticated'], 'Driver policy is authenticated-only');
select policy_cmd_is('public', 'notifications', 'notifications_driver_select_own', 'SELECT', 'Driver policy applies only to SELECT');
select has_function('public', 'acknowledge_notification', array['uuid'], 'Existing acknowledgement signature is retained');
select is((select prosecdef from pg_catalog.pg_proc where oid = 'public.acknowledge_notification(uuid)'::regprocedure), true, 'Acknowledgement remains SECURITY DEFINER');
select is((select proconfig from pg_catalog.pg_proc where oid = 'public.acknowledge_notification(uuid)'::regprocedure), array['search_path=""'], 'Acknowledgement retains empty search_path');
select function_privs_are('public', 'acknowledge_notification', array['uuid'], 'authenticated', array['EXECUTE'], 'Authenticated retains only execute');
select function_privs_are('public', 'acknowledge_notification', array['uuid'], 'anon', array[]::text[], 'Anonymous has no execute privilege');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select title from public.notifications order by created_at desc, id desc$$,
  $$values ('Unexpected own Operations type'::text), ('Message'::text), ('Cancelled'::text), ('Rejected'::text), ('Approved'::text), ('Assigned'::text)$$,
  'Active Driver sees only own rows in deterministic order'
);
select is((select count(*) from public.notifications), 6::bigint, 'Cross-Driver and Operations rows are hidden');
select is((select count(*) from public.notifications where read_at is null), 5::bigint, 'Driver unread count is derived correctly');
select results_eq($$select title from public.notifications where read_at is null order by created_at desc, id desc$$, $$values ('Unexpected own Operations type'::text), ('Message'::text), ('Cancelled'::text), ('Rejected'::text), ('Assigned'::text)$$, 'Unread filtering works');
select results_eq($$select title from public.notifications where read_at is not null order by created_at desc, id desc$$, $$values ('Approved'::text)$$, 'Read filtering works');
select results_eq($$select title from public.notifications order by created_at desc, id desc limit 2 offset 2$$, $$values ('Cancelled'::text), ('Rejected'::text)$$, 'Deterministic pagination works');
select lives_ok($$select id, notification_type, title, message, shipment_id, created_at, read_at from public.notifications$$, 'Minimum presentation columns are selectable');
select throws_ok($$select recipient_profile_id from public.notifications$$, '42501', null, 'Recipient Profile ID is not selectable');
select throws_ok($$select vehicle_id from public.notifications$$, '42501', null, 'Vehicle ID is not selectable');
select throws_ok($$select driver_id from public.notifications$$, '42501', null, 'Driver ID is not selectable');
select throws_ok($$select document_id from public.notifications$$, '42501', null, 'Document ID is not selectable');
select results_eq($$select notification_type from public.notifications where id in ('f6000000-0000-0000-0000-000000000001','f6000000-0000-0000-0000-000000000003','f6000000-0000-0000-0000-000000000004','f6000000-0000-0000-0000-000000000005') order by notification_type::text$$, $$values ('new_dispatcher_message'::public.notification_type), ('shipment_assigned'::public.notification_type), ('shipment_cancelled'::public.notification_type), ('status_rejected'::public.notification_type)$$, 'Existing Driver-directed notification types are readable');
select is_empty($$select id from public.notifications where title in ('Admin Operations','Dispatcher Operations')$$, 'Operations status-request notifications remain invisible');

create temporary table n1_observed (before_at timestamptz, returned_at timestamptz, after_at timestamptz);
grant insert, select on table n1_observed to authenticated;
insert into n1_observed select clock_timestamp(), public.acknowledge_notification('f6000000-0000-0000-0000-000000000001'), clock_timestamp();
select ok((select returned_at <= after_at and returned_at > '2026-09-12T09:00:00Z'::timestamptz from n1_observed), 'Acknowledgement uses trusted database time');
select is((select read_at from public.notifications where id = 'f6000000-0000-0000-0000-000000000001'), (select returned_at from n1_observed), 'Acknowledgement stores the returned timestamp');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000001'), (select returned_at from n1_observed), 'Repeated acknowledgement preserves first timestamp');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000007'), null, 'Cross-Driver acknowledgement is unavailable');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000099'), null, 'Nonexistent acknowledgement is indistinguishable');
select throws_ok($$insert into public.notifications (id, recipient_profile_id, notification_type, title, message) values (gen_random_uuid(), auth.uid(), 'shipment_assigned', 'Spoof', 'Spoof')$$, '42501', null, 'Direct insert is denied');
select throws_ok($$update public.notifications set read_at = now()$$, '42501', null, 'Direct update is denied');
select throws_ok($$delete from public.notifications$$, '42501', null, 'Direct delete is denied');

reset role;
select is((select count(*) from public.activity_logs where actor_profile_id = 'f1000000-0000-0000-0000-000000000001'), 0::bigint, 'Acknowledgement creates no activity');
select is((select count(*) from public.alerts), 0::bigint, 'Acknowledgement creates no alert');
select is((select count(*) from public.notifications), 10::bigint, 'Acknowledgement creates no notification');
select is((select count(*) from public.notifications where id = 'f6000000-0000-0000-0000-000000000001' and title = 'Assigned' and message = 'Assignment copy' and notification_type = 'shipment_assigned' and recipient_profile_id = 'f1000000-0000-0000-0000-000000000001' and created_at = '2026-09-12T09:00:00Z'), 1::bigint, 'Acknowledgement changes only read_at');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000002', true);
select results_eq($$select title from public.notifications$$, $$values ('Other Driver'::text)$$, 'Second Driver sees only own notification');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000001'), null, 'Second Driver cannot acknowledge first Driver notification');
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000003', true);
select results_eq($$select title from public.notifications$$, $$values ('Admin Operations'::text)$$, 'S6A Admin own-only visibility remains intact');
select ok(public.acknowledge_notification('f6000000-0000-0000-0000-000000000008') is not null, 'S6A Admin acknowledgement remains available');
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000004', true);
select results_eq($$select title from public.notifications$$, $$values ('Dispatcher Operations'::text)$$, 'S6A Dispatcher own-only visibility remains intact');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000007'), null, 'Operations cannot acknowledge a Driver notification');
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000005', true);
select is_empty($$select id from public.notifications$$, 'Inactive Driver is denied reads');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000010'), null, 'Inactive Driver is denied acknowledgement');
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000006', true);
select is_empty($$select id from public.notifications$$, 'Missing Profile is denied reads');
select is(public.acknowledge_notification('f6000000-0000-0000-0000-000000000010'), null, 'Missing Profile is denied acknowledgement');

reset role;
set local role anon;
select throws_ok($$select id from public.notifications$$, '42501', null, 'Anonymous read is denied');
select throws_ok($$select public.acknowledge_notification('f6000000-0000-0000-0000-000000000001')$$, '42501', null, 'Anonymous acknowledgement is denied');

reset role;
select ok(pg_get_functiondef('public.assign_pending_shipment(uuid,uuid,uuid)'::regprocedure) like '%shipment_assigned%', 'S1 assignment producer remains present');
select ok(pg_get_functiondef('public.create_shipment_status_request(public.shipment_status)'::regprocedure) like '%status_approval_requested%', 'S2 Operations producer remains present');
select ok(pg_get_functiondef('public.approve_shipment_status_request(uuid)'::regprocedure) like '%status_approved%', 'S2 approval producer remains present');
select ok(pg_get_functiondef('public.reject_shipment_status_request(uuid,text)'::regprocedure) like '%status_rejected%', 'S2 rejection producer remains present');
select ok(pg_get_functiondef('public.cancel_shipment(uuid)'::regprocedure) like '%shipment_cancelled%', 'S3 cancellation producer remains present');
select ok(pg_get_functiondef('public.send_driver_message(uuid,uuid,text)'::regprocedure) like '%new_dispatcher_message%', 'S6B message producer remains present');

select * from finish();
rollback;
