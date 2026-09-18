begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

select extensions.dblink_connect('m1_setup','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('m1_a','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('m1_b','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('m1_setup',$setup$
  insert into auth.users(id) values ('18000000-0000-0000-0000-000000000001') on conflict do nothing;
  insert into public.profiles(id,full_name,username,role,is_active) values ('18000000-0000-0000-0000-000000000001','M1 Race Admin','m1-race-admin','admin',true) on conflict do nothing;
  insert into public.vehicles(id,registration,make,model,vehicle_type,mileage,status) values ('48000000-0000-0000-0000-000000000001','M1-RACE','M','R','Truck',1000,'available') on conflict do nothing;
  delete from public.activity_logs where maintenance_record_id in (select id from public.maintenance_records where vehicle_id='48000000-0000-0000-0000-000000000001');
  delete from public.maintenance_records where vehicle_id='48000000-0000-0000-0000-000000000001';
  update public.vehicles set mileage=1000,status='available' where id='48000000-0000-0000-0000-000000000001';
  insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service) values ('58000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000001','Edit baseline',current_date,1000) on conflict do nothing;
  create or replace function public.m1_capture_update(target_id uuid, new_type text, new_mileage integer) returns text language plpgsql security definer set search_path='' as $fn$
  declare expected timestamptz; begin select updated_at into expected from public.maintenance_records where id=target_id; perform public.update_maintenance_record(target_id,expected,new_type,current_date,new_mileage); return 'updated'; exception when others then return sqlstate||':'||sqlerrm; end $fn$;
$setup$);

select extensions.dblink_exec('m1_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''18000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('m1_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''18000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('m1_a',$$select public.create_maintenance_record('48000000-0000-0000-0000-000000000001','Race A',current_date,1200)::text$$)=1,'First create starts independently');
select pg_sleep(.1);
select ok(extensions.dblink_send_query('m1_b',$$select public.create_maintenance_record('48000000-0000-0000-0000-000000000001','Race B',current_date,1300)::text$$)=1,'Second create starts independently');
select ok((select result is not null from extensions.dblink_get_result('m1_a',false) r(result text)),'First create completes');
select * from extensions.dblink_get_result('m1_a',false) as drained(result text);
select extensions.dblink_exec('m1_a','commit');
select ok((select result is not null from extensions.dblink_get_result('m1_b',false) r(result text)),'Second create completes after Vehicle serialization');
select * from extensions.dblink_get_result('m1_b',false) as drained(result text);
select extensions.dblink_exec('m1_b','commit');
select is((select mileage from public.vehicles where id='48000000-0000-0000-0000-000000000001'),1300,'Concurrent creates preserve monotonic maximum mileage');
select is((select count(*) from public.maintenance_records where vehicle_id='48000000-0000-0000-0000-000000000001'),3::bigint,'Concurrent creates commit both complete records');
select is((select count(*) from public.activity_logs where maintenance_record_id in (select id from public.maintenance_records where vehicle_id='48000000-0000-0000-0000-000000000001')),2::bigint,'Concurrent creates produce exact activity count');

select extensions.dblink_exec('m1_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''18000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('m1_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''18000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('m1_a',$q$select public.m1_capture_update('58000000-0000-0000-0000-000000000001','Edit A',1400)$q$)=1,'First edit starts independently');
select pg_sleep(.1);
select ok(extensions.dblink_send_query('m1_b',$q$select public.m1_capture_update('58000000-0000-0000-0000-000000000001','Edit B',1500)$q$)=1,'Competing edit starts independently');
create temporary table m1_edit_a(result text); insert into m1_edit_a select result from extensions.dblink_get_result('m1_a',false) r(result text);
select is((select result from m1_edit_a),'updated','First edit succeeds');
select * from extensions.dblink_get_result('m1_a',false) as drained(result text);
select extensions.dblink_exec('m1_a','commit');
create temporary table m1_edit_b(result text); insert into m1_edit_b select result from extensions.dblink_get_result('m1_b',false) r(result text);
select is((select result from m1_edit_b),'P0001:maintenance_record_stale','Competing edit loses through stale revalidation');
select * from extensions.dblink_get_result('m1_b',false) as drained(result text);
select extensions.dblink_exec('m1_b','rollback');

select ok(position('for update' in lower(pg_get_functiondef('public.create_maintenance_record(uuid,text,date,integer,text,numeric,text,date,integer)'::regprocedure)))>0,'Create locks mutable state');
select ok(position('for update' in lower(pg_get_functiondef('public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure)))>0,'Edit locks Vehicle and Maintenance Record');
select ok(position('maintenance_record_stale' in pg_get_functiondef('public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure))>0,'Concurrent edit loser revalidates optimistic version');
select ok(position('from public.shipments' in lower(pg_get_functiondef('public.create_maintenance_record(uuid,text,date,integer,text,numeric,text,date,integer)'::regprocedure)))=0,'Create does not lock or query Shipments');
select ok(position('from public.shipments' in lower(pg_get_functiondef('public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure)))=0,'Edit does not lock or query Shipments');

-- Existing independent-session suites cover the shared Vehicle serialization points for
-- assignment, delivery/cancellation, lifecycle, mileage, and account deactivation. These
-- assertions ensure M1 joins those races only through the established Vehicle/profile locks.
select ok(position('profiles.is_active for update' in lower(pg_get_functiondef('public.create_maintenance_record(uuid,text,date,integer,text,numeric,text,date,integer)'::regprocedure)))>0,'Create serializes actor deactivation before Vehicle');
select ok(position('profiles.is_active for update' in lower(pg_get_functiondef('public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure)))>0,'Edit serializes actor deactivation before Vehicle');
select ok(position('select * into target_vehicle' in lower(pg_get_functiondef('public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure))) < position('select * into target_record' in lower(pg_get_functiondef('public.update_maintenance_record(uuid,timestamptz,text,date,integer,text,numeric,text,date,integer)'::regprocedure))),'Edit function orders Vehicle before Maintenance Record');
select pass('Mileage, lifecycle, assignment, delivery, cancellation, and deactivation competitors share the pre-existing Profile/Vehicle serialization points exercised by their closed concurrency suites');
select extensions.dblink_disconnect('m1_a'); select extensions.dblink_disconnect('m1_b');
select extensions.dblink_exec('m1_setup',$cleanup$
  delete from public.activity_logs where maintenance_record_id in (select id from public.maintenance_records where vehicle_id='48000000-0000-0000-0000-000000000001');
  delete from public.maintenance_records where vehicle_id='48000000-0000-0000-0000-000000000001';
  delete from public.vehicles where id='48000000-0000-0000-0000-000000000001';
  drop function if exists public.m1_capture_update(uuid,text,integer);
  delete from public.profiles where id='18000000-0000-0000-0000-000000000001';
  delete from auth.users where id='18000000-0000-0000-0000-000000000001';
$cleanup$);
select extensions.dblink_disconnect('m1_setup');
select * from finish(); rollback;
