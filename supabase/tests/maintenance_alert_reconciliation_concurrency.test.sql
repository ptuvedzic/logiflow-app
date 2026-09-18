begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

select extensions.dblink_connect('m2_setup','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('m2_setup',$setup$
  insert into auth.users(id) values ('1a000000-0000-0000-0000-000000000001') on conflict do nothing;
  insert into public.profiles(id,full_name,username,role,is_active) values
    ('1a000000-0000-0000-0000-000000000001','M2 Race Admin','m2-race-admin','admin',true)
    on conflict do nothing;
  insert into public.vehicles(id,registration,make,model,vehicle_type,mileage,status) values
    ('4a000000-0000-0000-0000-000000000001','M2-RACE','M','R','Truck',1000,'available')
    on conflict do nothing;
  create or replace function public.m2_race_reset(with_record boolean, with_alerts boolean) returns void
  language plpgsql security definer set search_path='' as $f$
  begin
    delete from public.activity_logs where vehicle_id='4a000000-0000-0000-0000-000000000001'
      or maintenance_record_id in (select id from public.maintenance_records where vehicle_id='4a000000-0000-0000-0000-000000000001');
    delete from public.alerts where vehicle_id='4a000000-0000-0000-0000-000000000001';
    delete from public.maintenance_records where vehicle_id='4a000000-0000-0000-0000-000000000001';
    update public.vehicles set mileage=1000,status='available' where id='4a000000-0000-0000-0000-000000000001';
    if with_record then
      insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service,next_service_date,next_service_mileage)
      values('5a000000-0000-0000-0000-000000000001','4a000000-0000-0000-0000-000000000001','Race service',current_date-1,1000,current_date+5,1500);
    end if;
    if with_alerts then perform * from public.reconcile_vehicle_maintenance_alerts('4a000000-0000-0000-0000-000000000001',null); end if;
  end $f$;
  create or replace function public.m2_race_reconcile() returns text language plpgsql security definer set search_path='' as $f$
  declare r record; begin select * into r from public.reconcile_vehicle_maintenance_alerts('4a000000-0000-0000-0000-000000000001',null); return r.created_count||':'||r.resolved_count||':'||r.updated_count; exception when others then return sqlstate||':'||sqlerrm; end $f$;
  create or replace function public.m2_race_create() returns text language plpgsql security definer set search_path='' as $f$
  begin perform public.create_maintenance_record('4a000000-0000-0000-0000-000000000001','Created race',current_date,1000,null,null,null,current_date+5,1500); return 'created'; exception when others then return sqlstate||':'||sqlerrm; end $f$;
  create or replace function public.m2_race_mileage() returns text language plpgsql security definer set search_path='' as $f$
  begin perform public.update_vehicle_mileage('4a000000-0000-0000-0000-000000000001',(select updated_at from public.vehicles where id='4a000000-0000-0000-0000-000000000001'),1600); return 'updated'; exception when others then return sqlstate||':'||sqlerrm; end $f$;
  create or replace function public.m2_race_edit() returns text language plpgsql security definer set search_path='' as $f$
  begin perform public.update_maintenance_record('5a000000-0000-0000-0000-000000000001',(select updated_at from public.maintenance_records where id='5a000000-0000-0000-0000-000000000001'),'Race service',current_date-1,1000,null,null,null,current_date+30,3000); return 'updated'; exception when others then return sqlstate||':'||sqlerrm; end $f$;
  create or replace function public.m2_race_archive() returns text language plpgsql security definer set search_path='' as $f$
  begin perform public.change_vehicle_operational_status('4a000000-0000-0000-0000-000000000001','archive'); return 'archived'; exception when others then return sqlstate||':'||sqlerrm; end $f$;
$setup$);
select extensions.dblink_connect('m2_a','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('m2_b','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

-- Two scheduled reconcilers serialize on Vehicle and create one lifecycle.
select extensions.dblink_exec('m2_setup','do $d$ begin perform public.m2_race_reset(true,false); end $d$');
select extensions.dblink_exec('m2_a',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select extensions.dblink_exec('m2_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('m2_a','select public.m2_race_reconcile()') r(result text)),'2:0:0','First reconciler creates both alerts');
select ok(extensions.dblink_send_query('m2_b','select public.m2_race_reconcile()')=1,'Second reconciler starts concurrently');
select pg_sleep(.1); select extensions.dblink_exec('m2_a','commit');
select is((select result from extensions.dblink_get_result('m2_b',false) r(result text)),'0:0:0','Second reconciler observes committed lifecycle');
select * from extensions.dblink_get_result('m2_b',false) as drained(result text); select extensions.dblink_exec('m2_b','commit');
select is((select count(*) from public.alerts where vehicle_id='4a000000-0000-0000-0000-000000000001' and alert_state='active'),2::bigint,'Concurrent creators leave one active alert per dimension');
select is((select count(*) from public.activity_logs where vehicle_id='4a000000-0000-0000-0000-000000000001' and action_type='alert_created'),2::bigint,'Concurrent creators emit one activity per dimension');

-- Maintenance creation versus scheduled reconciliation.
select extensions.dblink_exec('m2_setup','do $d$ begin perform public.m2_race_reset(false,false); end $d$');
select extensions.dblink_exec('m2_a',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='1a000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);
select extensions.dblink_exec('m2_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('m2_a','select public.m2_race_create()') r(result text)),'created','Maintenance create wins');
select ok(extensions.dblink_send_query('m2_b','select public.m2_race_reconcile()')=1,'Scheduled reconciliation overlaps create');
select pg_sleep(.1); select extensions.dblink_exec('m2_a','commit');
select is((select result from extensions.dblink_get_result('m2_b',false) r(result text)),'0:0:0','Scheduled reconciliation is idempotent after create');
select * from extensions.dblink_get_result('m2_b',false) as drained(result text); select extensions.dblink_exec('m2_b','commit');
select is((select count(*) from public.alerts where vehicle_id='4a000000-0000-0000-0000-000000000001' and alert_state='active'),2::bigint,'Create race leaves exact active set');
select is((select count(*) from public.activity_logs where vehicle_id='4a000000-0000-0000-0000-000000000001' and action_type='alert_created' and actor_profile_id='1a000000-0000-0000-0000-000000000001'),2::bigint,'Create race retains human attribution');

-- Mileage increase versus scheduled reconciliation.
select extensions.dblink_exec('m2_setup','do $d$ begin perform public.m2_race_reset(true,true); end $d$');
select extensions.dblink_exec('m2_a',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='1a000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);
select extensions.dblink_exec('m2_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('m2_a','select public.m2_race_mileage()') r(result text)),'updated','Mileage mutation wins');
select ok(extensions.dblink_send_query('m2_b','select public.m2_race_reconcile()')=1,'Scheduled reconciliation overlaps mileage update');
select pg_sleep(.1); select extensions.dblink_exec('m2_a','commit');
select is((select result from extensions.dblink_get_result('m2_b',false) r(result text)),'0:0:0','Scheduled reconciliation sees refreshed mileage copy');
select * from extensions.dblink_get_result('m2_b',false) as drained(result text); select extensions.dblink_exec('m2_b','commit');
select results_eq($$select message from public.alerts where vehicle_id='4a000000-0000-0000-0000-000000000001' and alert_type='maintenance_due_mileage' and alert_state='active'$$,$$values ('Vehicle maintenance is overdue by 100 km.'::text)$$,'Mileage race leaves exact overdue copy');
select is((select count(*) from public.activity_logs where vehicle_id='4a000000-0000-0000-0000-000000000001' and action_type in ('alert_created','alert_resolved')),2::bigint,'Mileage message refresh adds no lifecycle activity');

-- Maintenance edit resolution versus scheduled reconciliation.
select extensions.dblink_exec('m2_setup','do $d$ begin perform public.m2_race_reset(true,true); end $d$');
select extensions.dblink_exec('m2_a',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='1a000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);
select extensions.dblink_exec('m2_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('m2_a','select public.m2_race_edit()') r(result text)),'updated','Maintenance edit wins');
select ok(extensions.dblink_send_query('m2_b','select public.m2_race_reconcile()')=1,'Scheduled reconciliation overlaps edit');
select pg_sleep(.1); select extensions.dblink_exec('m2_a','commit');
select is((select result from extensions.dblink_get_result('m2_b',false) r(result text)),'0:0:0','Scheduled reconciliation cannot duplicate resolution');
select * from extensions.dblink_get_result('m2_b',false) as drained(result text); select extensions.dblink_exec('m2_b','commit');
select is((select count(*) from public.alerts where vehicle_id='4a000000-0000-0000-0000-000000000001' and alert_state='resolved'),2::bigint,'Edit race resolves exact alert history');
select is((select count(*) from public.activity_logs where vehicle_id='4a000000-0000-0000-0000-000000000001' and action_type='alert_resolved'),2::bigint,'Edit race emits exact resolution activities');

-- Vehicle lifecycle serializes without suppressing alerts.
select extensions.dblink_exec('m2_setup','do $d$ begin perform public.m2_race_reset(true,false); end $d$');
select extensions.dblink_exec('m2_a',$$begin;set local role authenticated;set local "request.jwt.claim.sub"='1a000000-0000-0000-0000-000000000001';set local lock_timeout='2s';set local statement_timeout='8s'$$);
select extensions.dblink_exec('m2_b',$$begin;set local role service_role;set local lock_timeout='2s';set local statement_timeout='8s'$$);
select is((select result from extensions.dblink('m2_a','select public.m2_race_archive()') r(result text)),'archived','Vehicle lifecycle wins');
select ok(extensions.dblink_send_query('m2_b','select public.m2_race_reconcile()')=1,'Reconciliation overlaps Vehicle lifecycle');
select pg_sleep(.1); select extensions.dblink_exec('m2_a','commit');
select is((select result from extensions.dblink_get_result('m2_b',false) r(result text)),'2:0:0','Reconciliation evaluates archived Vehicle');
select * from extensions.dblink_get_result('m2_b',false) as drained(result text); select extensions.dblink_exec('m2_b','commit');
select results_eq($$select status from public.vehicles where id='4a000000-0000-0000-0000-000000000001'$$,$$values ('archived'::public.vehicle_status)$$,'Reconciliation preserves lifecycle result');
select is((select count(*) from public.alerts where vehicle_id='4a000000-0000-0000-0000-000000000001' and alert_state='active'),2::bigint,'Archived Vehicle retains applicable alerts');
select ok(position('deadlock detected' in coalesce(extensions.dblink_error_message('m2_a'),''))=0,'Session A reports no deadlock');
select ok(position('deadlock detected' in coalesce(extensions.dblink_error_message('m2_b'),''))=0,'Session B reports no deadlock');

select extensions.dblink_exec('m2_setup',$cleanup$
  do $d$ begin perform public.m2_race_reset(false,false); end $d$;
  drop function public.m2_race_archive(); drop function public.m2_race_edit(); drop function public.m2_race_mileage();
  drop function public.m2_race_create(); drop function public.m2_race_reconcile(); drop function public.m2_race_reset(boolean,boolean);
  delete from public.vehicles where id='4a000000-0000-0000-0000-000000000001';
  delete from public.profiles where id='1a000000-0000-0000-0000-000000000001';
  delete from auth.users where id='1a000000-0000-0000-0000-000000000001';
$cleanup$);
select extensions.dblink_disconnect('m2_a'); select extensions.dblink_disconnect('m2_b'); select extensions.dblink_disconnect('m2_setup');
select * from finish();
rollback;
