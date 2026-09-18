begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
 ('19000000-0000-0000-0000-000000000001'),
 ('19000000-0000-0000-0000-000000000002'),
 ('19000000-0000-0000-0000-000000000003');
insert into public.profiles(id,full_name,username,role,is_active) values
 ('19000000-0000-0000-0000-000000000001','M2 Admin','m2-admin','admin',true),
 ('19000000-0000-0000-0000-000000000002','M2 Dispatcher','m2-dispatcher','dispatcher',true),
 ('19000000-0000-0000-0000-000000000003','M2 Driver','m2-driver','driver',true);
insert into public.vehicles(id,registration,make,model,vehicle_type,mileage,status) values
 ('49000000-0000-0000-0000-000000000001','M2-PRIMARY','M','P','Truck',1000,'available'),
 ('49000000-0000-0000-0000-000000000002','M2-LATEST','M','L','Truck',5000,'maintenance'),
 ('49000000-0000-0000-0000-000000000003','M2-SYSTEM','M','S','Truck',8000,'archived'),
 ('49000000-0000-0000-0000-000000000004','M2-NONE','M','N','Truck',0,'out_of_service');

set local role service_role;
select results_eq(
  $$select * from public.reconcile_vehicle_maintenance_alerts('49000000-0000-0000-0000-000000000004',null)$$,
  $$values (0,0,0)$$,
  'No maintenance record produces no lifecycle change');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000001',true);
select lives_ok(
  $$select public.create_maintenance_record('49000000-0000-0000-0000-000000000001','Threshold service',current_date,1000,null,null,null,current_date+14,2000)$$,
  'Admin creation atomically evaluates both inclusive thresholds');
reset role;

select results_eq(
  $$select alert_type,severity,message,alert_state,vehicle_id from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001' order by alert_type$$,
  $$values
    ('maintenance_due_date'::public.alert_type,'warning'::public.alert_severity,('Vehicle maintenance is due by '||(current_date+14)::text||'.')::text,'active'::public.alert_state,'49000000-0000-0000-0000-000000000001'::uuid),
    ('maintenance_due_mileage'::public.alert_type,'warning'::public.alert_severity,'Vehicle maintenance is due in 1000 km.'::text,'active'::public.alert_state,'49000000-0000-0000-0000-000000000001'::uuid)$$,
  'Exact boundaries create simultaneous Vehicle-primary warning alerts with exact copy');
select is((select count(*) from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001' and shipment_id is null and driver_id is null and document_id is null),2::bigint,'Maintenance alerts have zero unrelated entity references');
select results_eq(
  $$select action_type,actor_profile_id,metadata from public.activity_logs where vehicle_id='49000000-0000-0000-0000-000000000001' order by metadata->>'alert_type'$$,
  $$values
    ('alert_created'::public.activity_action_type,'19000000-0000-0000-0000-000000000001'::uuid,'{"alert_type":"maintenance_due_date"}'::jsonb),
    ('alert_created'::public.activity_action_type,'19000000-0000-0000-0000-000000000001'::uuid,'{"alert_type":"maintenance_due_mileage"}'::jsonb)$$,
  'Mutation-triggered creation records exact human-attributed activity');
select is((select count(*) from public.notifications),0::bigint,'Maintenance alert creation sends no notification');

set local role authenticated;
select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000001',true);
select results_eq(
  $$select public.update_vehicle_mileage('49000000-0000-0000-0000-000000000001',(select updated_at from public.get_operations_vehicle_for_edit('49000000-0000-0000-0000-000000000001')),2000)$$,
  $$values ('updated'::text)$$,
  'Mileage update reconciles at exact due mileage');
reset role;
select results_eq(
  $$select message from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001' and alert_type='maintenance_due_mileage' and alert_state='active'$$,
  $$values ('Vehicle maintenance is overdue by 0 km.'::text)$$,
  'Exact due mileage uses approved overdue-by-zero copy');
select is((select count(*) from public.activity_logs where vehicle_id='49000000-0000-0000-0000-000000000001' and action_type='alert_created'),2::bigint,'Message-only refresh creates no activity');

set local role authenticated;
select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000001',true);
select lives_ok($m$
  select public.update_maintenance_record(
    (select id from public.list_operations_maintenance('', '49000000-0000-0000-0000-000000000001')),
    (select updated_at from public.get_operations_maintenance_for_edit((select id from public.list_operations_maintenance('', '49000000-0000-0000-0000-000000000001')))),
    'Threshold service',current_date,1000,null,null,null,current_date+30,4001)
$m$,'Moving both next-service values outside thresholds resolves both alerts atomically');
reset role;
select is((select count(*) from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001' and alert_state='active'),0::bigint,'Cleared conditions leave no active alert');
select is((select count(*) from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001' and alert_state='resolved' and resolved_by_profile_id='19000000-0000-0000-0000-000000000001'),2::bigint,'Human-triggered resolutions retain human resolver');
select is((select count(*) from public.activity_logs where vehicle_id='49000000-0000-0000-0000-000000000001' and action_type='alert_resolved'),2::bigint,'Each resolution emits exactly one activity');

set local role authenticated;
select set_config('request.jwt.claim.sub','19000000-0000-0000-0000-000000000001',true);
select lives_ok($m$
  select public.update_maintenance_record(
    (select id from public.list_operations_maintenance('', '49000000-0000-0000-0000-000000000001')),
    (select updated_at from public.get_operations_maintenance_for_edit((select id from public.list_operations_maintenance('', '49000000-0000-0000-0000-000000000001')))),
    'Threshold service',current_date-1,1000,null,null,null,current_date,2000)
$m$,'A later recurrence creates new active alerts');
reset role;
select is((select count(*) from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001'),4::bigint,'Resolved alerts are retained and recurrence creates new rows');
select results_eq(
  $$select alert_type,message from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000001' and alert_state='active' order by alert_type$$,
  $$values
    ('maintenance_due_date'::public.alert_type,('Vehicle maintenance is overdue since '||current_date::text||'.')::text),
    ('maintenance_due_mileage'::public.alert_type,'Vehicle maintenance is overdue by 0 km.'::text)$$,
  'Due date and mileage use exact overdue copy');

insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service,next_service_date,next_service_mileage,created_at) values
 ('59000000-0000-0000-0000-000000000001','49000000-0000-0000-0000-000000000002','Older both',current_date-20,4000,current_date+5,9000,now()-interval '3 days'),
 ('59000000-0000-0000-0000-000000000002','49000000-0000-0000-0000-000000000002','Newer date',current_date-10,4500,current_date+30,null,now()-interval '2 days'),
 ('59000000-0000-0000-0000-000000000003','49000000-0000-0000-0000-000000000002','Newest mileage',current_date-5,4800,null,5500,now()-interval '1 day');
set local role service_role;
select results_eq(
  $$select * from public.reconcile_vehicle_maintenance_alerts('49000000-0000-0000-0000-000000000002',null)$$,
  $$values (1,0,0)$$,
  'Latest eligible record is selected independently per dimension');
reset role;
select results_eq(
  $$select alert_type,message from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000002'$$,
  $$values ('maintenance_due_mileage'::public.alert_type,'Vehicle maintenance is due in 500 km.'::text)$$,
  'A newer null field does not supersede the latest eligible dimension record');

insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service,next_service_date,next_service_mileage)
values ('59000000-0000-0000-0000-000000000004','49000000-0000-0000-0000-000000000003','System due',current_date-1,8000,current_date+1,8500);
set local role service_role;
select lives_ok($$select * from public.reconcile_vehicle_maintenance_alerts('49000000-0000-0000-0000-000000000003',null)$$,'Scheduled reconciliation supports archived Vehicles');
reset role;
select is((select count(*) from public.alerts where vehicle_id='49000000-0000-0000-0000-000000000003' and alert_state='active'),2::bigint,'Vehicle status does not suppress maintenance evaluation');
select is((select count(*) from public.activity_logs where vehicle_id='49000000-0000-0000-0000-000000000003' and actor_profile_id is null and action_type='alert_created'),2::bigint,'Scheduled lifecycle activity is System-attributed');

select ok(not has_function_privilege('authenticated','public.reconcile_vehicle_maintenance_alerts(uuid,uuid)','EXECUTE'),'Authenticated cannot execute internal reconciler');
select ok(not has_function_privilege('anon','public.list_maintenance_alert_vehicle_ids(uuid)','EXECUTE'),'Anonymous cannot list scheduled Vehicle IDs');
select ok(has_function_privilege('service_role','public.reconcile_vehicle_maintenance_alerts(uuid,uuid)','EXECUTE'),'Service role can execute scheduler reconciler');
select is((select proconfig from pg_proc where oid='public.reconcile_vehicle_maintenance_alerts(uuid,uuid)'::regprocedure),array['search_path=""']::text[],'Reconciler has fixed empty search path');
select is((select count(*) from public.notifications),0::bigint,'All maintenance reconciliation remains notification-free');
select results_eq($$select status from public.vehicles where id='49000000-0000-0000-0000-000000000003'$$,$$values ('archived'::public.vehicle_status)$$,'Reconciliation never changes Vehicle status');
select is((select count(*) from public.shipments),0::bigint,'Reconciliation creates no Shipment');
select is((select count(*) from public.expenses),0::bigint,'Reconciliation creates no Expense');
select is((select count(*) from public.vehicle_locations),0::bigint,'Reconciliation creates no tracking state');
select is((select count(*) from pg_catalog.pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename<>'vehicle_locations'),0::bigint,'No additional Realtime publication exists');

select * from finish();
rollback;
