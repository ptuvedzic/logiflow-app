begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

select extensions.dblink_connect('f1_setup','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('f1_a','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('f1_b','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('f1_setup',$setup$
  insert into auth.users(id) values ('19200000-0000-0000-0000-000000000001') on conflict do nothing;
  insert into public.profiles(id,full_name,username,role,is_active) values ('19200000-0000-0000-0000-000000000001','F1 Race Admin','f1-race-admin','admin',true) on conflict do nothing;
  insert into public.clients(id,company_name) values ('19300000-0000-0000-0000-000000000002','F1 Race Client') on conflict do nothing;
  insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price,status)
  values ('19500000-0000-0000-0000-000000000003','SHP-F1-RACE','19300000-0000-0000-0000-000000000002','A','B',now(),now(),'Cargo',100,'pending') on conflict do nothing;
  delete from public.activity_logs where expense_id='19600000-0000-0000-0000-000000000001';
  delete from public.expenses where id='19600000-0000-0000-0000-000000000001';
  insert into public.expenses(id,shipment_id,created_by_profile_id,category,amount,expense_date)
  values ('19600000-0000-0000-0000-000000000001','19500000-0000-0000-0000-000000000003','19200000-0000-0000-0000-000000000001','fuel',10,current_date);
  create or replace function public.f1_capture_update(target_id uuid, new_amount numeric) returns text language plpgsql security definer set search_path='' as $fn$
  declare expected timestamptz; begin
    select updated_at into expected from public.expenses where id=target_id;
    perform public.update_shipment_expense(target_id,'19500000-0000-0000-0000-000000000003',expected,'fuel',new_amount,current_date,null);
    return 'updated';
  exception when others then return sqlstate||':'||sqlerrm; end $fn$;
$setup$);

select extensions.dblink_exec('f1_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''19200000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('f1_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''19200000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('f1_a',$q$select public.f1_capture_update('19600000-0000-0000-0000-000000000001',20)$q$)=1,'First expense edit starts');
select pg_sleep(.1);
select ok(extensions.dblink_send_query('f1_b',$q$select public.f1_capture_update('19600000-0000-0000-0000-000000000001',30)$q$)=1,'Competing expense edit starts');
create temporary table f1_result_a(result text); insert into f1_result_a select result from extensions.dblink_get_result('f1_a',false) r(result text);
select is((select result from f1_result_a),'updated','First expense edit succeeds');
select * from extensions.dblink_get_result('f1_a',false) as drained(result text);
select extensions.dblink_exec('f1_a','commit');
create temporary table f1_result_b(result text); insert into f1_result_b select result from extensions.dblink_get_result('f1_b',false) r(result text);
select is((select result from f1_result_b),'40001:expense_stale','Competing expense edit fails stale after serialization');
select * from extensions.dblink_get_result('f1_b',false) as drained(result text);
select extensions.dblink_exec('f1_b','rollback');

select is((select amount from public.expenses where id='19600000-0000-0000-0000-000000000001'),20::numeric,'Concurrent loser does not overwrite the winner');
select is((select count(*) from public.activity_logs where expense_id='19600000-0000-0000-0000-000000000001' and action_type='expense_updated'),1::bigint,'Only the successful concurrent edit writes activity');
select is((select created_by_profile_id from public.expenses where id='19600000-0000-0000-0000-000000000001'),'19200000-0000-0000-0000-000000000001'::uuid,'Concurrent edit preserves creator');
select ok(position('for update' in lower(pg_get_functiondef('public.update_shipment_expense(uuid,uuid,timestamptz,public.expense_category,numeric,date,text)'::regprocedure)))>0,'Expense update locks before optimistic revalidation');

select extensions.dblink_disconnect('f1_a');
select extensions.dblink_disconnect('f1_b');
select extensions.dblink_exec('f1_setup',$cleanup$
  delete from public.activity_logs where expense_id='19600000-0000-0000-0000-000000000001';
  delete from public.expenses where id='19600000-0000-0000-0000-000000000001';
  delete from public.shipments where id='19500000-0000-0000-0000-000000000003';
  delete from public.clients where id='19300000-0000-0000-0000-000000000002';
  drop function if exists public.f1_capture_update(uuid,numeric);
  delete from public.profiles where id='19200000-0000-0000-0000-000000000001';
  delete from auth.users where id='19200000-0000-0000-0000-000000000001';
$cleanup$);
select extensions.dblink_disconnect('f1_setup');

select * from finish();
rollback;
