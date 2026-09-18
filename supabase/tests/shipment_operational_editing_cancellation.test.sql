begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
('b1000000-0000-0000-0000-000000000001'),('b1000000-0000-0000-0000-000000000002'),
('b1000000-0000-0000-0000-000000000003'),('b1000000-0000-0000-0000-000000000004');
insert into public.profiles(id,full_name,username,role,is_active) values
('b1000000-0000-0000-0000-000000000001','S3 Admin','s3-admin','admin',true),
('b1000000-0000-0000-0000-000000000002','S3 Dispatcher','s3-dispatcher','dispatcher',true),
('b1000000-0000-0000-0000-000000000003','S3 Driver','s3-driver','driver',true),
('b1000000-0000-0000-0000-000000000004','S3 Inactive','s3-inactive','dispatcher',false);
insert into public.clients(id,company_name) values('b3000000-0000-0000-0000-000000000001','S3 Client');
insert into public.drivers(id,profile_id,status) values('b2000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000003','assigned');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values('b4000000-0000-0000-0000-000000000001','S3-TRACK','Test','Truck','Truck','in_use');

insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
('b5000000-0000-0000-0000-000000000001','SHP-S3-EDIT','b3000000-0000-0000-0000-000000000001',' A ',' B ','2025-01-01T10:00:00Z','2025-01-01T11:00:00Z',' Cargo ',null,null,10,'pending'),
('b5000000-0000-0000-0000-000000000002','SHP-S3-DELIVERED','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'delivered'),
('b5000000-0000-0000-0000-000000000003','SHP-S3-PENDING','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',null,null,10,'pending'),
('b5000000-0000-0000-0000-000000000004','SHP-S3-CANCELLED','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',null,null,10,'cancelled');

select ok(has_function_privilege('authenticated','public.update_shipment_details(uuid,timestamptz,text,text,timestamptz,timestamptz,text,numeric)','execute'),'Authenticated can execute narrow edit');
select ok(has_function_privilege('authenticated','public.cancel_shipment(uuid)','execute'),'Authenticated can execute narrow cancellation');
select ok(not has_function_privilege('authenticated','public.stop_shipment_tracking(uuid,uuid,uuid)','execute'),'Browser cannot call S2 tracking wrapper');
select ok(not has_function_privilege('authenticated','public.stop_shipment_tracking(uuid,uuid,uuid,text)','execute'),'Browser cannot call sourced tracking helper');
select ok(not has_function_privilege('anon','public.stop_shipment_tracking(uuid,uuid,uuid)','execute') and not exists(select 1 from pg_proc cross join lateral aclexplode(proacl) acl where oid='public.stop_shipment_tracking(uuid,uuid,uuid)'::regprocedure and acl.grantee=0 and acl.privilege_type='EXECUTE'),'Anon and PUBLIC cannot call S2 tracking wrapper');
select ok(not has_function_privilege('anon','public.stop_shipment_tracking(uuid,uuid,uuid,text)','execute') and not exists(select 1 from pg_proc cross join lateral aclexplode(proacl) acl where oid='public.stop_shipment_tracking(uuid,uuid,uuid,text)'::regprocedure and acl.grantee=0 and acl.privilege_type='EXECUTE'),'Anon and PUBLIC cannot call sourced tracking helper');
select ok('shipment_cancelled'=any(enum_range(null::public.notification_type)::text[]),'Cancellation notification enum exists');

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,' Pickup ',' Delivery ','2020-01-01T10:00:00Z','2020-01-01T12:00:00Z',' Food ',25)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Admin edits every approved field and past schedule');
reset role;
select ok((select pickup_address='Pickup' and delivery_address='Delivery' and cargo_type='Food' and price=25 and pickup_at='2020-01-01T10:00:00Z' and expected_delivery_at='2020-01-01T12:00:00Z' from public.shipments where id='b5000000-0000-0000-0000-000000000001'),'Edit normalizes and stores exact approved values');
select is((select metadata from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000001' and action_type='shipment_updated'),'{"changed_fields":["pickup_address","delivery_address","pickup_at","expected_delivery_at","cargo_type","price"]}'::jsonb,'Edit activity has deterministic field names and no values');
select ok((select proargnames[1:8]=array['target_shipment_id','expected_updated_at','input_pickup_address','input_delivery_address','input_pickup_at','input_expected_delivery_at','input_cargo_type','input_price'] from pg_proc where oid='public.update_shipment_details(uuid,timestamptz,text,text,timestamptz,timestamptz,text,numeric)'::regprocedure),'Edit RPC exposes only approved mutable inputs');

create temporary table s3_edit_snapshot as
select updated_at, (select count(*) from public.activity_logs where shipment_id=shipments.id and action_type='shipment_updated') as activity_count
from public.shipments where id='b5000000-0000-0000-0000-000000000001';

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select is((select mutated from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001')),' Pickup ','Delivery','2020-01-01T10:00:00Z','2020-01-01T12:00:00Z','Food',25)),false,'Normalized no-op succeeds');
reset role;
select is((select count(*) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000001' and action_type='shipment_updated'),1::bigint,'No-op creates zero additional activity');
select ok((select shipments.updated_at=s3_edit_snapshot.updated_at and s3_edit_snapshot.activity_count=1 from public.shipments cross join s3_edit_snapshot where shipments.id='b5000000-0000-0000-0000-000000000001'),'No-op leaves updated_at unchanged');

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000002';
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch','Delivery','2020-01-01T10:00:00Z','2020-01-01T12:00:00Z','Food',null)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Dispatcher edits operational fields without price');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch','Delivery','2020-01-01T10:00:00Z','2020-01-01T12:00:00Z','Food',30)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'42501','shipment_edit_price_forbidden','Dispatcher price input is denied');
reset role;
select is((select price from public.shipments where id='b5000000-0000-0000-0000-000000000001'),25::numeric,'Dispatcher preserves trusted price');

-- Exercise each editable field independently and prove the exact one-field metadata.
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch 2','Delivery','2020-01-01T10:00:00Z','2020-01-01T12:00:00Z','Food',25)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Pickup address edits independently');
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch 2','Delivery 2','2020-01-01T10:00:00Z','2020-01-01T12:00:00Z','Food',25)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Delivery address edits independently');
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch 2','Delivery 2','2020-01-01T10:30:00Z','2020-01-01T12:00:00Z','Food',25)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Pickup instant edits independently');
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch 2','Delivery 2','2020-01-01T10:30:00Z','2020-01-01T12:30:00Z','Food',25)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Delivery instant edits independently');
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch 2','Delivery 2','2020-01-01T10:30:00Z','2020-01-01T12:30:00Z','Food 2',25)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Cargo type edits independently');
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'Dispatch 2','Delivery 2','2020-01-01T10:30:00Z','2020-01-01T12:30:00Z','Food 2',26)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'Price edits independently');
reset role;
select is((select count(distinct metadata) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000001' and metadata in ('{"changed_fields":["pickup_address"]}','{"changed_fields":["delivery_address"]}','{"changed_fields":["pickup_at"]}','{"changed_fields":["expected_delivery_at"]}','{"changed_fields":["cargo_type"]}','{"changed_fields":["price"]}')),6::bigint,'Each independent field edit has exact metadata');

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select throws_ok($$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001','2000-01-01','A','B',now(),now(),'C',1)$$,'40001','shipment_edit_stale','Stale edit is denied');
select is((select pickup_address from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001')),'Dispatch 2','Stale edit has zero mutation effect');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,' ','B',now(),now(),'C',1)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'22023','shipment_edit_blank','Blank edit is denied');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'A',' ',now(),now(),'C',1)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'22023','shipment_edit_blank','Blank delivery address is denied');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'A','B',now(),now(),' ',1)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'22023','shipment_edit_blank','Blank cargo type is denied');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'A','B','2025-01-02','2025-01-01','C',1)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'22023','shipment_edit_schedule_invalid','Invalid schedule is denied');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'A','B',now(),now(),'C',-1)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'22023','shipment_edit_price_invalid','Negative price is denied');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',%L,'A','B',now(),now(),'C',null)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000001'))),'22023','shipment_edit_price_invalid','Admin null price is denied');
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000002',%L,'A','B',now(),now(),'C',1)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000002'))),'P0001','shipment_edit_status_invalid','Delivered edit is denied');
reset role;
select is((select count(*) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000001' and action_type='shipment_updated'),8::bigint,'Stale and invalid edits create zero additional activity');

reset "request.jwt.claim.sub"; set local role authenticated;
select throws_ok($$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',now(),'A','B',now(),now(),'C',1)$$,'42501','shipment_edit_access_denied','Unauthenticated edit is denied');
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000003')$$,'42501','shipment_cancellation_access_denied','Unauthenticated cancellation is denied');
select throws_ok($$select * from public.update_shipment_details('not-a-uuid'::uuid,now(),'A','B',now(),now(),'C',1)$$,'22P02',null,'Malformed edit target is rejected');
select throws_ok($$select * from public.cancel_shipment('not-a-uuid'::uuid)$$,'22P02',null,'Malformed cancellation target is rejected');
reset role;
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000003';
select throws_ok($$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',now(),'A','B',now(),now(),'C',1)$$,'42501','shipment_edit_access_denied','Driver cannot edit');
reset role;
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000004';
select throws_ok($$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000001',now(),'A','B',now(),now(),'C',1)$$,'42501','shipment_edit_access_denied','Inactive Operations caller cannot edit');
reset role;

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000003';
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000003')$$,'42501','shipment_cancellation_access_denied','Driver cannot cancel');
select throws_ok($$update public.shipments set status='cancelled' where id='b5000000-0000-0000-0000-000000000003'$$,'42501',null,'Direct Shipment update remains denied');
reset role;
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000004';
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000003')$$,'42501','shipment_cancellation_access_denied','Inactive Operations caller cannot cancel');
reset role;
select is((select count(*) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000003'),0::bigint,'Unauthorized cancellation attempts create no activity');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000003'),0::bigint,'Unauthorized cancellation attempts create no notification');

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000002';
select lives_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000003')$$,'Dispatcher cancels pending Shipment');
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000004')$$,'40001','shipment_cancellation_already_cancelled','Cancelled replay is rejected');
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000002')$$,'P0001','shipment_cancellation_delivered','Delivered cancellation is rejected');
reset role;
select ok((select status='cancelled' and not delayed from public.shipments where id='b5000000-0000-0000-0000-000000000003'),'Pending cancellation sets exact Shipment state');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000003'),0::bigint,'Pending cancellation sends no notification');
select is((select metadata from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000003' and action_type='shipment_cancelled'),'{"from_status":"pending"}'::jsonb,'Pending cancellation activity is exact');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000004'),0::bigint,'Cancelled replay creates no notification');

insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status,delayed) values
('b5000000-0000-0000-0000-000000000005','SHP-S3-TRACK','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'in_transit',true);
insert into public.alerts (id,alert_type,severity,message,alert_state,shipment_id,vehicle_id,driver_id,document_id,resolved_at,resolved_by_profile_id) values
('b7000000-0000-0000-0000-000000000002','shipment_delayed','warning','Shipment SHP-S3-TRACK has been marked as delayed.','active','b5000000-0000-0000-0000-000000000005',null,null,null,null,null);
insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status) values('b6000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000005','b2000000-0000-0000-0000-000000000001','in_transit','delivered');
insert into public.vehicle_locations(vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress) values('b4000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000005',45,19,5,90,50);
insert into public.tracking_history(id,vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress) values(gen_random_uuid(),'b4000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000005',44,18,0,0,0);
insert into public.alerts(id,alert_type,severity,message,vehicle_id) values('b7000000-0000-0000-0000-000000000001','stale_vehicle_location','critical','Stale','b4000000-0000-0000-0000-000000000001');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000005',%L,'A','B',now(),now(),'Cargo',10)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000005'))),'P0001','shipment_edit_status_invalid','In-transit Shipment edit is denied');
select lives_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000005')$$,'Admin cancels in-transit Shipment atomically');
reset role;
select ok((select status='cancelled' and not delayed from public.shipments where id='b5000000-0000-0000-0000-000000000005'),'In-transit cancellation clears delayed');
select is((select status from public.drivers where id='b2000000-0000-0000-0000-000000000001'),'available'::public.driver_status,'Cancellation releases Driver');
select is((select status from public.vehicles where id='b4000000-0000-0000-0000-000000000001'),'available'::public.vehicle_status,'Cancellation releases Vehicle');
select ok((select request_state='rejected' and resolved_at is not null and rejection_reason='Shipment cancelled' and resolved_by_profile_id='b1000000-0000-0000-0000-000000000001' from public.shipment_status_requests where id='b6000000-0000-0000-0000-000000000001'),'Pending request is rejected by cancelling actor');
select is((select metadata from public.activity_logs where status_request_id='b6000000-0000-0000-0000-000000000001' and action_type='status_request_rejected'),'{"from_status":"in_transit","requested_status":"delivered"}'::jsonb,'Cancellation request activity is exact');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000005' and notification_type='status_rejected'),0::bigint,'Cancellation suppresses status-rejected notification');
select ok((select count(*)=1 and min(recipient_profile_id::text)='b1000000-0000-0000-0000-000000000003' and min(title)='Shipment cancelled' and min(message)='Shipment SHP-S3-TRACK has been cancelled.' from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000005' and notification_type='shipment_cancelled'),'Cancellation notification is exact and singular');
select is((select count(*) from public.vehicle_locations where shipment_id='b5000000-0000-0000-0000-000000000005'),0::bigint,'Tracking stop removes current location');
select is((select count(*) from public.tracking_history where shipment_id='b5000000-0000-0000-0000-000000000005'),2::bigint,'Tracking stop preserves history and adds one final snapshot');
select is((select alert_state from public.alerts where id='b7000000-0000-0000-0000-000000000001'),'resolved'::public.alert_state,'Tracking stop resolves stale alert');
select is((select metadata from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000005' and action_type='tracking_stopped'),'{"source":"shipment_cancellation"}'::jsonb,'Cancellation tracking activity source is exact');
select is((select metadata from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000005' and action_type='shipment_cancelled'),'{"from_status":"in_transit"}'::jsonb,'In-transit cancellation activity is exact');

update public.drivers set status='assigned' where id='b2000000-0000-0000-0000-000000000001';
update public.vehicles set status='in_use' where id='b4000000-0000-0000-0000-000000000001';
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values('b5000000-0000-0000-0000-000000000006','SHP-S3-ASSIGNED','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'assigned');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000006',%L,'Assigned edit','B',now(),now(),'Cargo',10)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000006'))),'Assigned Shipment is editable');
select lives_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000006')$$,'Assigned Shipment is cancellable');
reset role;
select ok((select s.status='cancelled' and d.status='available' and v.status='available' from public.shipments s join public.drivers d on d.id=s.driver_id join public.vehicles v on v.id=s.vehicle_id where s.id='b5000000-0000-0000-0000-000000000006'),'Assigned cancellation releases both resources');

update public.drivers set status='assigned' where id='b2000000-0000-0000-0000-000000000001';
update public.vehicles set status='in_use' where id='b4000000-0000-0000-0000-000000000001';
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values('b5000000-0000-0000-0000-000000000007','SHP-S3-LOADING','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'loading');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000002';
select lives_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000007',%L,'Loading edit','B',now(),now(),'Cargo',null)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000007'))),'Loading Shipment is editable by Dispatcher');
select lives_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000007')$$,'Loading Shipment is cancellable');
reset role;
select ok((select s.status='cancelled' and d.status='available' and v.status='available' from public.shipments s join public.drivers d on d.id=s.driver_id join public.vehicles v on v.id=s.vehicle_id where s.id='b5000000-0000-0000-0000-000000000007'),'Loading cancellation releases both resources');

set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select throws_ok(format($q$select * from public.update_shipment_details('b5000000-0000-0000-0000-000000000005',%L,'A','B',now(),now(),'Cargo',10)$q$,(select updated_at from public.get_operations_shipment_for_edit('b5000000-0000-0000-0000-000000000005'))),'P0001','shipment_edit_status_invalid','Cancelled Shipment edit is denied');
select throws_ok($$select * from public.update_shipment_details('b5999999-0000-0000-0000-000000000001',now(),'A','B',now(),now(),'Cargo',10)$$,'P0002','shipment_edit_unavailable','Missing Shipment edit is denied');
select throws_ok($$select * from public.cancel_shipment('b5999999-0000-0000-0000-000000000001')$$,'P0002','shipment_cancellation_unavailable','Missing Shipment cancellation is denied');
reset role;

update public.drivers set status='assigned' where id='b2000000-0000-0000-0000-000000000001';
update public.vehicles set status='in_use' where id='b4000000-0000-0000-0000-000000000001';
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values('b5000000-0000-0000-0000-000000000008','SHP-S3-ROLLBACK','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'assigned');
alter table public.notifications add constraint s3_force_late_failure check (shipment_id <> 'b5000000-0000-0000-0000-000000000008' or title <> 'Shipment cancelled');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000008')$$,'23514',null,'Late notification failure aborts cancellation');
reset role;
alter table public.notifications drop constraint s3_force_late_failure;
select ok((select s.status='assigned' and d.status='assigned' and v.status='in_use' from public.shipments s join public.drivers d on d.id=s.driver_id join public.vehicles v on v.id=s.vehicle_id where s.id='b5000000-0000-0000-0000-000000000008'),'Late failure rolls back Shipment and resources');
select is((select count(*) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000008'),0::bigint,'Late failure rolls back activities');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000008'),0::bigint,'Late failure rolls back notifications');

delete from public.shipments where id='b5000000-0000-0000-0000-000000000008';
update public.drivers set status='assigned' where id='b2000000-0000-0000-0000-000000000001';
update public.vehicles set status='in_use' where id='b4000000-0000-0000-0000-000000000001';
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values('b5000000-0000-0000-0000-000000000009','SHP-S3-NO-LOCATION','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'in_transit');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select lives_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000009')$$,'In-transit cancellation succeeds without current location');
reset role;
select is((select count(*) from public.tracking_history where shipment_id='b5000000-0000-0000-0000-000000000009'),0::bigint,'Missing current location invents no history snapshot');
select is((select count(*) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000009' and action_type='tracking_stopped'),1::bigint,'Missing current location still records one tracking stop');

select throws_ok($$select public.stop_shipment_tracking('b5000000-0000-0000-0000-000000000005','b4000000-0000-0000-0000-000000000001','b1000000-0000-0000-0000-000000000001','arbitrary')$$,'22023','tracking_source_invalid','Tracking helper rejects arbitrary sources');

-- Contradictory assigned resources fail atomically with no observable effects.
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values('b5000000-0000-0000-0000-000000000010','SHP-S3-CONTRADICTION','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','b2000000-0000-0000-0000-000000000001','b4000000-0000-0000-0000-000000000001',10,'assigned');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000001';
select throws_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000010')$$,'P0001','shipment_cancellation_integrity','Contradictory released resources reject cancellation');
reset role;
select ok((select s.status='assigned' and d.status='available' and v.status='available' from public.shipments s join public.drivers d on d.id=s.driver_id join public.vehicles v on v.id=s.vehicle_id where s.id='b5000000-0000-0000-0000-000000000010'),'Integrity failure leaves Shipment and resources unchanged');
select is((select count(*) from public.activity_logs where shipment_id='b5000000-0000-0000-0000-000000000010'),0::bigint,'Integrity failure creates no activity');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000010'),0::bigint,'Integrity failure creates no notification');

-- Defensive pending cancellation resolves an unexpected pending S2 request.
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price,status) values('b5000000-0000-0000-0000-000000000011','SHP-S3-PENDING-REQUEST','b3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',10,'pending');
insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status) values('b6000000-0000-0000-0000-000000000011','b5000000-0000-0000-0000-000000000011','b2000000-0000-0000-0000-000000000001','assigned','loading');
set local role authenticated; set local "request.jwt.claim.sub"='b1000000-0000-0000-0000-000000000002';
select lives_ok($$select * from public.cancel_shipment('b5000000-0000-0000-0000-000000000011')$$,'Pending cancellation resolves an unexpected pending request');
reset role;
select ok((select request_state='rejected' and rejection_reason='Shipment cancelled' from public.shipment_status_requests where id='b6000000-0000-0000-0000-000000000011'),'Unexpected pending request is rejected, not deleted');
select is((select count(*) from public.notifications where shipment_id='b5000000-0000-0000-0000-000000000011'),0::bigint,'Pending cancellation with request still sends no notification');

select * from finish();
rollback;
