begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
  ('e1000000-0000-0000-0000-000000000001'),
  ('e1000000-0000-0000-0000-000000000002'),
  ('e1000000-0000-0000-0000-000000000003'),
  ('e1000000-0000-0000-0000-000000000004');
insert into public.profiles(id,full_name,username,role,is_active) values
  ('e1000000-0000-0000-0000-000000000001','S5 Admin','s5-admin','admin',true),
  ('e1000000-0000-0000-0000-000000000002','S5 Dispatcher','s5-dispatcher','dispatcher',true),
  ('e1000000-0000-0000-0000-000000000003','S5 Driver','s5-driver','driver',true),
  ('e1000000-0000-0000-0000-000000000004','S5 Inactive','s5-inactive','admin',false);
insert into public.drivers(id,profile_id,status) values ('e2000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000003','assigned');
insert into public.clients(id,company_name,status) values ('e3000000-0000-0000-0000-000000000001','S5 Client','active');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values ('e4000000-0000-0000-0000-000000000001','S5-VEHICLE','Make','Model','Truck','in_use');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status)
values ('e5000000-0000-0000-0000-000000000001','SHP-S5','e3000000-0000-0000-0000-000000000001','A','B',now(),now()+interval '1 hour','Cargo','e2000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001',10,'assigned');
insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status)
values ('e6000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001','assigned','loading');

insert into public.activity_logs(id,actor_profile_id,action_type,client_id) values
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','client_created','e3000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','client_updated','e3000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','client_archived','e3000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','client_reactivated','e3000000-0000-0000-0000-000000000001');
insert into public.activity_logs(id,actor_profile_id,action_type,driver_id) values
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','driver_status_changed','e2000000-0000-0000-0000-000000000001');
insert into public.activity_logs(id,actor_profile_id,action_type,vehicle_id) values
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','vehicle_created','e4000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','vehicle_updated','e4000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','vehicle_status_changed','e4000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','vehicle_archived','e4000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),null,'alert_created','e4000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),null,'alert_resolved','e4000000-0000-0000-0000-000000000001');
insert into public.activity_logs(id,actor_profile_id,action_type,shipment_id) values
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','shipment_created','e5000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','shipment_assigned','e5000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','shipment_updated','e5000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','shipment_status_changed','e5000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','shipment_cancelled','e5000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','tracking_started','e5000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','tracking_stopped','e5000000-0000-0000-0000-000000000001');
insert into public.activity_logs(id,actor_profile_id,action_type,status_request_id) values
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000003','status_request_created','e6000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','status_request_approved','e6000000-0000-0000-0000-000000000001'),
  (gen_random_uuid(),'e1000000-0000-0000-0000-000000000001','status_request_rejected','e6000000-0000-0000-0000-000000000001');
insert into public.alerts(id,alert_type,severity,message,vehicle_id) values ('e7000000-0000-0000-0000-000000000001','stale_vehicle_location','critical','S5 active stale alert','e4000000-0000-0000-0000-000000000001');
insert into public.alerts(id,alert_type,severity,message,shipment_id,alert_state,resolved_at,resolved_by_profile_id) values ('e7000000-0000-0000-0000-000000000002','shipment_delayed','warning','S5 resolved shipment alert','e5000000-0000-0000-0000-000000000001','resolved',now(),null);

set local role authenticated; select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000001',true);
select is((select count(distinct action_type) from public.activity_logs),21::bigint,'Admin sees every currently implemented activity category');
select is((select count(*) from public.alerts),2::bigint,'Admin sees active and resolved alerts');
select is((select count(*) from public.shipments where id='e5000000-0000-0000-0000-000000000001'),0::bigint,'Admin cannot bypass Shipment label RLS');
select is((select count(*) from public.vehicles where id='e4000000-0000-0000-0000-000000000001'),0::bigint,'Admin cannot bypass Vehicle label RLS');
select is((select count(*) from public.documents),0::bigint,'Admin cannot obtain unauthorized Document labels');
select is((select count(*) from public.profiles where id='e1000000-0000-0000-0000-000000000002'),0::bigint,'Admin cannot obtain another Operations profile label');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000002',true);
select is((select count(*) from public.activity_logs),10::bigint,'Dispatcher sees every and only authorized Shipment workflow activity row');
select is((select count(*) from public.activity_logs where shipment_id is not null),7::bigint,'Dispatcher sees all Shipment-primary and tracking rows');
select is((select count(*) from public.activity_logs where status_request_id is not null),3::bigint,'Dispatcher sees all authorized status-request rows');
select is((select count(*) from public.activity_logs where action_type in ('status_request_created','status_request_approved','status_request_rejected')),3::bigint,'Status-request activity remains visible');
select is((select count(*) from public.activity_logs where client_id is not null or driver_id is not null or vehicle_id is not null),0::bigint,'Dispatcher cannot obtain excluded primary categories');
select is((select count(*) from public.activity_logs where action_type in ('alert_created','alert_resolved')),0::bigint,'Dispatcher cannot obtain stale-alert activity');
select is((select count(*) from public.activity_logs where actor_profile_id='e1000000-0000-0000-0000-000000000001' and vehicle_id='e4000000-0000-0000-0000-000000000001'),0::bigint,'Crafted actor and Vehicle predicates do not widen activity access');
select is((select count(*) from public.activity_logs where metadata @> '{}'::jsonb and client_id='e3000000-0000-0000-0000-000000000001'),0::bigint,'Crafted metadata and Client predicates do not widen activity access');
select is((select count(*) from public.alerts),2::bigint,'Dispatcher alert visibility is independent from activity visibility');
select is((select count(*) from public.shipments where id='e5000000-0000-0000-0000-000000000001'),0::bigint,'Dispatcher cannot obtain a Shipment label through a crafted join source');
select throws_ok($$select count(*) from public.shipment_status_requests$$,'42501',null,'Dispatcher cannot obtain status-request label data');
select is((select count(*) from public.profiles where id='e1000000-0000-0000-0000-000000000001'),0::bigint,'Dispatcher cannot obtain another Operations actor label');

reset role; set local role authenticated; select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000003',true);
select is((select count(*) from public.activity_logs),0::bigint,'Driver sees no activity-center rows');
select is((select count(*) from public.alerts),0::bigint,'Driver sees no alerts-center rows');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000004',true);
select is((select count(*) from public.activity_logs),0::bigint,'Inactive profile sees no activity');
select is((select count(*) from public.alerts),0::bigint,'Inactive profile sees no alerts');
reset role; set local role authenticated; reset "request.jwt.claim.sub";
select is((select count(*) from public.activity_logs),0::bigint,'Missing authenticated identity sees no activity');
select is((select count(*) from public.alerts),0::bigint,'Missing authenticated identity sees no alerts');

reset role; set local role anon;
select throws_ok($$select count(*) from public.activity_logs$$,'42501',null,'Anonymous caller lacks activity SELECT');
select throws_ok($$select count(*) from public.alerts$$,'42501',null,'Anonymous caller lacks alert SELECT');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','e1000000-0000-0000-0000-000000000002',true);
select throws_ok($$insert into public.alerts(id,alert_type,severity,message,vehicle_id) values(gen_random_uuid(),'stale_vehicle_location','critical','forbidden','e4000000-0000-0000-0000-000000000001')$$,'42501',null,'Browser alert INSERT is denied');
select throws_ok($$update public.alerts set message='forbidden' where id='e7000000-0000-0000-0000-000000000001'$$,'42501',null,'Browser alert UPDATE is denied');
select throws_ok($$delete from public.alerts where id='e7000000-0000-0000-0000-000000000001'$$,'42501',null,'Browser alert DELETE is denied');
select throws_ok($$insert into public.activity_logs(id,action_type,shipment_id) values(gen_random_uuid(),'shipment_created','e5000000-0000-0000-0000-000000000001')$$,'42501',null,'Browser activity INSERT is denied');
select throws_ok($$update public.activity_logs set metadata='{}' where shipment_id='e5000000-0000-0000-0000-000000000001'$$,'42501',null,'Browser activity UPDATE is denied');
select throws_ok($$delete from public.activity_logs where shipment_id='e5000000-0000-0000-0000-000000000001'$$,'42501',null,'Browser activity DELETE is denied');

reset role;
select ok(not has_table_privilege('authenticated','public.shipment_status_requests','SELECT'),'S5 added no status-request table grant');
select ok(not has_table_privilege('authenticated','public.maintenance_records','SELECT'),'S5 added no maintenance table grant');
select ok(not has_table_privilege('authenticated','public.expenses','SELECT'),'S5 added no expense table grant');
select is((select alert_state from public.alerts where id='e7000000-0000-0000-0000-000000000002'),'resolved'::public.alert_state,'Resolved alert history remains retained');
select is((select count(*) from public.activity_logs where id is not null),21::bigint,'Activity history remains append-only after denied writes');
select * from finish();
rollback;
