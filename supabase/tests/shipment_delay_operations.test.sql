begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
 ('f1000000-0000-0000-0000-000000000001'),('f1000000-0000-0000-0000-000000000002'),
 ('f1000000-0000-0000-0000-000000000003'),('f1000000-0000-0000-0000-000000000004'),
 ('f1000000-0000-0000-0000-000000000005');
insert into public.profiles(id,full_name,username,role,is_active) values
 ('f1000000-0000-0000-0000-000000000001','O1 Admin','o1-admin','admin',true),
 ('f1000000-0000-0000-0000-000000000002','O1 Dispatcher','o1-dispatcher','dispatcher',true),
 ('f1000000-0000-0000-0000-000000000003','O1 Driver','o1-driver','driver',true),
 ('f1000000-0000-0000-0000-000000000004','O1 Other Driver','o1-other','driver',true),
 ('f1000000-0000-0000-0000-000000000005','O1 Inactive','o1-inactive','admin',false);
insert into public.drivers(id,profile_id,status) values
 ('f2000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000003','assigned'),
 ('f2000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000004','assigned');
insert into public.clients(id,company_name,status) values ('f3000000-0000-0000-0000-000000000001','O1 Client','active');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
 ('f4000000-0000-0000-0000-000000000001','O1-A','M','A','Truck','in_use'),
 ('f4000000-0000-0000-0000-000000000002','O1-B','M','B','Truck','in_use');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
 ('f5000000-0000-0000-0000-000000000001','SHP-O1-A','f3000000-0000-0000-0000-000000000001','A','B',now(),now()+interval '1 day','Cargo','f2000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001',10,'in_transit'),
 ('f5000000-0000-0000-0000-000000000002','SHP-O1-P','f3000000-0000-0000-0000-000000000001','A','B',now(),now()+interval '1 day','Cargo',null,null,10,'pending');

set local role authenticated; select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000001',true);
select results_eq(format('select mutation_result,delayed from public.set_shipment_delayed(%L,true,%L)','f5000000-0000-0000-0000-000000000001',(select updated_at from public.list_operations_shipments() where id='f5000000-0000-0000-0000-000000000001')),$$values ('updated'::text,true)$$,'Admin marks delayed');
reset role;
select results_eq($$select alert_type,severity,alert_state,message,shipment_id,vehicle_id,driver_id,document_id from public.alerts where shipment_id='f5000000-0000-0000-0000-000000000001'$$,$$values ('shipment_delayed'::public.alert_type,'warning'::public.alert_severity,'active'::public.alert_state,'Shipment SHP-O1-A has been marked as delayed.'::text,'f5000000-0000-0000-0000-000000000001'::uuid,null::uuid,null::uuid,null::uuid)$$,'Mark alert is exact');
select results_eq($$select action_type,metadata from public.activity_logs where shipment_id='f5000000-0000-0000-0000-000000000001' order by action_type$$,$$values ('shipment_delayed'::public.activity_action_type,'{"delayed":true}'::jsonb),('alert_created'::public.activity_action_type,'{"alert_type":"shipment_delayed"}'::jsonb)$$,'Mark activities are exact');
select results_eq($$select recipient_profile_id,notification_type,title,message,shipment_id,vehicle_id,driver_id,document_id,read_at from public.notifications$$,$$values ('f1000000-0000-0000-0000-000000000003'::uuid,'shipment_delayed'::public.notification_type,'Shipment delayed'::text,'Shipment SHP-O1-A has been marked as delayed.'::text,'f5000000-0000-0000-0000-000000000001'::uuid,null::uuid,null::uuid,null::uuid,null::timestamptz)$$,'Mark notification is exact');
set local role authenticated; select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000001',true);
select results_eq(format('select mutation_result from public.set_shipment_delayed(%L,true,%L)','f5000000-0000-0000-0000-000000000001',(select updated_at from public.list_operations_shipments() where id='f5000000-0000-0000-0000-000000000001')),$$values ('noop'::text)$$,'True to true is a no-op');
select is((select count(*) from public.activity_logs where shipment_id='f5000000-0000-0000-0000-000000000001'),2::bigint,'Mark replay adds no activity');

select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000002',true);
select results_eq(format('select mutation_result,delayed from public.set_shipment_delayed(%L,false,%L)','f5000000-0000-0000-0000-000000000001',(select updated_at from public.list_operations_shipments() where id='f5000000-0000-0000-0000-000000000001')),$$values ('updated'::text,false)$$,'Dispatcher clears delay');
reset role;
select results_eq($$select alert_state,resolved_by_profile_id from public.alerts where shipment_id='f5000000-0000-0000-0000-000000000001'$$,$$values ('resolved'::public.alert_state,'f1000000-0000-0000-0000-000000000002'::uuid)$$,'Clear resolves alert with actor');
select is((select count(*) from public.activity_logs where action_type='alert_resolved' and shipment_id='f5000000-0000-0000-0000-000000000001'),1::bigint,'Clear records alert resolution');
select is((select count(*) from public.notifications),1::bigint,'Clear creates no notification');
set local role authenticated; select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000002',true);
select results_eq(format('select mutation_result from public.set_shipment_delayed(%L,false,%L)','f5000000-0000-0000-0000-000000000001',(select updated_at from public.list_operations_shipments() where id='f5000000-0000-0000-0000-000000000001')),$$values ('noop'::text)$$,'False to false is a no-op');
select throws_ok(format('select * from public.set_shipment_delayed(%L,true,%L)','f5000000-0000-0000-0000-000000000002',(select updated_at from public.list_operations_shipments() where id='f5000000-0000-0000-0000-000000000002')),'P0001','shipment_delay_status_invalid','Pending rejects delay mutation');
select throws_ok(format('select * from public.set_shipment_delayed(%L,true,%L)','f5000000-0000-0000-0000-000000000001','2000-01-01'),'40001','shipment_delay_stale','Stale version rejects');

select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000003',true);
select throws_ok($$select * from public.set_shipment_delayed('f5000000-0000-0000-0000-000000000001',true,now())$$,'42501','shipment_delay_access_denied','Driver denied');
select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000005',true);
select throws_ok($$select * from public.set_shipment_delayed('f5000000-0000-0000-0000-000000000001',true,now())$$,'42501','shipment_delay_access_denied','Inactive actor denied');
reset "request.jwt.claim.sub";
select throws_ok($$select * from public.set_shipment_delayed('f5000000-0000-0000-0000-000000000001',true,now())$$,'42501','shipment_delay_access_denied','Missing identity denied');
reset role; set local role anon;
select throws_ok($$select * from public.set_shipment_delayed('f5000000-0000-0000-0000-000000000001',true,now())$$,'42501',null,'Anonymous lacks execute');
reset role;

select function_privs_are('public','set_shipment_delayed',array['uuid','boolean','timestamp with time zone'], 'authenticated',array['EXECUTE'],'Authenticated function grant is exact');
select function_privs_are('public','set_shipment_delayed',array['uuid','boolean','timestamp with time zone'], 'anon',array[]::text[],'Anon has no function grant');
select is((select prosecdef from pg_proc where oid='public.set_shipment_delayed(uuid,boolean,timestamptz)'::regprocedure),true,'Function is security definer');
select is((select proconfig from pg_proc where oid='public.set_shipment_delayed(uuid,boolean,timestamptz)'::regprocedure),array['search_path=""']::text[],'Function search path is empty');

select * from finish();
rollback;
