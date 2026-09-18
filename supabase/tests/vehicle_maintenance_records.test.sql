begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id) values
 ('17000000-0000-0000-0000-000000000001'), ('17000000-0000-0000-0000-000000000002'),
 ('17000000-0000-0000-0000-000000000003'), ('17000000-0000-0000-0000-000000000004'),
 ('17000000-0000-0000-0000-000000000005');
insert into public.profiles (id,full_name,username,role,is_active) values
 ('17000000-0000-0000-0000-000000000001','Maintenance Admin','m1-admin','admin',true),
 ('17000000-0000-0000-0000-000000000002','Maintenance Dispatcher','m1-dispatcher','dispatcher',true),
 ('17000000-0000-0000-0000-000000000003','Maintenance Driver','m1-driver','driver',true),
 ('17000000-0000-0000-0000-000000000004','Inactive Admin','m1-inactive','admin',false);
insert into public.drivers (id,profile_id,status) values ('27000000-0000-0000-0000-000000000003','17000000-0000-0000-0000-000000000003','available');
insert into public.vehicles (id,registration,make,model,vehicle_type,mileage,status) values
 ('47000000-0000-0000-0000-000000000001','M1-AVAILABLE','M','A','Truck',1000,'available'),
 ('47000000-0000-0000-0000-000000000002','M1-IN-USE','M','I','Truck',2000,'in_use'),
 ('47000000-0000-0000-0000-000000000003','M1-MAINT','M','M','Truck',3000,'maintenance'),
 ('47000000-0000-0000-0000-000000000004','M1-OOS','M','O','Truck',4000,'out_of_service'),
 ('47000000-0000-0000-0000-000000000005','M1-ARCHIVED','M','R','Truck',5000,'archived');
insert into public.maintenance_records (id,vehicle_id,service_type,service_date,mileage_at_service,workshop,cost,notes,next_service_date,next_service_mileage)
values ('57000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000005','Baseline',current_date-10,5000,'Old Shop',50,'Old notes',current_date+10,5500);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);

select lives_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','  Oil service  ',current_date,1200,'  Main Shop  ',125.50,'  Checked  ',current_date+30,2000)$$,'Admin creates normalized maintenance');
reset role;
select results_eq($$select service_type,workshop,cost,notes from public.maintenance_records where vehicle_id='47000000-0000-0000-0000-000000000001'$$,$$values ('Oil service'::text,'Main Shop'::text,125.50::numeric,'Checked'::text)$$,'Create persists normalized values');
select results_eq($$select mileage,status from public.vehicles where id='47000000-0000-0000-0000-000000000001'$$,$$values (1200,'available'::public.vehicle_status)$$,'Create raises mileage without status change');
select results_eq($$select action_type,metadata from public.activity_logs where maintenance_record_id is not null$$,$$values ('maintenance_record_created'::public.activity_action_type,'{"vehicle_mileage_updated":true}'::jsonb)$$,'Create activity is exact');
select results_eq(
  $$select alert_type,severity,message,vehicle_id from public.alerts$$,
  $$values ('maintenance_due_mileage'::public.alert_type,'warning'::public.alert_severity,'Vehicle maintenance is due in 800 km.'::text,'47000000-0000-0000-0000-000000000001'::uuid)$$,
  'Create produces the M2-authorized mileage alert');
select is((select count(*) from public.notifications),0::bigint,'Create produces no notification');
select is((select count(*) from public.expenses),0::bigint,'Create produces no expense');

set local role authenticated;
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000002','Equal',current_date,2000)$$,'Equal mileage is accepted');
select lives_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000003','Historical',current_date,2900)$$,'Lower historical mileage is accepted');
select lives_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000004','All status OOS',current_date,4000); select public.create_maintenance_record('47000000-0000-0000-0000-000000000005','All status archived',current_date,5000)$$,'Out-of-service and archived Vehicles are accepted');
select throws_ok($$select public.create_maintenance_record(gen_random_uuid(),'Missing',current_date,0)$$,'P0001','maintenance_vehicle_not_found','Missing Vehicle rejected');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','Future',current_date+1,1200)$$,'P0001','maintenance_validation_failed','Future service date rejected');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001',' ',current_date,0)$$,'P0001','maintenance_validation_failed','Blank service type rejected');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','Bad next date',current_date,0,null,null,null,current_date,1)$$,'P0001','maintenance_validation_failed','Next date must be later');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','Bad next mileage',current_date,10,null,null,null,null,10)$$,'P0001','maintenance_validation_failed','Next mileage must be greater');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','Bad cost',current_date,10,null,-1)$$,'P0001','maintenance_validation_failed','Negative cost rejected');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','Cost precision',current_date,10,null,1.234)$$,'P0001','maintenance_validation_failed','Cost precision rejected');

select results_eq($$select vehicle_registration from public.list_operations_maintenance('oil','47000000-0000-0000-0000-000000000001',current_date,current_date,1)$$,$$values ('M1-AVAILABLE'::text)$$,'Combined list filters work');
select results_eq($$select vehicle_registration from public.list_operations_maintenance('main shop',null,null,null,1)$$,$$values ('M1-AVAILABLE'::text)$$,'Workshop search is case-insensitive');
select throws_ok($$select * from public.list_operations_maintenance('',null,current_date,current_date-1,1)$$,'P0001','maintenance_list_invalid','Invalid date range rejected');
select throws_ok($$select * from public.list_operations_maintenance('',null,null,null,0)$$,'P0001','maintenance_list_invalid','Invalid page rejected');

select results_eq($$select public.update_maintenance_record('57000000-0000-0000-0000-000000000001',(select updated_at from public.get_operations_maintenance_for_edit('57000000-0000-0000-0000-000000000001')),' Baseline ',current_date-10,5000,' Old Shop ',50,' Old notes ',current_date+10,5500)$$,$$values ('noop'::text)$$,'Normalized edit is no-op');
select throws_ok($$select public.update_maintenance_record('57000000-0000-0000-0000-000000000001','2000-01-01','Baseline',current_date-10,5000,'Old Shop',50,'Old notes',current_date+10,5500)$$,'P0001','maintenance_record_stale','Stale check precedes no-op');
select results_eq($$select public.update_maintenance_record('57000000-0000-0000-0000-000000000001',(select updated_at from public.get_operations_maintenance_for_edit('57000000-0000-0000-0000-000000000001')),'Major service',current_date-10,5600,'Old Shop',50,'Old notes',current_date+10,5700)$$,$$values ('updated'::text)$$,'Real edit succeeds');
reset role;
select results_eq($$select metadata from public.activity_logs where action_type='maintenance_record_updated'$$,$$values ('{"changed_fields":["service_type","mileage_at_service","next_service_mileage"],"vehicle_mileage_updated":true}'::jsonb)$$,'Edit metadata order and mileage flag are exact');
select is((select count(*) from public.activity_logs where vehicle_id='47000000-0000-0000-0000-000000000005' and action_type in ('vehicle_created','vehicle_updated','vehicle_status_changed','vehicle_archived')),0::bigint,'No separate Vehicle master-data activity created');
select is((select count(*) from public.activity_logs where vehicle_id='47000000-0000-0000-0000-000000000005' and action_type='alert_created'),2::bigint,'M2-authorized Vehicle alert lifecycle activity is recorded');

set local role authenticated;
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000002',true);
select ok((select count(*) from public.list_operations_maintenance())>0,'Dispatcher reads maintenance');
select throws_ok($$select public.create_maintenance_record('47000000-0000-0000-0000-000000000001','Denied',current_date,1)$$,'P0001','maintenance_mutation_access_denied','Dispatcher create denied');
select throws_ok($$select public.get_operations_maintenance_for_edit('57000000-0000-0000-0000-000000000001')$$,'P0001','maintenance_read_access_denied','Dispatcher edit read denied');
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000003',true);
select throws_ok($$select * from public.list_operations_maintenance()$$,'P0001','maintenance_read_access_denied','Driver read denied');
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000004',true);
select throws_ok($$select * from public.list_operations_maintenance()$$,'P0001','maintenance_read_access_denied','Inactive read denied');
select set_config('request.jwt.claim.sub','17000000-0000-0000-0000-000000000005',true);
select throws_ok($$select * from public.list_operations_maintenance()$$,'P0001','maintenance_read_access_denied','Missing profile denied');
select throws_ok($$select * from public.maintenance_records$$,'42501',null,'Direct authenticated SELECT denied');
select throws_ok($$insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service) values(gen_random_uuid(),'47000000-0000-0000-0000-000000000001','Direct',current_date,1)$$,'42501',null,'Direct INSERT denied');
select throws_ok($$update public.maintenance_records set notes='Direct'$$,'42501',null,'Direct UPDATE denied');
select throws_ok($$delete from public.maintenance_records$$,'42501',null,'Direct DELETE denied');

reset role; set local role anon;
select throws_ok($$select * from public.list_operations_maintenance()$$,'42501',null,'Anonymous read denied');
reset role;
select is((select prosecdef from pg_proc where oid='public.create_maintenance_record(uuid,text,date,integer,text,numeric,text,date,integer)'::regprocedure),true,'Create is SECURITY DEFINER');
select is((select proconfig from pg_proc where oid='public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure),array['search_path=""']::text[],'Update has empty search path');
select ok(has_function_privilege('authenticated','public.create_maintenance_record(uuid,text,date,integer,text,numeric,text,date,integer)','EXECUTE'),'Authenticated has create execute');
select ok(not has_function_privilege('anon','public.create_maintenance_record(uuid,text,date,integer,text,numeric,text,date,integer)','EXECUTE'),'Anon lacks create execute');
select * from finish(); rollback;
