begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
('d1000000-0000-0000-0000-000000000001'),('d1000000-0000-0000-0000-000000000002');
insert into public.profiles(id,full_name,username,role,is_active) values
('d1000000-0000-0000-0000-000000000001','S4 Admin','s4-admin','admin',true),
('d1000000-0000-0000-0000-000000000002','S4 Driver','s4-driver','driver',true);
insert into public.drivers(id,profile_id,status) values
('d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000002','assigned');
insert into public.clients(id,company_name,status) values
('d3000000-0000-0000-0000-000000000001','S4 Client','active');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
('d4000000-0000-0000-0000-000000000001','S4-TRACK','Make','Model','Truck','in_use');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status,delayed)
values('d5000000-0000-0000-0000-000000000001','SHP-2026-S4','d3000000-0000-0000-0000-000000000001','Novi Sad','Belgrade',now(),now()+interval '2 hours','General','d2000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',100,'in_transit',true);

insert into public.alerts(id,alert_type,severity,message,vehicle_id)
values('d6000000-0000-0000-0000-000000000001','stale_vehicle_location','critical','Unresolved','d4000000-0000-0000-0000-000000000001');
select lives_ok($$update public.alerts set message='Still unresolved' where id='d6000000-0000-0000-0000-000000000001'$$,'unresolved with null resolver is allowed');
select throws_ok($$update public.alerts set resolved_by_profile_id='d1000000-0000-0000-0000-000000000001' where id='d6000000-0000-0000-0000-000000000001'$$,'23514',null,'unresolved with resolver is rejected');
select lives_ok($$update public.alerts set alert_state='resolved',resolved_at=now(),resolved_by_profile_id='d1000000-0000-0000-0000-000000000001' where id='d6000000-0000-0000-0000-000000000001'$$,'resolved with human resolver is allowed');
insert into public.alerts(id,alert_type,severity,message,vehicle_id)
values('d6000000-0000-0000-0000-000000000002','stale_vehicle_location','critical','System resolution','d4000000-0000-0000-0000-000000000001');
select lives_ok($$update public.alerts set alert_state='resolved',resolved_at=now(),resolved_by_profile_id=null where id='d6000000-0000-0000-0000-000000000002'$$,'resolved with null resolver is allowed');

insert into public.vehicle_locations(vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress,updated_at)
values('d4000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000001',45.2671,19.8335,0,0,0,now()-interval '120 seconds');
insert into public.tracking_history(id,vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress,recorded_at)
values(gen_random_uuid(),'d4000000-0000-0000-0000-000000000001','d5000000-0000-0000-0000-000000000001',45.2671,19.8335,0,0,0,now()-interval '120 seconds');
insert into public.alerts(id,alert_type,severity,message,vehicle_id)
values('d6000000-0000-0000-0000-000000000003','stale_vehicle_location','critical','Recover me','d4000000-0000-0000-0000-000000000001');

set local role service_role;
select is((select step_result from public.simulate_tracking_step('d5000000-0000-0000-0000-000000000001','[[19.8335,45.2671],[20.4489,44.7866]]'::jsonb)),'advanced','trusted step advances');
reset role;
select cmp_ok((select route_progress from public.vehicle_locations where vehicle_id='d4000000-0000-0000-0000-000000000001'),'>',0::numeric,'progress advances');
select is((select speed from public.vehicle_locations where vehicle_id='d4000000-0000-0000-0000-000000000001'),60.00::numeric,'moving speed is 60 km/h');
select ok((select heading >= 0 and heading < 360 from public.vehicle_locations where vehicle_id='d4000000-0000-0000-0000-000000000001'),'heading is normalized');
select is((select delayed from public.shipments where id='d5000000-0000-0000-0000-000000000001'),true,'simulation does not change delayed');
select is((select status from public.shipments where id='d5000000-0000-0000-0000-000000000001'),'in_transit'::public.shipment_status,'simulation does not deliver');
select is((select count(*) from public.tracking_history where shipment_id='d5000000-0000-0000-0000-000000000001'),2::bigint,'moving 60-second interval appends history');
select is((select count(*) from public.activity_logs where vehicle_id='d4000000-0000-0000-0000-000000000001' and action_type='alert_resolved'),1::bigint,'simulation recovery creates one alert resolution activity');
select is((select resolved_by_profile_id from public.alerts where id='d6000000-0000-0000-0000-000000000003'),null::uuid,'system recovery has null resolver');
select is((select count(*) from public.notifications where vehicle_id='d4000000-0000-0000-0000-000000000001'),0::bigint,'simulation creates no notification');

update public.vehicle_locations
set latitude=44.7866,longitude=20.4489,speed=60,heading=140,route_progress=100,updated_at=now()-interval '10 seconds'
where vehicle_id='d4000000-0000-0000-0000-000000000001';
set local role service_role;
select is((select step_result from public.simulate_tracking_step('d5000000-0000-0000-0000-000000000001','[[19.8335,45.2671],[20.4489,44.7866]]'::jsonb)),'heartbeat','destination receives a heartbeat');
reset role;
select is((select route_progress from public.vehicle_locations where vehicle_id='d4000000-0000-0000-0000-000000000001'),100.00::numeric,'destination progress remains 100');
select is((select speed from public.vehicle_locations where vehicle_id='d4000000-0000-0000-0000-000000000001'),0.00::numeric,'destination heartbeat sets speed zero');
select is((select count(*) from public.tracking_history where shipment_id='d5000000-0000-0000-0000-000000000001'),2::bigint,'destination heartbeat adds no history snapshot');
select is((select count(*) from public.activity_logs where shipment_id='d5000000-0000-0000-0000-000000000001'),0::bigint,'tracking samples and heartbeats add no tracking activity');

update public.vehicle_locations set updated_at=now()-interval '11 minutes' where vehicle_id='d4000000-0000-0000-0000-000000000001';
set local role service_role;
select is((select created_count from public.reconcile_stale_vehicle_locations()),1,'reconciliation creates stale alert');
select is((select created_count from public.reconcile_stale_vehicle_locations()),0,'reconciliation retains active alert idempotently');
reset role;
select is((select severity from public.alerts where vehicle_id='d4000000-0000-0000-0000-000000000001' and alert_state='active'),'critical'::public.alert_severity,'stale severity is critical');
select is((select message from public.alerts where vehicle_id='d4000000-0000-0000-0000-000000000001' and alert_state='active'),'Vehicle location has not updated for more than 10 minutes.','stale message is exact');
update public.vehicle_locations set updated_at=now() where vehicle_id='d4000000-0000-0000-0000-000000000001';
set local role service_role;
select is((select resolved_count from public.reconcile_stale_vehicle_locations()),1,'reconciliation resolves recovered alert');
reset role;
select is((select count(*) from public.activity_logs where vehicle_id='d4000000-0000-0000-0000-000000000001' and action_type='alert_created'),1::bigint,'one alert creation activity');
select is((select count(*) from public.activity_logs where vehicle_id='d4000000-0000-0000-0000-000000000001' and action_type='alert_resolved'),2::bigint,'one recovery and one reconciliation resolution activity');

select ok(not has_function_privilege('authenticated','public.simulate_tracking_step(uuid,jsonb)','EXECUTE'),'browser cannot execute simulation');
select ok(not has_function_privilege('authenticated','public.reconcile_stale_vehicle_locations()','EXECUTE'),'browser cannot execute reconciliation');
set local role authenticated;
set local "request.jwt.claim.sub"='d1000000-0000-0000-0000-000000000001';
select throws_ok($$update public.alerts set alert_state='resolved',resolved_at=now(),resolved_by_profile_id=null where id='d6000000-0000-0000-0000-000000000001'$$,'42501',null,'browser cannot exploit null resolver state');
reset role;

select * from finish();
rollback;
