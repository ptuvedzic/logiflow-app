begin;

create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select no_plan();

select extensions.dblink_connect('s6b_setup', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('s6b_a', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('s6b_b', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

select extensions.dblink_exec('s6b_setup', $setup$
  drop trigger if exists s6b_test_notification_failure on public.notifications;
  drop function if exists public.s6b_test_fail_notification();
  drop function if exists public.s6b_test_try_send(uuid,uuid,text);
  create or replace function public.s6b_test_try_send(target_driver uuid, target_shipment uuid, body text)
  returns text language plpgsql security invoker set search_path='' as $fn$
  begin
    perform * from public.send_driver_message(target_driver, target_shipment, body);
    return 'sent';
  exception when others then
    return sqlerrm;
  end;
  $fn$;
  grant execute on function public.s6b_test_try_send(uuid,uuid,text) to authenticated;
  create function public.s6b_test_fail_notification() returns trigger language plpgsql set search_path='' as $fn$
  begin
    if pg_catalog.current_setting('s6b.force_notification_failure', true) = 'on' then
      raise exception 's6b_forced_notification_failure';
    end if;
    return new;
  end;
  $fn$;
  create trigger s6b_test_notification_failure before insert on public.notifications
  for each row when (new.notification_type='new_dispatcher_message')
  execute function public.s6b_test_fail_notification();

  delete from public.notifications where recipient_profile_id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002');
  delete from public.messages where sender_profile_id in ('a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000004');
  delete from public.shipments where id='a5000000-0000-0000-0000-000000000001';
  delete from public.vehicles where id='a4000000-0000-0000-0000-000000000001';
  delete from public.clients where id='a3000000-0000-0000-0000-000000000001';
  delete from public.drivers where id in ('a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002');
  delete from public.profiles where id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000004');
  delete from auth.users where id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000004');
  insert into auth.users(id) values
    ('a1000000-0000-0000-0000-000000000001'),('a1000000-0000-0000-0000-000000000002'),
    ('a1000000-0000-0000-0000-000000000003'),('a1000000-0000-0000-0000-000000000004');
  insert into public.profiles(id,full_name,username,role,is_active) values
    ('a1000000-0000-0000-0000-000000000001','S6B Race Driver Low','s6b-race-driver-low','driver',true),
    ('a1000000-0000-0000-0000-000000000002','S6B Race Driver High','s6b-race-driver-high','driver',true),
    ('a1000000-0000-0000-0000-000000000003','S6B Race Dispatcher','s6b-race-dispatcher','dispatcher',true),
    ('a1000000-0000-0000-0000-000000000004','S6B Race Admin','s6b-race-admin','admin',true);
  insert into public.drivers(id,profile_id,status) values
    ('a2000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000001','available'),
    ('a2000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000002','available');
  insert into public.clients(id,company_name) values ('a3000000-0000-0000-0000-000000000001','S6B Race Client');
  insert into public.vehicles(id,registration,make,model,vehicle_type,status) values ('a4000000-0000-0000-0000-000000000001','S6B-RACE','Make','Model','Truck','in_use');
  insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status)
  values ('a5000000-0000-0000-0000-000000000001','S6B-RACE-SHIP','a3000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo','a2000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000001',1,'assigned');
$setup$);

-- Final-slot race: nine committed sends, then two sessions compete.
select extensions.dblink_exec('s6b_setup', $$
  insert into public.messages(id,sender_profile_id,recipient_driver_id,body,sent_at)
  select gen_random_uuid(),'a1000000-0000-0000-0000-000000000003','a2000000-0000-0000-0000-000000000001','Seed '||value,transaction_timestamp()
  from generate_series(1,9) value
$$);
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s6b_b', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select ok(extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000001',null,'Final A')$$)=1, 'First final-slot send starts');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s6b_b', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000001',null,'Final B')$$)=1, 'Second final-slot send starts');
create temporary table final_a(result text);
insert into final_a select result from extensions.dblink_get_result('s6b_a',false) as r(result text);
select * from extensions.dblink_get_result('s6b_a',false) as r(result text);
select extensions.dblink_exec('s6b_a','commit');
create temporary table final_b(result text);
insert into final_b select result from extensions.dblink_get_result('s6b_b',false) as r(result text);
select * from extensions.dblink_get_result('s6b_b',false) as r(result text);
select extensions.dblink_exec('s6b_b','commit');
select is((select result from final_a),'sent','One final-slot contender succeeds');
select is((select result from final_b),'message_send_rate_limited','One final-slot contender is rate limited');
select is((select count(*) from public.messages where sender_profile_id='a1000000-0000-0000-0000-000000000003' and sent_at>=transaction_timestamp()-interval '10 minutes'),10::bigint,'Final rolling count is ten');
select is((select count(*) from public.messages where body in ('Final A','Final B')),1::bigint,'Competing pair creates one message');
select is((select count(*) from public.notifications where recipient_profile_id='a1000000-0000-0000-0000-000000000001'),1::bigint,'Competing pair creates one notification');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6b_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6b_b'))=0,'Final-slot race has no deadlock');

-- Expired sends do not count; below-limit simultaneous sends both commit.
select extensions.dblink_exec('s6b_setup', $$delete from public.notifications where recipient_profile_id='a1000000-0000-0000-0000-000000000002'; delete from public.messages where sender_profile_id='a1000000-0000-0000-0000-000000000004'; insert into public.messages(id,sender_profile_id,recipient_driver_id,body,sent_at) select gen_random_uuid(),'a1000000-0000-0000-0000-000000000004','a2000000-0000-0000-0000-000000000002','Expired '||value,transaction_timestamp()-interval '11 minutes' from generate_series(1,10) value$$);
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000004''');
select extensions.dblink_exec('s6b_b', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000004''');
select extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000002',null,'Below A')$$);
select pg_sleep(0.1);
select extensions.dblink_send_query('s6b_b', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000002',null,'Below B')$$);
create temporary table below_a(result text); insert into below_a select result from extensions.dblink_get_result('s6b_a',false) as r(result text); select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select extensions.dblink_exec('s6b_a','commit');
create temporary table below_b(result text); insert into below_b select result from extensions.dblink_get_result('s6b_b',false) as r(result text); select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select extensions.dblink_exec('s6b_b','commit');
select is((select result from below_a),'sent','First below-limit send commits');
select is((select result from below_b),'sent','Second below-limit send commits');
select is((select count(*) from public.messages where body in ('Below A','Below B')),2::bigint,'Below-limit race creates two messages');
select is((select count(*) from public.notifications where recipient_profile_id='a1000000-0000-0000-0000-000000000002'),2::bigint,'Below-limit race creates two notifications');
select is((select count(*) from public.messages where sender_profile_id='a1000000-0000-0000-0000-000000000004' and sent_at>=transaction_timestamp()-interval '10 minutes'),2::bigint,'Expired sends consume no current capacity');

-- Notification failure rolls back the message and capacity reservation.
create temporary table failure_before as
select count(*)::bigint as notification_count
from public.notifications
where recipient_profile_id='a1000000-0000-0000-0000-000000000002';
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000004''; set local s6b.force_notification_failure=''on''');
select ok(extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000002',null,'Must rollback')$$)=1,'Notification-failure send starts');
create temporary table failed_send(result text);
insert into failed_send select result from extensions.dblink_get_result('s6b_a',false) as r(result text);
select * from extensions.dblink_get_result('s6b_a',false) as r(result text);
select is((select result from failed_send),'s6b_forced_notification_failure','Notification failure is returned by the test wrapper');
select extensions.dblink_exec('s6b_a','rollback');
select is((select count(*) from public.messages where body='Must rollback'),0::bigint,'Notification failure rolls back message');
select is((select count(*) from public.notifications where recipient_profile_id='a1000000-0000-0000-0000-000000000002'),(select notification_count from failure_before),'Notification failure leaves notification cardinality unchanged');
select is((select count(*) from public.messages where sender_profile_id='a1000000-0000-0000-0000-000000000004' and sent_at>=transaction_timestamp()-interval '10 minutes'),2::bigint,'Failed transaction consumes no capacity');

-- Profile/Driver/Shipment ordering races: send wins, lifecycle mutation waits, both commit consistently.
select extensions.dblink_exec('s6b_setup', $$delete from public.notifications where recipient_profile_id='a1000000-0000-0000-0000-000000000001'; delete from public.messages where sender_profile_id='a1000000-0000-0000-0000-000000000003'$$);
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s6b_b', 'begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','Before recipient deactivation')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('s6b_b', $$update public.profiles set is_active=false where id='a1000000-0000-0000-0000-000000000001' returning is_active::text$$);
select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select extensions.dblink_exec('s6b_a','commit');
select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select extensions.dblink_exec('s6b_b','commit');
select ok((select not is_active from public.profiles where id='a1000000-0000-0000-0000-000000000001') and exists(select 1 from public.messages where body='Before recipient deactivation'),'Send and recipient deactivation serialize consistently');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6b_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6b_b'))=0,'Recipient deactivation race has no deadlock');

select extensions.dblink_exec('s6b_setup', $$update public.profiles set is_active=true where id='a1000000-0000-0000-0000-000000000001'; update public.drivers set status='available' where id='a2000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s6b_b', 'begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000001',null,'Before Driver inactive')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('s6b_b', $$update public.drivers set status='inactive' where id='a2000000-0000-0000-0000-000000000001' returning status::text$$);
select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select extensions.dblink_exec('s6b_a','commit');
select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select extensions.dblink_exec('s6b_b','commit');
select ok((select status='inactive' from public.drivers where id='a2000000-0000-0000-0000-000000000001') and exists(select 1 from public.messages where body='Before Driver inactive'),'Send and Driver lifecycle serialize consistently');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6b_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6b_b'))=0,'Driver lifecycle race has no deadlock');

select extensions.dblink_exec('s6b_setup', $$update public.drivers set status='available' where id='a2000000-0000-0000-0000-000000000001'; update public.profiles set is_active=true where id='a1000000-0000-0000-0000-000000000003'$$);
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s6b_b', 'begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-000000000001','Before Shipment unlink')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('s6b_b', $$update public.shipments set status='cancelled',driver_id=null,vehicle_id=null where id='a5000000-0000-0000-0000-000000000001' returning status::text$$);
select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select extensions.dblink_exec('s6b_a','commit');
select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select extensions.dblink_exec('s6b_b','commit');
select ok((select driver_id is null from public.shipments where id='a5000000-0000-0000-0000-000000000001') and exists(select 1 from public.messages where body='Before Shipment unlink'),'Linked send and Shipment relationship mutation serialize consistently');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6b_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6b_b'))=0,'Shipment relationship race has no deadlock');

-- Sender deactivation waits on the same sender Profile mutex.
select extensions.dblink_exec('s6b_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''a1000000-0000-0000-0000-000000000003''');
select extensions.dblink_exec('s6b_b', 'begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select extensions.dblink_send_query('s6b_a', $$select public.s6b_test_try_send('a2000000-0000-0000-0000-000000000002',null,'Before sender deactivation')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('s6b_b', $$update public.profiles set is_active=false where id='a1000000-0000-0000-0000-000000000003' returning is_active::text$$);
select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select * from extensions.dblink_get_result('s6b_a',false) as r(result text); select extensions.dblink_exec('s6b_a','commit');
select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select * from extensions.dblink_get_result('s6b_b',false) as r(result text); select extensions.dblink_exec('s6b_b','commit');
select ok((select not is_active from public.profiles where id='a1000000-0000-0000-0000-000000000003') and exists(select 1 from public.messages where body='Before sender deactivation'),'Send and sender deactivation serialize consistently');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6b_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6b_b'))=0,'Sender deactivation race has no deadlock');

select * from finish();
rollback;

drop trigger s6b_test_notification_failure on public.notifications;
drop function public.s6b_test_fail_notification();
drop function public.s6b_test_try_send(uuid,uuid,text);
delete from public.notifications where recipient_profile_id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002');
delete from public.messages where sender_profile_id in ('a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000004');
delete from public.shipments where id='a5000000-0000-0000-0000-000000000001';
delete from public.vehicles where id='a4000000-0000-0000-0000-000000000001';
delete from public.clients where id='a3000000-0000-0000-0000-000000000001';
delete from public.drivers where id in ('a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002');
delete from public.profiles where id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000004');
delete from auth.users where id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-000000000003','a1000000-0000-0000-0000-000000000004');
