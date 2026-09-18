begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select plan(14);

select extensions.dblink_connect('s6a_setup', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('s6a_a', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('s6a_b', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

select extensions.dblink_exec('s6a_setup', $setup$
  delete from public.notifications where recipient_profile_id='e1000000-0000-0000-0000-000000000001';
  delete from public.profiles where id='e1000000-0000-0000-0000-000000000001';
  delete from auth.users where id='e1000000-0000-0000-0000-000000000001';
  insert into auth.users(id) values ('e1000000-0000-0000-0000-000000000001');
  insert into public.profiles(id,full_name,username,role,is_active) values ('e1000000-0000-0000-0000-000000000001','S6A Concurrent Dispatcher','s6a-concurrent','dispatcher',true);
  insert into public.notifications(id,recipient_profile_id,notification_type,title,message,created_at) values
    ('e6000000-0000-0000-0000-000000000001','e1000000-0000-0000-0000-000000000001','status_approval_requested','Concurrent A','A','2026-01-13T08:00:00Z'),
    ('e6000000-0000-0000-0000-000000000002','e1000000-0000-0000-0000-000000000001','status_approval_requested','Concurrent B','B','2026-01-13T08:01:00Z'),
    ('e6000000-0000-0000-0000-000000000003','e1000000-0000-0000-0000-000000000001','status_approval_requested','Concurrent C','C','2026-01-13T08:02:00Z');
$setup$);

select extensions.dblink_exec('s6a_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''e1000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('s6a_b', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''e1000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('s6a_a', $$select public.acknowledge_notification('e6000000-0000-0000-0000-000000000001')::text$$) = 1, 'First acknowledgement starts');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s6a_b', $$select public.acknowledge_notification('e6000000-0000-0000-0000-000000000001')::text$$) = 1, 'Competing acknowledgement starts');
create temporary table s6a_first_result(result text);
insert into s6a_first_result select result from extensions.dblink_get_result('s6a_a', false) as r(result text);
select * from extensions.dblink_get_result('s6a_a', false) as r(result text);
select extensions.dblink_exec('s6a_a', 'commit');
create temporary table s6a_second_result(result text);
insert into s6a_second_result select result from extensions.dblink_get_result('s6a_b', false) as r(result text);
select * from extensions.dblink_get_result('s6a_b', false) as r(result text);
select extensions.dblink_exec('s6a_b', 'commit');
select ok((select result::timestamptz = n.read_at from s6a_first_result cross join public.notifications n where n.id='e6000000-0000-0000-0000-000000000001'), 'First acknowledgement returns the final timestamp');
select ok((select result::timestamptz = n.read_at from s6a_second_result cross join public.notifications n where n.id='e6000000-0000-0000-0000-000000000001'), 'Both acknowledgements preserve the same final timestamp');
select is((select count(*) from public.notifications where id='e6000000-0000-0000-0000-000000000001' and read_at is not null), 1::bigint, 'Exactly one notification has one established read timestamp');
select is((select count(*) from public.activity_logs where actor_profile_id='e1000000-0000-0000-0000-000000000001'), 0::bigint, 'Concurrent acknowledgements create no activity');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6a_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6a_b'))=0, 'Acknowledgement race has no deadlock');

select extensions.dblink_exec('s6a_setup', $$update public.profiles set is_active=false where id='e1000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('s6a_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''e1000000-0000-0000-0000-000000000001''');
select results_eq($query$select result from extensions.dblink('s6a_a', $$select public.acknowledge_notification('e6000000-0000-0000-0000-000000000002')::text$$) as r(result text)$query$, $$values (null::text)$$, 'Deactivation winning first denies acknowledgement');
select extensions.dblink_exec('s6a_a', 'rollback');
select is((select read_at from public.notifications where id='e6000000-0000-0000-0000-000000000002'), null, 'Deactivation-first leaves read_at unchanged');

select extensions.dblink_exec('s6a_setup', $$update public.profiles set is_active=true where id='e1000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('s6a_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''e1000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('s6a_b', 'begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select ok(extensions.dblink_send_query('s6a_a', $$select public.acknowledge_notification('e6000000-0000-0000-0000-000000000003')::text$$)=1, 'Acknowledgement takes Profile lock first');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('s6a_b', $$update public.profiles set is_active=false where id='e1000000-0000-0000-0000-000000000001' returning is_active::text$$)=1, 'Deactivation competes for Profile lock');
select * from extensions.dblink_get_result('s6a_a', false) as r(result text);
select * from extensions.dblink_get_result('s6a_a', false) as r(result text);
select extensions.dblink_exec('s6a_a', 'commit');
select * from extensions.dblink_get_result('s6a_b', false) as r(result text);
select * from extensions.dblink_get_result('s6a_b', false) as r(result text);
select extensions.dblink_exec('s6a_b', 'commit');
select ok((select not is_active from public.profiles where id='e1000000-0000-0000-0000-000000000001') and (select read_at is not null from public.notifications where id='e6000000-0000-0000-0000-000000000003'), 'Profile-first race serializes acknowledgement before deactivation');
select ok(position('deadlock detected' in extensions.dblink_error_message('s6a_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('s6a_b'))=0, 'Profile-first race has no deadlock');
select is((select count(*) from public.alerts), 0::bigint, 'All concurrency cases create no alert side effect');

select extensions.dblink_disconnect('s6a_a');
select extensions.dblink_disconnect('s6a_b');
select extensions.dblink_exec('s6a_setup', $$delete from public.notifications where recipient_profile_id='e1000000-0000-0000-0000-000000000001'; delete from public.profiles where id='e1000000-0000-0000-0000-000000000001'; delete from auth.users where id='e1000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_disconnect('s6a_setup');
select * from finish();
rollback;
