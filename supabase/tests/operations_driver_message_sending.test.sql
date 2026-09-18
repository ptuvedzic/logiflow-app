begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id)
values
  ('f1000000-0000-0000-0000-000000000001'),
  ('f1000000-0000-0000-0000-000000000002'),
  ('f1000000-0000-0000-0000-000000000003'),
  ('f1000000-0000-0000-0000-000000000004'),
  ('f1000000-0000-0000-0000-000000000005'),
  ('f1000000-0000-0000-0000-000000000006'),
  ('f1000000-0000-0000-0000-000000000007');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('f1000000-0000-0000-0000-000000000001', 'S6B Admin', 's6b-admin', 'admin', true),
  ('f1000000-0000-0000-0000-000000000002', 'S6B Dispatcher', 's6b-dispatcher', 'dispatcher', true),
  ('f1000000-0000-0000-0000-000000000003', 'S6B Driver Available', 's6b-driver-a', 'driver', true),
  ('f1000000-0000-0000-0000-000000000004', 'S6B Driver Archived', 's6b-driver-b', 'driver', true),
  ('f1000000-0000-0000-0000-000000000005', 'S6B Driver Inactive', 's6b-driver-c', 'driver', true),
  ('f1000000-0000-0000-0000-000000000006', 'S6B Deactivated Driver', 's6b-driver-d', 'driver', false),
  ('f1000000-0000-0000-0000-000000000007', 'S6B Inactive Dispatcher', 's6b-inactive-dispatcher', 'dispatcher', false);

insert into public.drivers (id, profile_id, status)
values
  ('f2000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000003', 'available'),
  ('f2000000-0000-0000-0000-000000000002', 'f1000000-0000-0000-0000-000000000004', 'archived'),
  ('f2000000-0000-0000-0000-000000000003', 'f1000000-0000-0000-0000-000000000005', 'inactive'),
  ('f2000000-0000-0000-0000-000000000004', 'f1000000-0000-0000-0000-000000000006', 'off_duty');

insert into public.clients (id, company_name)
values ('f3000000-0000-0000-0000-000000000001', 'S6B Client');

insert into public.vehicles (id, registration, make, model, vehicle_type, status)
select
  ('f4000000-0000-0000-0000-' || pg_catalog.lpad(value::text, 12, '0'))::uuid,
  'S6B-' || value, 'Make', 'Model', 'Truck',
  case when value <= 4 then 'in_use'::public.vehicle_status else 'available'::public.vehicle_status end
from generate_series(1, 6) value;

insert into public.shipments (
  id, tracking_number, client_id, pickup_address, delivery_address,
  pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status
)
values
  ('f5000000-0000-0000-0000-000000000001', 'S6B-ASSIGNED', 'f3000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', 'f2000000-0000-0000-0000-000000000001', 'f4000000-0000-0000-0000-000000000001', 1, 'assigned'),
  ('f5000000-0000-0000-0000-000000000004', 'S6B-DELIVERED', 'f3000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', 'f2000000-0000-0000-0000-000000000001', 'f4000000-0000-0000-0000-000000000004', 1, 'delivered'),
  ('f5000000-0000-0000-0000-000000000005', 'S6B-CANCELLED', 'f3000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', 'f2000000-0000-0000-0000-000000000001', 'f4000000-0000-0000-0000-000000000005', 1, 'cancelled'),
  ('f5000000-0000-0000-0000-000000000006', 'S6B-PENDING', 'f3000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo', null, null, 1, 'pending');

select has_function('public', 'send_driver_message', array['uuid', 'uuid', 'text'], 'Narrow send function exists');
select has_function('public', 'list_message_recipient_options', array[]::text[], 'Recipient option function exists');
select has_function('public', 'list_message_shipment_options', array[]::text[], 'Shipment option function exists');
select has_index('public', 'messages', 'messages_sender_sent_at_idx', 'Sender/time rate-limit index exists');
select col_is_pk('public', 'messages', 'id', 'Messages retain their primary key');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select display_name from public.list_message_recipient_options() where id='f2000000-0000-0000-0000-000000000001'$$,
  $$values ('S6B Driver Available'::text)$$,
  'Options expose only eligible Drivers'
);
select is((select count(*) from public.list_message_shipment_options() where id::text like 'f5000000-%'), 3::bigint, 'Shipment options exclude fixture rows without a Driver');

create temporary table first_send as
select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, '  Standalone body  ');
reset role;
select is((select body from public.messages where id = (select message_id from first_send)), 'Standalone body', 'Body is trimmed before persistence');
select is((select sender_profile_id from public.messages where id = (select message_id from first_send)), 'f1000000-0000-0000-0000-000000000001'::uuid, 'Sender comes from the session');
select is((select read_at from public.messages where id = (select message_id from first_send)), null, 'Message starts unread');
select is((select shipment_id from public.messages where id = (select message_id from first_send)), null, 'Standalone message has no Shipment');
select is((select count(*) from public.notifications where id = (select notification_id from first_send)), 1::bigint, 'Committed message creates exactly one notification');
select is((select notification_type from public.notifications where id = (select notification_id from first_send)), 'new_dispatcher_message'::public.notification_type, 'Notification type is exact');
select is((select title from public.notifications where id = (select notification_id from first_send)), 'New message from Operations', 'Notification title is exact');
select is((select message from public.notifications where id = (select notification_id from first_send)), 'You have received a new message from Operations.', 'Notification copy is exact and excludes body');
select ok((select num_nonnulls(shipment_id, vehicle_id, driver_id, document_id) = 0 from public.notifications where id = (select notification_id from first_send)), 'Standalone notification has no entity FK');
select is((select count(*) from public.activity_logs where actor_profile_id = 'f1000000-0000-0000-0000-000000000001'), 0::bigint, 'Send creates no activity');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000001', true);
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000001', repeat('x', 500))$$, 'Exactly 500 characters are accepted');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, repeat('x', 501))$$, '22023', 'message_send_body_invalid', '501 characters are rejected');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, '   ')$$, '22023', 'message_send_body_invalid', 'Blank-after-trim is rejected');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000002', null, 'No')$$, 'P0002', 'message_send_driver_unavailable', 'Archived Driver is unavailable');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000003', null, 'No')$$, 'P0002', 'message_send_driver_unavailable', 'Inactive Driver is unavailable');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000004', null, 'No')$$, 'P0002', 'message_send_driver_unavailable', 'Deactivated Driver is unavailable');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000099', null, 'No')$$, 'P0002', 'message_send_driver_unavailable', 'Missing Driver is unavailable');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000006', 'No')$$, 'P0001', 'message_send_shipment_driver_mismatch', 'Shipment/Driver mismatch is rejected');
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000099', 'No')$$, 'P0002', 'message_send_shipment_unavailable', 'Missing Shipment is unavailable');

reset role;
update public.shipments set status='loading' where id='f5000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000001', true);
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000001', 'Loading')$$, 'Loading Shipment relationship is accepted');
reset role;
update public.shipments set status='in_transit' where id='f5000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000001', true);
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000001', 'Transit')$$, 'In-transit Shipment relationship is accepted');
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000004', 'Delivered')$$, 'Delivered Shipment relationship is accepted');
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', 'f5000000-0000-0000-0000-000000000005', 'Cancelled')$$, 'Cancelled Shipment relationship is accepted');
reset role;
select ok((select shipment_id = 'f5000000-0000-0000-0000-000000000005' and vehicle_id is null and driver_id is null and document_id is null from public.notifications where title = 'New message from Operations' and shipment_id = 'f5000000-0000-0000-0000-000000000005'), 'Linked notification contains only shipment_id');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000002', true);
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, 'Dispatcher message')$$, 'Active Dispatcher can send');
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000003', true);
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, 'Driver send')$$, '42501', 'message_send_access_denied', 'Driver cannot send');
select ok((select count(*) > 0 from public.messages), 'Driver sees their own newly sent messages under existing RLS');
select ok(public.acknowledge_driver_message((select id from public.messages order by sent_at limit 1)) is not null, 'Existing Driver acknowledgement remains available');
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000007', true);
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, 'Inactive sender')$$, '42501', 'message_send_access_denied', 'Inactive Operations actor cannot send');

select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000002', true);
select is_empty($$select id from public.messages$$, 'Dispatcher cannot select message history');
select throws_ok($$insert into public.messages(id,sender_profile_id,recipient_driver_id,body) values(gen_random_uuid(),'f1000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001','Direct')$$, '42501', null, 'Direct message INSERT remains denied');
select throws_ok($$update public.messages set body='Changed'$$, '42501', null, 'Direct message UPDATE remains denied');
select throws_ok($$delete from public.messages$$, '42501', null, 'Message DELETE remains denied');

reset role;
select throws_ok($$insert into public.messages(id,sender_profile_id,recipient_driver_id,body) values(gen_random_uuid(),'f1000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001',' untrimmed ')$$, '23514', null, 'PostgreSQL independently rejects unnormalized bodies');
select throws_ok($$insert into public.messages(id,sender_profile_id,recipient_driver_id,body) values(gen_random_uuid(),'f1000000-0000-0000-0000-000000000002','f2000000-0000-0000-0000-000000000001',repeat('x',501))$$, '23514', null, 'PostgreSQL independently rejects bodies over 500 characters');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000002', true);
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, 'Duplicate')$$, 'First duplicate submission commits');
select lives_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, 'Duplicate')$$, 'Second duplicate submission commits independently');
reset role;
select is((select count(*) from public.messages where sender_profile_id='f1000000-0000-0000-0000-000000000002' and body='Duplicate'), 2::bigint, 'Duplicate submissions create two messages');
select is((select count(*) from public.notifications where recipient_profile_id='f1000000-0000-0000-0000-000000000003' and notification_type='new_dispatcher_message'), (select count(*) from public.messages where recipient_driver_id='f2000000-0000-0000-0000-000000000001'), 'Committed messages and notifications have equal cardinality');

reset role;
insert into public.messages(id,sender_profile_id,recipient_driver_id,body,sent_at)
select gen_random_uuid(), 'f1000000-0000-0000-0000-000000000002', 'f2000000-0000-0000-0000-000000000001', 'Rate seed ' || value, transaction_timestamp()
from generate_series(1, 7) value;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', 'f1000000-0000-0000-0000-000000000002', true);
select throws_ok($$select * from public.send_driver_message('f2000000-0000-0000-0000-000000000001', null, 'Eleventh')$$, 'P0001', 'message_send_rate_limited', 'Send 11 in the rolling window is rejected');
reset role;
select is((select count(*) from public.messages where sender_profile_id='f1000000-0000-0000-0000-000000000002' and sent_at >= transaction_timestamp()-interval '10 minutes'), 10::bigint, 'Exactly ten successful sends consume capacity');

select * from finish();
rollback;
