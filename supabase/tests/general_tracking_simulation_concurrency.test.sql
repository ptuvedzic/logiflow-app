begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

select extensions.dblink_connect('s4_setup','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('s4_setup',$setup$
create or replace function public.s4_race_cleanup() returns void language plpgsql security definer set search_path='' as $f$ begin
 delete from public.notifications where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.activity_logs where vehicle_id='e4000000-0000-0000-0000-000000000001' or shipment_id='e5000000-0000-0000-0000-000000000001' or status_request_id='e6000000-0000-0000-0000-000000000001';
 delete from public.alerts where vehicle_id='e4000000-0000-0000-0000-000000000001';
 delete from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.vehicle_locations where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.documents where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.shipment_status_requests where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.shipments where id='e5000000-0000-0000-0000-000000000001';
 delete from public.vehicles where id='e4000000-0000-0000-0000-000000000001';
 delete from public.drivers where id='e2000000-0000-0000-0000-000000000001';
 delete from public.clients where id='e3000000-0000-0000-0000-000000000001';
 delete from public.profiles where id::text like 'e1000000-%'; delete from auth.users where id::text like 'e1000000-%';
end $f$;
do $d$ begin perform public.s4_race_cleanup(); end $d$;
insert into auth.users(id) values('e1000000-0000-0000-0000-000000000001'),('e1000000-0000-0000-0000-000000000002');
insert into public.profiles(id,full_name,username,role,is_active) values
 ('e1000000-0000-0000-0000-000000000001','Race Admin','s4-race-admin','admin',true),
 ('e1000000-0000-0000-0000-000000000002','Race Driver','s4-race-driver','driver',true);
insert into public.drivers(id,profile_id,status) values('e2000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002','assigned');
insert into public.clients(id,company_name,status) values('e3000000-0000-0000-0000-000000000001','Race Client','active');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values('e4000000-0000-0000-0000-000000000001','S4-RACE','Make','Model','Truck','in_use');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status)
values('e5000000-0000-0000-0000-000000000001','SHP-S4-RACE','e3000000-0000-0000-0000-000000000001','A','B',now(),now()+interval '1 hour','Cargo','e2000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001',1,'in_transit');

create or replace function public.s4_race_reset(delivery boolean, active_alert boolean, destination boolean, stale boolean) returns void language plpgsql security definer set search_path='' as $f$ begin
 delete from public.notifications where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.activity_logs where vehicle_id='e4000000-0000-0000-0000-000000000001' or shipment_id='e5000000-0000-0000-0000-000000000001' or status_request_id='e6000000-0000-0000-0000-000000000001';
 delete from public.alerts where vehicle_id='e4000000-0000-0000-0000-000000000001'; delete from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.vehicle_locations where shipment_id='e5000000-0000-0000-0000-000000000001'; delete from public.documents where shipment_id='e5000000-0000-0000-0000-000000000001';
 delete from public.shipment_status_requests where shipment_id='e5000000-0000-0000-0000-000000000001';
 update public.drivers set status='assigned' where id='e2000000-0000-0000-0000-000000000001'; update public.vehicles set status='in_use' where id='e4000000-0000-0000-0000-000000000001';
 update public.shipments set status='in_transit',delayed=false where id='e5000000-0000-0000-0000-000000000001';
 insert into public.vehicle_locations(vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress,updated_at) values
 ('e4000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001',case when destination then 44.7866 else 45.2671 end,case when destination then 20.4489 else 19.8335 end,0,0,case when destination then 100 else 0 end,now()-case when stale then interval '11 minutes' else interval '61 seconds' end);
 insert into public.tracking_history(id,vehicle_id,shipment_id,latitude,longitude,speed,heading,route_progress,recorded_at) values('e9000000-0000-0000-0000-000000000001','e4000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001',45.2671,19.8335,0,0,0,now()-interval '12 minutes');
 if delivery then
  insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status) values('e6000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001','e2000000-0000-0000-0000-000000000001','in_transit','delivered');
  insert into public.documents(id,shipment_id,uploader_profile_id,document_type,file_path,file_name,lifecycle_status) values('e7000000-0000-0000-0000-000000000001','e5000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000002','proof_of_delivery','shipment/s4-race/pod.pdf','pod.pdf','active');
 end if;
 if active_alert then insert into public.alerts(id,alert_type,severity,message,vehicle_id) values('e8000000-0000-0000-0000-000000000001','stale_vehicle_location','critical','Race stale','e4000000-0000-0000-0000-000000000001'); end if;
end $f$;
create or replace function public.s4_race_sim() returns text language plpgsql security definer set search_path='' as $f$ begin return (select step_result from public.simulate_tracking_step('e5000000-0000-0000-0000-000000000001','[[19.8335,45.2671],[20.4489,44.7866]]'::jsonb)); exception when others then return sqlstate||':'||sqlerrm; end $f$;
create or replace function public.s4_race_rec() returns text language plpgsql security definer set search_path='' as $f$ declare r record; begin select * into r from public.reconcile_stale_vehicle_locations(); return r.created_count||':'||r.resolved_count; exception when others then return sqlstate||':'||sqlerrm; end $f$;
create or replace function public.s4_race_deliver() returns text language plpgsql security definer set search_path='' as $f$ begin perform public.approve_shipment_status_request('e6000000-0000-0000-0000-000000000001'); return 'delivered'; exception when others then return sqlstate||':'||sqlerrm; end $f$;
create or replace function public.s4_race_cancel() returns text language plpgsql security definer set search_path='' as $f$ begin perform public.cancel_shipment('e5000000-0000-0000-0000-000000000001'); return 'cancelled'; exception when others then return sqlstate||':'||sqlerrm; end $f$;
$setup$);
select extensions.dblink_connect('s4_a','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('s4_b','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Each session has finite lock/statement timeouts. Any unexpected wait or deadlock becomes a returned test failure.
-- A: simulator versus simulator.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,false,false,false); end $d$');
select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_sim()') r(result text)),'advanced','A winner advances');
select is((select result from extensions.dblink('s4_b','select public.s4_race_sim()') r(result text)),'skipped_locked','A loser advisory-skips');
select extensions.dblink_exec('s4_a','commit');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select ok((select route_progress>0 from public.vehicle_locations where vehicle_id='e4000000-0000-0000-0000-000000000001'),'A one effective progress advance');
select is((select count(*) from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001'),2::bigint,'A one new history row');

-- Shared helper pattern for B/C: winner holds its transaction while the competitor starts, then commits.
-- B1 simulator wins delivery.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(true,false,false,false); end $d$');
select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='e1000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_sim()') r(result text)),'advanced','B1 simulator commits first');select ok(extensions.dblink_send_query('s4_b','select public.s4_race_deliver()')=1,'B1 delivery starts concurrently');select pg_sleep(.1);select extensions.dblink_exec('s4_a','commit');
select is((select result from extensions.dblink_get_result('s4_b',false) r(result text)),'delivered','B1 delivery consumes committed state');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.vehicle_locations where shipment_id='e5000000-0000-0000-0000-000000000001'),0::bigint,'B1 location never reappears');select is((select count(*) from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001'),3::bigint,'B1 history is initial, simulation, final');select is((select count(*) from public.activity_logs where shipment_id='e5000000-0000-0000-0000-000000000001' and action_type='tracking_stopped' and metadata='{"source":"status_request_approval"}'::jsonb),1::bigint,'B1 exact S2 tracking stop');
-- B2 delivery wins simulator.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(true,false,false,false); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='e1000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_deliver()') r(result text)),'delivered','B2 delivery wins');select ok(extensions.dblink_send_query('s4_b','select public.s4_race_sim()')=1,'B2 simulator starts concurrently');select pg_sleep(.1);select extensions.dblink_exec('s4_a','commit');select is((select result from extensions.dblink_get_result('s4_b',false) r(result text)),'skipped_ineligible','B2 simulator skips after reread');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.vehicle_locations where shipment_id='e5000000-0000-0000-0000-000000000001'),0::bigint,'B2 location never reappears');select is((select count(*) from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001'),2::bigint,'B2 exact S2 snapshots');select is((select count(*) from public.activity_logs where shipment_id='e5000000-0000-0000-0000-000000000001' and action_type='tracking_stopped'),1::bigint,'B2 one S2 stop');

-- C1 simulator wins cancellation.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,false,false,false); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='e1000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_sim()') r(result text)),'advanced','C1 simulator commits first');select ok(extensions.dblink_send_query('s4_b','select public.s4_race_cancel()')=1,'C1 cancellation starts concurrently');select pg_sleep(.1);select extensions.dblink_exec('s4_a','commit');select is((select result from extensions.dblink_get_result('s4_b',false) r(result text)),'cancelled','C1 cancellation consumes committed state');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.vehicle_locations where shipment_id='e5000000-0000-0000-0000-000000000001'),0::bigint,'C1 location never reappears');select is((select count(*) from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001'),3::bigint,'C1 exact simulation plus S3 snapshots');select is((select count(*) from public.activity_logs where shipment_id='e5000000-0000-0000-0000-000000000001' and action_type='tracking_stopped' and metadata='{"source":"shipment_cancellation"}'::jsonb),1::bigint,'C1 exact S3 tracking stop');
-- C2 cancellation wins simulator.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,false,false,false); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='e1000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_cancel()') r(result text)),'cancelled','C2 cancellation wins');select ok(extensions.dblink_send_query('s4_b','select public.s4_race_sim()')=1,'C2 simulator starts concurrently');select pg_sleep(.1);select extensions.dblink_exec('s4_a','commit');select is((select result from extensions.dblink_get_result('s4_b',false) r(result text)),'skipped_ineligible','C2 simulator skips after reread');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.vehicle_locations where shipment_id='e5000000-0000-0000-0000-000000000001'),0::bigint,'C2 location never reappears');select is((select count(*) from public.tracking_history where shipment_id='e5000000-0000-0000-0000-000000000001'),2::bigint,'C2 exact S3 snapshots');select is((select count(*) from public.activity_logs where shipment_id='e5000000-0000-0000-0000-000000000001' and action_type='tracking_stopped'),1::bigint,'C2 one S3 stop');

-- D simulator versus stale creation.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,false,false,true); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_sim()') r(result text)),'advanced','D simulator refreshes stale row');select is((select result from extensions.dblink('s4_b','select public.s4_race_rec()') r(result text)),'0:0','D reconciler skip-locks row');select extensions.dblink_exec('s4_a','commit');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.alerts where vehicle_id='e4000000-0000-0000-0000-000000000001' and alert_state='active'),0::bigint,'D no invalid active alert');select is((select count(*) from public.activity_logs where vehicle_id='e4000000-0000-0000-0000-000000000001' and action_type='alert_created'),0::bigint,'D no duplicate create activity');
-- E recovery versus scheduled resolution.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,true,false,false); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_sim()') r(result text)),'advanced','E simulator resolves alert');select is((select result from extensions.dblink('s4_b','select public.s4_race_rec()') r(result text)),'0:0','E reconciler cannot duplicate resolution');select extensions.dblink_exec('s4_a','commit');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.alerts where id='e8000000-0000-0000-0000-000000000001' and alert_state='resolved'),1::bigint,'E alert resolved once');select is((select count(*) from public.activity_logs where vehicle_id='e4000000-0000-0000-0000-000000000001' and action_type='alert_resolved'),1::bigint,'E one resolution activity');
-- F two stale reconcilers.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,false,false,true); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_rec()') r(result text)),'1:0','F first reconciler creates');select is((select result from extensions.dblink('s4_b','select public.s4_race_rec()') r(result text)),'0:0','F second reconciler skips');select extensions.dblink_exec('s4_a','commit');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.alerts where vehicle_id='e4000000-0000-0000-0000-000000000001' and alert_state='active'),1::bigint,'F one active stale alert');select is((select count(*) from public.activity_logs where vehicle_id='e4000000-0000-0000-0000-000000000001' and action_type='alert_created'),1::bigint,'F one creation activity');
-- G destination heartbeat versus reconciliation.
select extensions.dblink_exec('s4_setup','do $d$ begin perform public.s4_race_reset(false,false,true,true); end $d$');select extensions.dblink_exec('s4_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);select extensions.dblink_exec('s4_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('s4_a','select public.s4_race_sim()') r(result text)),'heartbeat','G heartbeat refreshes destination');select is((select result from extensions.dblink('s4_b','select public.s4_race_rec()') r(result text)),'0:0','G reconciler skip-locks heartbeat');select extensions.dblink_exec('s4_a','commit');select * from extensions.dblink_get_result('s4_b',false) as drained(result text);select extensions.dblink_exec('s4_b','commit');
select is((select count(*) from public.alerts where vehicle_id='e4000000-0000-0000-0000-000000000001' and alert_state='active'),0::bigint,'G no contradictory active alert');select is((select speed from public.vehicle_locations where vehicle_id='e4000000-0000-0000-0000-000000000001'),0.00::numeric,'G destination remains stopped');select is((select route_progress from public.vehicle_locations where vehicle_id='e4000000-0000-0000-0000-000000000001'),100.00::numeric,'G destination remains complete');
-- H: timeout-enforced completion and lock/deadlock safety.
select ok(position('deadlock detected' in coalesce(extensions.dblink_error_message('s4_a'),''))=0,'H session A has no deadlock');select ok(position('deadlock detected' in coalesce(extensions.dblink_error_message('s4_b'),''))=0,'H session B has no deadlock');

select extensions.dblink_exec('s4_setup',$cleanup$do $d$ begin perform public.s4_race_cleanup(); end $d$;drop function public.s4_race_cancel();drop function public.s4_race_deliver();drop function public.s4_race_rec();drop function public.s4_race_sim();drop function public.s4_race_reset(boolean,boolean,boolean,boolean);drop function public.s4_race_cleanup();$cleanup$);
select extensions.dblink_disconnect('s4_a');select extensions.dblink_disconnect('s4_b');select extensions.dblink_disconnect('s4_setup');
select * from finish();
rollback;
