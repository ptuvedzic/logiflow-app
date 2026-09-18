begin;

create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select plan(68);
select extensions.dblink_connect('s2_setup','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('s2_setup',$setup$
  delete from public.notifications where shipment_id='a5000000-0000-0000-0000-000000000001';
  delete from public.activity_logs where shipment_id='a5000000-0000-0000-0000-000000000001' or status_request_id in(select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001');
  delete from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001';
  delete from public.shipments where id='a5000000-0000-0000-0000-000000000001';
  delete from public.vehicles where id='a4000000-0000-0000-0000-000000000001';
  delete from public.drivers where id='a2000000-0000-0000-0000-000000000001';
  delete from public.clients where id='a3000000-0000-0000-0000-000000000001';
  delete from public.profiles where id::text like 'a1000000-%'; delete from auth.users where id::text like 'a1000000-%';
  drop function if exists public.s2_capture_create();
  drop function if exists public.s2_capture_approve();
  drop function if exists public.s2_capture_reject();
  drop function if exists public.s2_capture_deactivate();
  drop function if exists public.s2_capture_driver_lifecycle();
  drop function if exists public.s2_capture_vehicle_lifecycle();
  drop function if exists public.s2_capture_delivery_competitor();
  drop function if exists public.s2_reset_fixture(public.shipment_status,boolean,boolean,boolean,boolean);
  insert into auth.users(id) values
    ('a1000000-0000-0000-0000-000000000001'),('a1000000-0000-0000-0000-000000000002'),('a1000000-0000-0000-0000-000000000003');
  insert into public.profiles(id,full_name,username,role,is_active) values
    ('a1000000-0000-0000-0000-000000000001','Race Admin','s2-race-admin','admin',true),
    ('a1000000-0000-0000-0000-000000000002','Race Dispatcher','s2-race-dispatcher','dispatcher',true),
    ('a1000000-0000-0000-0000-000000000003','Race Driver','s2-race-driver','driver',true);
  insert into public.drivers(id,profile_id,status) values('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','assigned');
  insert into public.clients(id,company_name) values('a3000000-0000-0000-0000-000000000001','Race Client');
  insert into public.vehicles(id,registration,make,model,vehicle_type,status) values('a4000000-0000-0000-0000-000000000001','S2-RACE','Test','Race','Truck','in_use');
  insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status)
  values('a5000000-0000-0000-0000-000000000001','SHP-S2-RACE','a3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','a2000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,'assigned');
  create function public.s2_capture_create() returns text language plpgsql security definer set search_path='' as $fn$
  begin perform public.create_shipment_status_request('loading'); return 'captured_success';
  exception when others then return sqlstate || ':' || sqlerrm; end $fn$;
  create function public.s2_capture_approve() returns text language plpgsql security definer set search_path='' as $fn$
  begin perform public.approve_shipment_status_request((select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001')); return 'captured_success';
  exception when others then return sqlstate || ':' || sqlerrm; end $fn$;
  create function public.s2_capture_reject() returns text language plpgsql security definer set search_path='' as $fn$
  begin perform public.reject_shipment_status_request((select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001'),null); return 'captured_success';
  exception when others then return sqlstate || ':' || sqlerrm; end $fn$;
  create function public.s2_capture_deactivate() returns text language plpgsql security definer set search_path='' as $fn$
  begin perform public.set_managed_account_active_state('s2-race-driver',false); return 'captured_success';
  exception when others then return sqlstate || ':' || sqlerrm; end $fn$;
  create function public.s2_capture_driver_lifecycle() returns text language plpgsql security definer set search_path='' as $fn$
  begin perform public.change_driver_operational_status('a2000000-0000-0000-0000-000000000001','mark_off_duty'); return 'captured_success';
  exception when others then return sqlstate || ':' || sqlerrm; end $fn$;
  create function public.s2_capture_vehicle_lifecycle() returns text language plpgsql security definer set search_path='' as $fn$
  begin perform public.change_vehicle_operational_status('a4000000-0000-0000-0000-000000000001','mark_maintenance'); return 'captured_success';
  exception when others then return sqlstate || ':' || sqlerrm; end $fn$;
  create function public.s2_capture_delivery_competitor() returns text language plpgsql security definer set search_path='' as $fn$
  begin
    update public.documents set lifecycle_status='archived' where id='a7000000-0000-0000-0000-000000000001';
    update public.vehicle_locations set speed=2 where vehicle_id='a4000000-0000-0000-0000-000000000001';
    update public.alerts set message='Race reconciled' where id='a8000000-0000-0000-0000-000000000001';
    return 'competitor_done';
  end $fn$;
  create function public.s2_reset_fixture(target_status public.shipment_status,add_request boolean,add_pod boolean,add_location boolean,add_alert boolean) returns void language plpgsql security definer set search_path='' as $fn$
  begin
    delete from public.notifications where shipment_id='a5000000-0000-0000-0000-000000000001';
    delete from public.activity_logs where shipment_id='a5000000-0000-0000-0000-000000000001' or status_request_id in(select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001');
    delete from public.alerts where vehicle_id='a4000000-0000-0000-0000-000000000001';
    delete from public.tracking_history where shipment_id='a5000000-0000-0000-0000-000000000001';
    delete from public.vehicle_locations where shipment_id='a5000000-0000-0000-0000-000000000001';
    delete from public.documents where shipment_id='a5000000-0000-0000-0000-000000000001';
    delete from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001';
    update public.profiles set is_active=true where id='a1000000-0000-0000-0000-000000000003';
    update public.drivers set status='assigned' where id='a2000000-0000-0000-0000-000000000001';
    update public.vehicles set status='in_use' where id='a4000000-0000-0000-0000-000000000001';
    update public.shipments set status=target_status,delayed=false where id='a5000000-0000-0000-0000-000000000001';
    if add_request then insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status) values('a6000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000001',target_status,case target_status when 'assigned' then 'loading'::public.shipment_status when 'loading' then 'in_transit'::public.shipment_status else 'delivered'::public.shipment_status end); end if;
    if add_pod then insert into public.documents(id,shipment_id,uploader_profile_id,document_type,file_path,file_name,lifecycle_status) values('a7000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000003','proof_of_delivery','shipment/race/pod.pdf','pod.pdf','active'); end if;
    if add_location then insert into public.vehicle_locations(vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress) values('a4000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001',45,19,1,1,50); end if;
    if add_alert then insert into public.alerts(id,alert_type,severity,message,vehicle_id) values('a8000000-0000-0000-0000-000000000001','stale_vehicle_location','critical','Race stale','a4000000-0000-0000-0000-000000000001'); end if;
  end $fn$;
$setup$);
select extensions.dblink_connect('s2_a','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('s2_b','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select ok(extensions.dblink_send_query('s2_a',$$select * from public.create_shipment_status_request('loading')$$)=1,'First request starts');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_create()$$)=1,'Duplicate request starts');
select * from extensions.dblink_get_result('s2_a',false) as r(request_state public.status_request_state,accepted_status public.shipment_status);
select * from extensions.dblink_get_result('s2_a',false) as r(request_state public.status_request_state,accepted_status public.shipment_status);
select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('23505:shipment_status_request_pending'::text)$$,'Duplicate request loses safely');
select * from extensions.dblink_get_result('s2_b',false) as r(result text);
select extensions.dblink_exec('s2_b','rollback');
select is((select count(*) from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001'),1::bigint,'Duplicate race creates one request');
select is((select count(*) from public.activity_logs where action_type='status_request_created' and status_request_id in(select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001')),1::bigint,'Duplicate race creates one activity');
select is((select count(*) from public.notifications where shipment_id='a5000000-0000-0000-0000-000000000001' and notification_type='status_approval_requested'),2::bigint,'Duplicate race creates one notification per Operations recipient');

select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000002''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'Approval starts');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_reject()$$)=1,'Competing rejection starts');
select * from extensions.dblink_get_result('s2_a',false) as r(result text);
select * from extensions.dblink_get_result('s2_a',false) as r(result text);
select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('40001:shipment_status_request_resolved'::text)$$,'Competing rejection loses safely');
select * from extensions.dblink_get_result('s2_b',false) as r(result text);
select extensions.dblink_exec('s2_b','rollback');
select is((select request_state from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001'),'approved'::public.status_request_state,'Approve/reject race has one winner');
select is((select status from public.shipments where id='a5000000-0000-0000-0000-000000000001'),'loading'::public.shipment_status,'Race leaves exact Shipment state');
select is((select count(*) from public.activity_logs where action_type='status_request_approved' and status_request_id in(select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001')),1::bigint,'Race records one approval activity');
select is((select count(*) from public.activity_logs where action_type='status_request_rejected' and status_request_id in(select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001')),0::bigint,'Race loser records no rejection activity');
select ok(position('deadlock detected' in extensions.dblink_error_message('s2_b'))=0,'Concurrent S2 workflows do not deadlock');

-- Request creation serializes with account, Driver, and Vehicle lifecycle.
select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',false,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s2_b','begin; set local role service_role; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_create()$$)=1,'Request versus deactivation starts request'); select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_deactivate()$$)=1,'Request versus deactivation starts lifecycle');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Request wins deactivation race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('P0001:Driver has an active shipment.'::text)$$,'Deactivation loses after request'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select ok((select is_active from public.profiles where id='a1000000-0000-0000-0000-000000000003'),'Request race preserves active profile');
select is((select count(*) from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001'),1::bigint,'Request race leaves one request');

select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',false,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_create()$$)=1,'Request versus Driver lifecycle starts request'); select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_driver_lifecycle()$$)=1,'Request versus Driver lifecycle starts lifecycle');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Request wins Driver lifecycle race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('P0001:driver_status_active_shipment'::text)$$,'Driver lifecycle loses after request'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select is((select status from public.drivers where id='a2000000-0000-0000-0000-000000000001'),'assigned'::public.driver_status,'Driver lifecycle race preserves assigned Driver');
select is((select count(*) from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001'),1::bigint,'Driver lifecycle race leaves one request');

select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',false,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_create()$$)=1,'Request versus Vehicle lifecycle starts request'); select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_vehicle_lifecycle()$$)=1,'Request versus Vehicle lifecycle starts lifecycle');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Request wins Vehicle lifecycle race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('P0001:vehicle_active_shipment'::text)$$,'Vehicle lifecycle loses after request'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select is((select status from public.vehicles where id='a4000000-0000-0000-0000-000000000001'),'in_use'::public.vehicle_status,'Vehicle lifecycle race preserves in-use Vehicle');
select is((select count(*) from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001'),1::bigint,'Vehicle lifecycle race leaves one request');

-- Duplicate approval and approval versus lifecycle serialize on the same global order.
select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',true,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000002''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'First duplicate approval starts'); select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_approve()$$)=1,'Second duplicate approval starts');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'First duplicate approval wins'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('40001:shipment_status_request_resolved'::text)$$,'Second duplicate approval loses'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select is((select request_state from public.shipment_status_requests where id='a6000000-0000-0000-0000-000000000001'),'approved'::public.status_request_state,'Duplicate approval resolves once');
select is((select count(*) from public.activity_logs where action_type='status_request_approved'),1::bigint,'Duplicate approval records one approval activity');

-- One approval race against each closed lifecycle workflow.
select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',true,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001'''); select extensions.dblink_exec('s2_b','begin; set local role service_role; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'Approval versus deactivation starts approval'); select pg_sleep(0.1); select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_deactivate()$$)=1,'Approval versus deactivation starts lifecycle');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Approval wins deactivation race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('P0001:Driver has an active shipment.'::text)$$,'Deactivation loses after approval'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select is((select status from public.shipments where id='a5000000-0000-0000-0000-000000000001'),'loading'::public.shipment_status,'Approval/deactivation race keeps approved Shipment'); select ok((select is_active from public.profiles where id='a1000000-0000-0000-0000-000000000003'),'Approval/deactivation race keeps Driver active');

select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',true,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001'''); select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'Approval versus Driver lifecycle starts approval'); select pg_sleep(0.1); select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_driver_lifecycle()$$)=1,'Approval versus Driver lifecycle starts lifecycle');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Approval wins Driver lifecycle race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('P0001:driver_status_active_shipment'::text)$$,'Driver lifecycle loses after approval'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select is((select status from public.shipments where id='a5000000-0000-0000-0000-000000000001'),'loading'::public.shipment_status,'Approval/Driver lifecycle race keeps approved Shipment'); select is((select status from public.drivers where id='a2000000-0000-0000-0000-000000000001'),'assigned'::public.driver_status,'Approval/Driver lifecycle race keeps assigned Driver');

select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('assigned',true,false,false,false); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001'''); select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'Approval versus Vehicle lifecycle starts approval'); select pg_sleep(0.1); select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_vehicle_lifecycle()$$)=1,'Approval versus Vehicle lifecycle starts lifecycle');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Approval wins Vehicle lifecycle race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('P0001:vehicle_active_shipment'::text)$$,'Vehicle lifecycle loses after approval'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','rollback');
select is((select status from public.shipments where id='a5000000-0000-0000-0000-000000000001'),'loading'::public.shipment_status,'Approval/Vehicle lifecycle race keeps approved Shipment'); select is((select status from public.vehicles where id='a4000000-0000-0000-0000-000000000001'),'in_use'::public.vehicle_status,'Approval/Vehicle lifecycle race keeps Vehicle in use');

-- Delivery approval serializes with POD archive, tracking update, and stale-alert reconciliation in their shared order.
select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('in_transit',true,true,true,true); end $do$;$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001'''); select extensions.dblink_exec('s2_b','begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'Delivery approval starts'); select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_delivery_competitor()$$)=1,'POD/tracking/alert competitor starts');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Delivery approval wins mutable-row race'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','commit');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('competitor_done'::text)$$,'POD/tracking/alert competitor completes without deadlock'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','commit');
select is((select status from public.shipments where id='a5000000-0000-0000-0000-000000000001'),'delivered'::public.shipment_status,'Delivery race leaves delivered Shipment'); select is((select count(*) from public.tracking_history where shipment_id='a5000000-0000-0000-0000-000000000001'),1::bigint,'Delivery race keeps one final snapshot'); select is((select alert_state from public.alerts where id='a8000000-0000-0000-0000-000000000001'),'resolved'::public.alert_state,'Delivery race resolves stale alert');

-- A stale approval loses while a competing manual rejection clears the request.
select extensions.dblink_exec('s2_setup',$$do $do$ begin perform public.s2_reset_fixture('loading',true,false,false,false); end $do$;$$); select extensions.dblink_exec('s2_setup',$$update public.shipments set status='in_transit' where id='a5000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('s2_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000001'''); select extensions.dblink_exec('s2_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000002''');
select ok(extensions.dblink_send_query('s2_a',$$select public.s2_capture_approve()$$)=1,'Stale approval starts'); select pg_sleep(0.1); select ok(extensions.dblink_send_query('s2_b',$$select public.s2_capture_reject()$$)=1,'Competing stale rejection starts');
select results_eq($$select result from extensions.dblink_get_result('s2_a',false) as r(result text)$$,$$values ('40001:shipment_status_request_stale'::text)$$,'Stale approval fails safely'); select * from extensions.dblink_get_result('s2_a',false) as r(result text); select extensions.dblink_exec('s2_a','rollback');
select results_eq($$select result from extensions.dblink_get_result('s2_b',false) as r(result text)$$,$$values ('captured_success'::text)$$,'Competing stale rejection succeeds'); select * from extensions.dblink_get_result('s2_b',false) as r(result text); select extensions.dblink_exec('s2_b','commit');
select is((select request_state from public.shipment_status_requests where id='a6000000-0000-0000-0000-000000000001'),'rejected'::public.status_request_state,'Stale race clears pending request');

select extensions.dblink_disconnect('s2_a');
select extensions.dblink_disconnect('s2_b');
select extensions.dblink_exec('s2_setup',$cleanup$
  delete from public.notifications where shipment_id='a5000000-0000-0000-0000-000000000001';
  delete from public.activity_logs where shipment_id='a5000000-0000-0000-0000-000000000001' or status_request_id in(select id from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001');
  delete from public.shipment_status_requests where shipment_id='a5000000-0000-0000-0000-000000000001';
  delete from public.shipments where id='a5000000-0000-0000-0000-000000000001';
  delete from public.vehicles where id='a4000000-0000-0000-0000-000000000001';
  delete from public.drivers where id='a2000000-0000-0000-0000-000000000001';
  delete from public.clients where id='a3000000-0000-0000-0000-000000000001';
  delete from public.profiles where id::text like 'a1000000-%'; delete from auth.users where id::text like 'a1000000-%';
  drop function if exists public.s2_capture_create();
  drop function if exists public.s2_capture_approve();
  drop function if exists public.s2_capture_reject();
  drop function if exists public.s2_capture_deactivate();
  drop function if exists public.s2_capture_driver_lifecycle();
  drop function if exists public.s2_capture_vehicle_lifecycle();
  drop function if exists public.s2_capture_delivery_competitor();
  drop function if exists public.s2_reset_fixture(public.shipment_status,boolean,boolean,boolean,boolean);
$cleanup$);
select extensions.dblink_disconnect('s2_setup');
select * from finish();
rollback;
