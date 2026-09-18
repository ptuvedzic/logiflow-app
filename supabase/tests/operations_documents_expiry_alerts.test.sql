begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
 ('d1000000-0000-0000-0000-000000000001'),('d1000000-0000-0000-0000-000000000002'),
 ('d1000000-0000-0000-0000-000000000003'),('d1000000-0000-0000-0000-000000000004');
insert into public.profiles(id,full_name,username,role,is_active) values
 ('d1000000-0000-0000-0000-000000000001','D1 Admin','d1-admin','admin',true),
 ('d1000000-0000-0000-0000-000000000002','D1 Dispatcher','d1-dispatcher','dispatcher',true),
 ('d1000000-0000-0000-0000-000000000003','D1 Driver','d1-driver','driver',true),
 ('d1000000-0000-0000-0000-000000000004','D1 Inactive','d1-inactive','admin',false);
insert into public.drivers(id,profile_id,status) values ('d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003','assigned');
insert into public.clients(id,company_name) values ('d3000000-0000-0000-0000-000000000001','D1 Client');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
 ('d4000000-0000-0000-0000-000000000001','D1-ACTIVE','D','One','Truck','in_use'),
 ('d4000000-0000-0000-0000-000000000002','D1-ARCHIVED','D','Two','Truck','archived');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
 ('d5000000-0000-0000-0000-000000000001','SHP-D1','d3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','d2000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001',100,'assigned');

select throws_ok($$insert into public.documents(id,vehicle_id,uploader_profile_id,document_type,file_path,file_name) values(gen_random_uuid(),'d4000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','made_up','vehicle/x/y/z.pdf','z.pdf')$$,'23514',null,'Unknown Vehicle document type is rejected');
select lives_ok($$insert into public.documents(id,vehicle_id,uploader_profile_id,document_type,file_path,file_name,valid_until) values('d6000000-0000-0000-0000-000000000001','d4000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','insurance','vehicle/d4/d6/insurance.pdf','insurance.pdf',current_date+30)$$,'Canonical Vehicle type and exact threshold are accepted');
select lives_ok($$insert into public.documents(id,driver_id,uploader_profile_id,document_type,file_path,file_name,valid_until) values('d6000000-0000-0000-0000-000000000002','d2000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000001','driving_license','driver/d2/d6/license.pdf','license.pdf',current_date)$$,'Canonical Driver type and due today are accepted');
select lives_ok($$insert into public.documents(id,shipment_id,uploader_profile_id,document_type,file_path,file_name) values('d6000000-0000-0000-0000-000000000003','d5000000-0000-0000-0000-000000000001','d1000000-0000-0000-0000-000000000003','proof_of_delivery','shipment/d5/d6/pod.pdf','pod.pdf')$$,'Canonical Shipment POD is accepted');

set local role service_role;
select lives_ok($$select * from public.reconcile_document_expiry_alerts('d6000000-0000-0000-0000-000000000001',null)$$,'Scheduled reconciliation creates exact threshold alert');
select lives_ok($$select * from public.reconcile_document_expiry_alerts('d6000000-0000-0000-0000-000000000002',null)$$,'Due today is expiring');
reset role;
select results_eq($$select alert_type,severity,message from public.alerts where document_id='d6000000-0000-0000-0000-000000000001'$$,$$values('document_expiring'::public.alert_type,'warning'::public.alert_severity,('insurance.pdf expires on '||(current_date+30)::text||'.')::text)$$,'Expiring alert has exact type severity and ISO copy');
select is((select count(*) from public.notifications where document_id='d6000000-0000-0000-0000-000000000001' and notification_type='vehicle_document_expiring'),2::bigint,'Vehicle expiry notifies every active Operations profile once');
select results_eq($$select title,message from public.notifications where document_id='d6000000-0000-0000-0000-000000000002'$$,$$values('Driver document expiring'::text,('license.pdf expires on '||current_date::text||'.')::text)$$,'Driver expiry notifies its active profile with exact copy');
select is((select count(*) from public.notifications where document_id='d6000000-0000-0000-0000-000000000003'),0::bigint,'Shipment-owned document creates zero expiry notifications');
select is((select count(*) from public.activity_logs where document_id in('d6000000-0000-0000-0000-000000000001','d6000000-0000-0000-0000-000000000002') and action_type='alert_created' and actor_profile_id is null),2::bigint,'Scheduled alert activity uses System actor');

set local role authenticated;select set_config('request.jwt.claim.role','authenticated',true);select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.update_document_metadata('d6000000-0000-0000-0000-000000000001',(select listed.updated_at from public.list_operations_documents('insurance',null,null,'all',null,1) listed where listed.id='d6000000-0000-0000-0000-000000000001'),'insurance',null,current_date-1)$$,'Admin correction atomically moves document to expired');
reset role;
select is((select count(*) from public.alerts where document_id='d6000000-0000-0000-0000-000000000001' and alert_state='active'),1::bigint,'Only one active expiry condition remains');
select is((select count(*) from public.alerts where document_id='d6000000-0000-0000-0000-000000000001' and alert_type='document_expiring' and alert_state='resolved'),1::bigint,'Expiring alert is resolved');
select results_eq($$select alert_type,severity,message from public.alerts where document_id='d6000000-0000-0000-0000-000000000001' and alert_state='active'$$,$$values('document_expired'::public.alert_type,'critical'::public.alert_severity,('insurance.pdf expired on '||(current_date-1)::text||'.')::text)$$,'Expired recurrence creates a critical alert with exact copy');
select is((select count(*) from public.notifications where document_id='d6000000-0000-0000-0000-000000000001'),4::bigint,'Condition entry notifies once per active Operations recipient');

set local role authenticated;select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.update_document_metadata('d6000000-0000-0000-0000-000000000001',(select listed.updated_at from public.list_operations_documents('insurance',null,null,'all',null,1) listed where listed.id='d6000000-0000-0000-0000-000000000001'),'insurance',null,current_date)$$,'42501','document_mutation_access_denied','Dispatcher cannot edit metadata');
select lives_ok($$select public.set_document_lifecycle('d6000000-0000-0000-0000-000000000001',(select listed.updated_at from public.list_operations_documents('insurance',null,null,'all',null,1) listed where listed.id='d6000000-0000-0000-0000-000000000001'),'archived')$$,'Dispatcher archives');
select throws_ok($$delete from public.documents where id='d6000000-0000-0000-0000-000000000001'$$,'42501',null,'Authenticated hard delete is denied');
reset role;
select is((select count(*) from public.activity_logs where document_id='d6000000-0000-0000-0000-000000000001' and action_type='document_archived'),1::bigint,'Archive creates one document activity');
select is((select count(*) from public.alerts where document_id='d6000000-0000-0000-0000-000000000001' and alert_state='active'),0::bigint,'Archive resolves active expiry alert');

set local role authenticated;select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.set_document_lifecycle('d6000000-0000-0000-0000-000000000001',(select listed.updated_at from public.list_operations_documents('insurance',null,null,'all',null,1) listed where listed.id='d6000000-0000-0000-0000-000000000001'),'active')$$,'Admin restores');
select throws_ok($$select public.update_document_metadata('d6000000-0000-0000-0000-000000000001','2000-01-01'::timestamptz,'insurance',null,current_date-1)$$,'P0001','document_stale','Optimistic conflict is rejected before no-op');
reset role;
select is((select count(*) from public.activity_logs where document_id='d6000000-0000-0000-0000-000000000001' and action_type='document_restored'),1::bigint,'Restore creates exact new activity');
select is((select count(*) from public.alerts where document_id='d6000000-0000-0000-0000-000000000001' and alert_state='active'),1::bigint,'Restore immediately recreates expiry condition');

set local role authenticated;select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000003',true);
select ok(public.authorize_document_upload_intent('shipment','d5000000-0000-0000-0000-000000000001','proof_of_delivery'),'Assigned Driver may request exact POD intent');
select is(public.authorize_document_upload_intent('vehicle','d4000000-0000-0000-0000-000000000001','insurance'),false,'Driver cannot request general upload');
reset role;

insert into storage.objects(bucket_id,name,owner_id,metadata) values
 ('documents','shipment/d5/d6/pod.pdf','d1000000-0000-0000-0000-000000000003','{"size":100,"mimetype":"application/pdf"}'),
 ('documents','shipment/d5000000-0000-0000-0000-000000000001/d6000000-0000-0000-0000-000000000004/new-pod.pdf','d1000000-0000-0000-0000-000000000003','{"size":100,"mimetype":"application/pdf"}');
set local role authenticated;select set_config('request.jwt.claim.sub','d1000000-0000-0000-0000-000000000003',true);
select lives_ok($$select public.complete_document_upload('d6000000-0000-0000-0000-000000000004','shipment','d5000000-0000-0000-0000-000000000001','proof_of_delivery','shipment/d5000000-0000-0000-0000-000000000001/d6000000-0000-0000-0000-000000000004/new-pod.pdf','new-pod.pdf')$$,'Driver completes staged POD upload');
reset role;
select is((select lifecycle_status from public.documents where id='d6000000-0000-0000-0000-000000000003'),'archived'::public.document_lifecycle_status,'New POD archives previous active POD metadata');
select is((select lifecycle_status from public.documents where id='d6000000-0000-0000-0000-000000000004'),'active'::public.document_lifecycle_status,'New POD becomes active');
select ok(exists(select 1 from storage.objects where name like '%/pod.pdf') and exists(select 1 from storage.objects where name like '%/new-pod.pdf'),'POD replacement retains Storage objects');
select is((select count(*) from public.activity_logs where document_id='d6000000-0000-0000-0000-000000000004' and action_type='document_uploaded'),1::bigint,'Upload creates one attributed activity');

select results_eq($$select schedule from cron.job where jobname='logiflow-reconcile-documents-daily-0200-utc'$$,$$values('0 2 * * *'::text)$$,'Document reconciliation is locked to 02:00 UTC Cron');
select results_eq($$select schedule from cron.job where jobname='logiflow-document-upload-cleanup-hourly'$$,$$values('0 * * * *'::text)$$,'Abandoned cleanup is hourly');
select is((select count(*) from pg_publication_tables where pubname='supabase_realtime' and tablename in('documents','alerts','notifications')),0::bigint,'Realtime excludes Documents Alerts and Notifications');

select * from finish();
rollback;
