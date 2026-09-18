begin;
create extension if not exists pgtap with schema extensions;
select plan(57);
insert into auth.users(id) values ('71000000-0000-0000-0000-000000000001'),('71000000-0000-0000-0000-000000000002'),('71000000-0000-0000-0000-000000000003'),('71000000-0000-0000-0000-000000000004'),('71000000-0000-0000-0000-000000000005');
insert into public.profiles(id,full_name,username,role,is_active) values
('71000000-0000-0000-0000-000000000001','S1 Admin','s1-admin','admin',true),
('71000000-0000-0000-0000-000000000002','S1 Dispatcher','s1-dispatch','dispatcher',true),
('71000000-0000-0000-0000-000000000003','S1 Driver','s1-driver','driver',true),
('71000000-0000-0000-0000-000000000004','Inactive','s1-inactive','dispatcher',false),
('71000000-0000-0000-0000-000000000005','S1 Driver Two','s1-driver-two','driver',true);
insert into public.drivers(id,profile_id,status) values
('72000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000003','available'),
('72000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000005','available');
insert into public.clients(id,company_name,status) values('73000000-0000-0000-0000-000000000001','S1 Active','active'),('73000000-0000-0000-0000-000000000002','S1 Archived','archived');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
('74000000-0000-0000-0000-000000000001','S1-REG','Make','Model','Truck','available'),
('74000000-0000-0000-0000-000000000002','S1-REG-2','Make','Model','Truck','available');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price)
values(gen_random_uuid(),'SHP-'||(to_char(current_timestamp at time zone 'UTC','YYYY')::integer-1)::text||'-9999','73000000-0000-0000-0000-000000000002','Prior year','History',now(),now(),'Cargo',1);
set local role authenticated; select set_config('request.jwt.claim.role','authenticated',true); select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select has_function('public','create_pending_shipment',array['uuid','text','text','timestamp with time zone','timestamp with time zone','text','numeric'],'Creation function exists');
select has_function('public','assign_pending_shipment',array['uuid','uuid','uuid'],'Assignment function exists');
select lives_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','A','B','2026-09-02T08:00Z','2026-09-02T09:00Z','Cargo',100)$$,'Admin creates pending Shipment');
reset role;
select id as created_shipment_id from public.shipments where client_id='73000000-0000-0000-0000-000000000001' \gset
select is((select count(*) from public.shipments where client_id='73000000-0000-0000-0000-000000000001'),1::bigint,'One Shipment created');
select ok((select status='pending' and not delayed and driver_id is null and vehicle_id is null from public.shipments where client_id='73000000-0000-0000-0000-000000000001'),'Creation defaults exact');
select matches((select tracking_number from public.shipments where client_id='73000000-0000-0000-0000-000000000001'),'^SHP-[0-9]{4}-[0-9]{3,}$','Tracking format exact');
select is((select tracking_number from public.shipments where pickup_address='A'),'SHP-'||to_char(current_timestamp at time zone 'UTC','YYYY')||'-001','Tracking sequence resets for the UTC year');
select is((select metadata from public.activity_logs where action_type='shipment_created' and shipment_id=(select id from public.shipments where client_id='73000000-0000-0000-0000-000000000001')),'{"status":"pending"}'::jsonb,'Creation activity exact');
set local role authenticated;
select throws_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000002','A','B',now(),now(),'Cargo',1)$$,'P0002','shipment_client_unavailable','Archived Client rejected');
reset role;
select is((select count(*) from public.activity_logs where action_type='shipment_created'),1::bigint,'Rejected creation has zero activity');
set local role authenticated;
select lives_ok(format('select * from public.assign_pending_shipment(%L,%L,%L)',:'created_shipment_id','72000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001'),'Admin assigns pending Shipment');
reset role;
select is((select status from public.drivers where id='72000000-0000-0000-0000-000000000001'),'assigned'::public.driver_status,'Driver synchronized');
select is((select status from public.vehicles where id='74000000-0000-0000-0000-000000000001'),'in_use'::public.vehicle_status,'Vehicle synchronized');
select is((select metadata from public.activity_logs where action_type='shipment_assigned'),'{"driver_status":"assigned","vehicle_status":"in_use"}'::jsonb,'Assignment activity exact');
select results_eq($$select title,message from public.notifications where notification_type='shipment_assigned'$$,format($$select 'New shipment assigned'::text,('Shipment '||(select tracking_number from public.shipments where id=%L)||' has been assigned to you.')::text$$,:'created_shipment_id'),'Assignment notification exact');
select ok((select recipient_profile_id='71000000-0000-0000-0000-000000000003' and shipment_id=:'created_shipment_id' from public.notifications where notification_type='shipment_assigned'),'Assignment notification targets the assigned Driver profile and Shipment');
select ok((select actor_profile_id='71000000-0000-0000-0000-000000000001' and shipment_id=:'created_shipment_id' and num_nonnulls(vehicle_id,driver_id,client_id,document_id,status_request_id,maintenance_record_id,expense_id)=0 from public.activity_logs where action_type='shipment_assigned'),'Assignment activity has the authenticated actor and Shipment as sole primary entity');
select is((select status from public.clients where id='73000000-0000-0000-0000-000000000001'),'active'::public.client_status,'Assignment does not mutate Client lifecycle');
set local role authenticated;
select throws_ok(format('select * from public.assign_pending_shipment(%L,%L,%L)',:'created_shipment_id','72000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001'),'P0002','shipment_driver_unavailable','Replay rejected');
reset role;
select is((select count(*) from public.activity_logs where action_type='shipment_assigned'),1::bigint,'Replay creates zero activity');
set local role authenticated;
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000003',true);
select throws_ok($$select * from public.list_operations_shipments()$$,'42501','shipment_read_access_denied','Driver Operations read denied');
select throws_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1)$$,'42501','shipment_mutation_access_denied','Driver creation denied');
select throws_ok(format('select * from public.assign_pending_shipment(%L,%L,%L)',:'created_shipment_id','72000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001'),'42501','shipment_mutation_access_denied','Driver assignment denied');
select is_empty($$select * from public.list_active_shipment_clients()$$,'Driver receives no Client candidates');
select is_empty($$select * from public.list_eligible_shipment_drivers()$$,'Driver receives no Driver candidates');
select is_empty($$select * from public.list_eligible_shipment_vehicles()$$,'Driver receives no Vehicle candidates');

reset role;
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price,created_at)
select gen_random_uuid(),'LIST-'||lpad(value::text,2,'0'),'73000000-0000-0000-0000-000000000001','List pickup '||value,'List delivery',now(),now(),'Cargo',1,current_timestamp-(value||' days')::interval from generate_series(1,11) value;
set local role authenticated; select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select lives_ok($$select * from public.list_operations_shipments()$$,'Admin lists Shipments');
select is((select count(*) from public.list_operations_shipments()),10::bigint,'Shipment list page size is 10');
select is((select count(*) from public.list_operations_shipments('','all','all',2)),3::bigint,'Shipment list returns the normalized second page');
select is((select count(*) from public.list_operations_shipments('LIST-11','all','all',1)),1::bigint,'Shipment list searches tracking number case-insensitively');
select is((select count(*) from public.list_operations_shipments('s1 active','all','all',1)),10::bigint,'Shipment list searches Client company case-insensitively with bounded output');
select is((select count(*) from public.list_operations_shipments('','assigned','all',1)),1::bigint,'Shipment list applies status filter');
select is_empty($$select * from public.list_operations_shipments('','all','delayed',1)$$,'Shipment list applies delayed filter');
select is((select count(*) from public.list_active_shipment_clients()),1::bigint,'Admin receives only active Client candidates');
select is((select count(*) from public.list_eligible_shipment_drivers()),1::bigint,'Admin receives only currently eligible Drivers');
select is((select count(*) from public.list_eligible_shipment_vehicles()),1::bigint,'Admin receives only currently eligible Vehicles');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select lives_ok($$select * from public.list_operations_shipments()$$,'Dispatcher lists Shipments');
select lives_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','Dispatcher pickup','Dispatcher delivery',now(),now(),'Cargo',25)$$,'Dispatcher creates pending Shipment');
reset role;
select id as dispatcher_shipment_id from public.shipments where pickup_address='Dispatcher pickup' \gset
set local role authenticated; select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000002',true);
select lives_ok(format('select * from public.assign_pending_shipment(%L,%L,%L)',:'dispatcher_shipment_id','72000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000002'),'Dispatcher assigns pending Shipment');
reset role;
select ok((select s.status='assigned' and d.status='assigned' and v.status='in_use' from public.shipments s join public.drivers d on d.id=s.driver_id join public.vehicles v on v.id=s.vehicle_id where s.id=:'dispatcher_shipment_id'),'Dispatcher assignment synchronizes all entities');

set local role authenticated; select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000004',true);
select throws_ok($$select * from public.list_operations_shipments()$$,'42501','shipment_read_access_denied','Inactive profile read denied');
select throws_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1)$$,'42501','shipment_mutation_access_denied','Inactive profile creation denied');
select throws_ok(format('select * from public.assign_pending_shipment(%L,%L,%L)',:'created_shipment_id','72000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000001'),'42501','shipment_mutation_access_denied','Inactive profile assignment denied');
select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000099',true);
select throws_ok($$select * from public.list_operations_shipments()$$,'42501','shipment_read_access_denied','Missing profile read denied');
select throws_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1)$$,'42501','shipment_mutation_access_denied','Missing profile creation denied');
reset role; set local role anon;
select throws_ok($$select * from public.list_operations_shipments()$$,'42501',null,'Anonymous execution denied');
select throws_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1)$$,'42501',null,'Anonymous creation execution denied');
reset role; set local role authenticated; select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select throws_ok($$insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price) values(gen_random_uuid(),'BYPASS','73000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1)$$,'42501',null,'Direct Shipment insert bypass denied');
select throws_ok(format('update public.shipments set status=''cancelled'' where id=%L',:'dispatcher_shipment_id'),'42501',null,'Direct Shipment update bypass denied');
reset role;
select ok((select bool_and(prosecdef) from pg_proc where oid in ('public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric)'::regprocedure,'public.assign_pending_shipment(uuid,uuid,uuid)'::regprocedure,'public.list_operations_shipments(text,text,text,integer)'::regprocedure,'public.list_active_shipment_clients()'::regprocedure,'public.list_eligible_shipment_drivers()'::regprocedure,'public.list_eligible_shipment_vehicles()'::regprocedure)),'All S1 functions are SECURITY DEFINER');
select ok((select bool_and('search_path=""'=any(proconfig)) from pg_proc where oid in ('public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric)'::regprocedure,'public.assign_pending_shipment(uuid,uuid,uuid)'::regprocedure,'public.list_operations_shipments(text,text,text,integer)'::regprocedure,'public.list_active_shipment_clients()'::regprocedure,'public.list_eligible_shipment_drivers()'::regprocedure,'public.list_eligible_shipment_vehicles()'::regprocedure)),'All S1 functions use fixed empty search_path');
select ok(has_function_privilege('authenticated','public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric)','execute'),'Authenticated role has creation execute grant');
select ok(not has_function_privilege('anon','public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric)','execute'),'Anonymous role lacks creation execute grant');
select ok(not exists(select 1 from aclexplode((select proacl from pg_proc where oid='public.create_pending_shipment(uuid,text,text,timestamptz,timestamptz,text,numeric)'::regprocedure)) where grantee=0 and privilege_type='EXECUTE'),'PUBLIC lacks creation execute grant');

insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price)
values(gen_random_uuid(),'SHP-'||to_char(current_timestamp at time zone 'UTC','YYYY')||'-999','73000000-0000-0000-0000-000000000001','Allocator','Test',now(),now(),'Cargo',1);
set local role authenticated; select set_config('request.jwt.claim.sub','71000000-0000-0000-0000-000000000001',true);
select lives_ok($$select * from public.create_pending_shipment('73000000-0000-0000-0000-000000000001','After 999','B',now(),now(),'Cargo',1)$$,'Allocator continues above 999');
reset role;
select is((select tracking_number from public.shipments where pickup_address='After 999'),'SHP-'||to_char(current_timestamp at time zone 'UTC','YYYY')||'-1000','Minimum width expands naturally above 999');
select ok((select tracking_number like 'SHP-'||to_char(current_timestamp at time zone 'UTC','YYYY')||'-%' from public.shipments where pickup_address='After 999'),'Allocator uses database UTC year');
select * from finish(); rollback;
