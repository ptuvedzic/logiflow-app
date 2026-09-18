begin;

create extension if not exists pgtap with schema extensions;
select plan(64);

insert into auth.users (id) values
  ('91000000-0000-0000-0000-000000000001'),
  ('91000000-0000-0000-0000-000000000002'),
  ('91000000-0000-0000-0000-000000000003'),
  ('91000000-0000-0000-0000-000000000004'),
  ('91000000-0000-0000-0000-000000000005'),
  ('91000000-0000-0000-0000-000000000006');

insert into public.profiles (id,full_name,username,role,is_active) values
  ('91000000-0000-0000-0000-000000000001','S2 Admin','s2-admin','admin',true),
  ('91000000-0000-0000-0000-000000000002','S2 Dispatcher','s2-dispatcher','dispatcher',true),
  ('91000000-0000-0000-0000-000000000003','S2 Driver A','s2-driver-a','driver',true),
  ('91000000-0000-0000-0000-000000000004','S2 Driver B','s2-driver-b','driver',true),
  ('91000000-0000-0000-0000-000000000005','S2 Inactive Ops','s2-inactive','dispatcher',false),
  ('91000000-0000-0000-0000-000000000006','S2 Extra Admin','s2-extra-admin','admin',true);

insert into public.drivers (id,profile_id,status) values
  ('92000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000003','assigned'),
  ('92000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000004','assigned');
insert into public.clients (id,company_name) values ('93000000-0000-0000-0000-000000000001','S2 Client');
insert into public.vehicles (id,registration,make,model,vehicle_type,status) values
  ('94000000-0000-0000-0000-000000000001','S2-A','Test','A','Truck','in_use'),
  ('94000000-0000-0000-0000-000000000002','S2-B','Test','B','Truck','in_use');
insert into public.shipments (id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
  ('95000000-0000-0000-0000-000000000001','SHP-S2-A','93000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','92000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001',1,'assigned'),
  ('95000000-0000-0000-0000-000000000002','SHP-S2-B','93000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','92000000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000002',1,'loading');

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000003';
select results_eq(
  $$select request_state,accepted_status from public.create_shipment_status_request('loading')$$,
  $$values ('pending'::public.status_request_state,'loading'::public.shipment_status)$$,
  'Assigned Driver requests loading'
);
reset role;

select is((select count(*) from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000001' and request_state='pending'),1::bigint,'Request snapshot is pending');
select results_eq(
  $$select current_status,requested_status from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000001'$$,
  $$values ('assigned'::public.shipment_status,'loading'::public.shipment_status)$$,
  'Request stores exact transition snapshot'
);
select results_eq(
  $$select action_type,metadata from public.activity_logs where status_request_id=(select id from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000001')$$,
  $$values ('status_request_created'::public.activity_action_type,'{"from_status":"assigned","requested_status":"loading"}'::jsonb)$$,
  'Creation activity is exact'
);
select is((select count(*) from public.notifications where shipment_id='95000000-0000-0000-0000-000000000001' and notification_type='status_approval_requested'),3::bigint,'Every active Operations profile receives one notification');
select is((select count(*) from public.notifications where recipient_profile_id in ('91000000-0000-0000-0000-000000000003','91000000-0000-0000-0000-000000000005')),0::bigint,'Driver and inactive Operations profile receive none');
select results_eq(
  $$select distinct title,message from public.notifications where shipment_id='95000000-0000-0000-0000-000000000001'$$,
  $$values ('Shipment status request'::text,'Shipment SHP-S2-A: Driver requested Loading.'::text)$$,
  'Creation notification copy is exact'
);

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000003';
select throws_ok($$select * from public.create_shipment_status_request('loading')$$,'23505','shipment_status_request_pending','Duplicate pending request is rejected');
select throws_ok($$select * from public.create_shipment_status_request('delivered')$$,'22023','shipment_status_request_transition_invalid','Skipped transition is rejected before duplicate check');
reset role;
select is((select count(*) from public.activity_logs where action_type='status_request_created' and actor_profile_id='91000000-0000-0000-0000-000000000003'),1::bigint,'Failed creation adds no activity');

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000004';
select throws_ok($$select * from public.create_shipment_status_request('delivered')$$,'22023','shipment_status_request_transition_invalid','Loading Driver cannot skip to delivered');
select results_eq($$select request_state,current_status,requested_status from public.get_current_driver_status_request()$$,$$select null::public.status_request_state,null::public.shipment_status,null::public.shipment_status where false$$,'Driver without request reads no request');
select lives_ok($$select * from public.create_shipment_status_request('in_transit')$$,'Loading Driver requests exact next status');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000001';
select is((select count(*) from public.list_operations_pending_status_requests()),2::bigint,'Admin lists pending queue');
reset role;
select results_eq($$select id from public.list_operations_pending_status_requests()$$,$$select id from public.shipment_status_requests where request_state='pending' order by requested_at asc,id asc$$,'Pending queue uses requested time then ID order');
set local role authenticated;
select lives_ok(format('select * from public.approve_shipment_status_request(%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-A')),'Admin approves assigned to loading');
reset role;
select is((select status from public.shipments where id='95000000-0000-0000-0000-000000000001'),'loading'::public.shipment_status,'Shipment becomes loading');
select is((select request_state from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000001'),'approved'::public.status_request_state,'Request becomes approved');
select is((select status from public.drivers where id='92000000-0000-0000-0000-000000000001'),'assigned'::public.driver_status,'Loading keeps Driver assigned');
select is((select status from public.vehicles where id='94000000-0000-0000-0000-000000000001'),'in_use'::public.vehicle_status,'Loading keeps Vehicle in use');
select is((select count(*) from public.vehicle_locations where shipment_id='95000000-0000-0000-0000-000000000001'),0::bigint,'Loading starts no tracking');
select is((select count(*) from public.activity_logs where shipment_id='95000000-0000-0000-0000-000000000001' and action_type='shipment_status_changed'),1::bigint,'Approval creates one Shipment status activity');
select is((select count(*) from public.activity_logs where action_type='status_request_approved' and status_request_id=(select id from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000001')),1::bigint,'Approval creates one request activity');
select results_eq(
  $$select title,message from public.notifications where shipment_id='95000000-0000-0000-0000-000000000001' and notification_type='status_approved'$$,
  $$values ('Shipment status approved'::text,'Shipment SHP-S2-A is now Loading.'::text)$$,
  'Approval notification copy is exact'
);
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000002';
select lives_ok(format('select * from public.reject_shipment_status_request(%L,%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-B'),''),'Dispatcher rejects without a reason');
reset role;
select is((select rejection_reason from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000002'),null,'Empty rejection reason becomes null');
select results_eq($$select message from public.notifications where shipment_id='95000000-0000-0000-0000-000000000002' and notification_type='status_rejected'$$,$$values ('Shipment SHP-S2-B: In transit request was rejected.'::text)$$,'Reasonless rejection notification is exact');

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000003';
select lives_ok($$select * from public.create_shipment_status_request('in_transit')$$,'Driver requests in transit');
reset role;
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000002';
select lives_ok(format('select * from public.approve_shipment_status_request(%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-A')),'Dispatcher approves loading to in transit');
reset role;
select results_eq(
  $$select latitude,longitude,speed,heading,route_progress from public.vehicle_locations where shipment_id='95000000-0000-0000-0000-000000000001'$$,
  $$values (45.2671::double precision,19.8335::double precision,0::numeric,0::double precision,0::numeric)$$,
  'Tracking current state uses exact seed'
);
select is((select count(*) from public.tracking_history where shipment_id='95000000-0000-0000-0000-000000000001'),1::bigint,'Tracking start inserts one initial snapshot');
select results_eq($$select metadata from public.activity_logs where shipment_id='95000000-0000-0000-0000-000000000001' and action_type='tracking_started'$$,$$values ('{"source":"status_request_approval"}'::jsonb)$$,'Tracking start activity is exact');

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000003';
select lives_ok($$select * from public.create_shipment_status_request('delivered')$$,'Delivered request does not require POD');
reset role;
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000001';
select throws_ok(format('select * from public.approve_shipment_status_request(%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-A')),'P0001','shipment_delivery_pod_required','Delivery approval requires POD');
reset role;
select is((select status from public.shipments where id='95000000-0000-0000-0000-000000000001'),'in_transit'::public.shipment_status,'Failed POD gate leaves Shipment unchanged');

insert into public.documents (id,shipment_id,uploader_profile_id,document_type,file_path,file_name,lifecycle_status) values
  ('96000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000003','proof_of_delivery','shipment/s2/pod.pdf','pod.pdf','active'),
  ('96000000-0000-0000-0000-000000000002','95000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000003','proof_of_delivery','shipment/s2/pod-2.pdf','pod-2.pdf','active');
insert into public.alerts (id,alert_type,severity,message,alert_state,vehicle_id) values ('97000000-0000-0000-0000-000000000001','stale_vehicle_location','critical','Stale','active','94000000-0000-0000-0000-000000000001');
update public.shipments set delayed=true where id='95000000-0000-0000-0000-000000000001';
insert into public.alerts (id,alert_type,severity,message,alert_state,shipment_id,vehicle_id,driver_id,document_id,resolved_at,resolved_by_profile_id) values
  ('97000000-0000-0000-0000-000000000002','shipment_delayed','warning','Shipment SHP-S2-A has been marked as delayed.','active','95000000-0000-0000-0000-000000000001',null,null,null,null,null);
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000002';
select lives_ok(format('select * from public.approve_shipment_status_request(%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-A')),'Delivery approval succeeds with multiple valid PODs');
reset role;
select results_eq($$select status,delayed from public.shipments where id='95000000-0000-0000-0000-000000000001'$$,$$values ('delivered'::public.shipment_status,false)$$,'Delivery sets status and clears delayed');
select is((select status from public.drivers where id='92000000-0000-0000-0000-000000000001'),'available'::public.driver_status,'Delivery releases Driver');
select is((select status from public.vehicles where id='94000000-0000-0000-0000-000000000001'),'available'::public.vehicle_status,'Delivery releases Vehicle');
select is((select count(*) from public.vehicle_locations where shipment_id='95000000-0000-0000-0000-000000000001'),0::bigint,'Delivery removes current location');
select is((select count(*) from public.tracking_history where shipment_id='95000000-0000-0000-0000-000000000001'),2::bigint,'Delivery preserves initial and final history');
select is((select alert_state from public.alerts where id='97000000-0000-0000-0000-000000000001'),'resolved'::public.alert_state,'Delivery resolves stale-location alert');
select is((select count(*) from public.activity_logs where shipment_id='95000000-0000-0000-0000-000000000001' and action_type='tracking_stopped'),1::bigint,'Delivery records one tracking stop');

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000004';
select lives_ok($$select * from public.create_shipment_status_request('in_transit')$$,'Second Driver creates valid request');
reset role;
update public.shipments set status='in_transit' where id='95000000-0000-0000-0000-000000000002';
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000001';
select throws_ok(format('select * from public.approve_shipment_status_request(%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-B')),'40001','shipment_status_request_stale','Stale approval is denied');
select lives_ok(format('select * from public.reject_shipment_status_request(%L,%L)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-B'),'  Not ready  '),'Stale request can be rejected');
reset role;
select results_eq($$select request_state,rejection_reason from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000002' and rejection_reason='Not ready'$$,$$values ('rejected'::public.status_request_state,'Not ready'::text)$$,'Rejection trims and stores reason');
select results_eq($$select metadata from public.activity_logs where action_type='status_request_rejected' and status_request_id=(select id from public.shipment_status_requests where shipment_id='95000000-0000-0000-0000-000000000002' and rejection_reason='Not ready')$$,$$values ('{"from_status":"loading","requested_status":"in_transit"}'::jsonb)$$,'Rejection activity excludes reason');
select results_eq($$select title,message from public.notifications where shipment_id='95000000-0000-0000-0000-000000000002' and notification_type='status_rejected' and message like '%Reason:%'$$,$$values ('Shipment status request rejected'::text,'Shipment SHP-S2-B: In transit request was rejected. Reason: Not ready'::text)$$,'Rejection notification is exact');

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000004';
select throws_ok($$select * from public.create_shipment_status_request('loading')$$,'22023','shipment_status_request_transition_invalid','In-transit Driver cannot request backwards status');
select throws_ok($$select * from public.create_shipment_status_request('cancelled')$$,'22023','shipment_status_request_transition_invalid','Driver cannot request cancelled');
select lives_ok($$select * from public.create_shipment_status_request('delivered')$$,'In-transit Driver can request delivered');
reset role;
update public.shipments set status='delivered' where id='95000000-0000-0000-0000-000000000002';
update public.profiles set is_active=false where id='91000000-0000-0000-0000-000000000004';
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000001';
select lives_ok(format('select * from public.reject_shipment_status_request(%L,null)',(select id from public.list_operations_pending_status_requests() where tracking_number='SHP-S2-B')),'Stale rejection succeeds for inactive original Driver');
reset role;
select is((select count(*) from public.notifications where shipment_id='95000000-0000-0000-0000-000000000002' and notification_type='status_rejected'),2::bigint,'Ineligible original Driver receives no additional rejection notification');
set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000001';
select throws_ok($$select * from public.reject_shipment_status_request('00000000-0000-0000-0000-000000000001',repeat('x',501))$$,'22023','shipment_status_rejection_invalid','Over-limit rejection reason is rejected safely');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000003';
select throws_ok($$select * from public.list_operations_pending_status_requests()$$,'42501','shipment_status_request_read_access_denied','Driver cannot list Operations queue');
select throws_ok($$select * from public.approve_shipment_status_request('00000000-0000-0000-0000-000000000001')$$,'42501','shipment_status_resolution_access_denied','Driver cannot approve');
select throws_ok($$insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status) values(gen_random_uuid(),'95000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001','assigned','loading')$$,'42501',null,'Direct request insert is denied');
select throws_ok($$select public.start_shipment_tracking('95000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000003')$$,'42501',null,'Tracking helper is not browser executable');
reset role;

set local role authenticated;
set local "request.jwt.claim.sub"='91000000-0000-0000-0000-000000000005';
select throws_ok($$select * from public.list_operations_pending_status_requests()$$,'42501','shipment_status_request_read_access_denied','Inactive Dispatcher cannot list queue');
reset role;
set local role anon;
select throws_ok($$select * from public.list_operations_pending_status_requests()$$,'42501',null,'Anonymous caller cannot list queue');
reset role;

select ok(not has_function_privilege('anon','public.create_shipment_status_request(public.shipment_status)','EXECUTE'),'Anonymous cannot create request');
select ok(not has_function_privilege('authenticated','public.start_shipment_tracking(uuid,uuid,uuid)','EXECUTE'),'Authenticated cannot execute tracking start helper');
select ok(not has_function_privilege('authenticated','public.stop_shipment_tracking(uuid,uuid,uuid)','EXECUTE'),'Authenticated cannot execute tracking stop helper');

select * from finish();
rollback;
