begin;

create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select plan(21);

select extensions.dblink_connect('n1_setup', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('n1_driver_a', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('n1_driver_b', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('n1_operations', 'host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');

select extensions.dblink_exec('n1_setup', $setup$
  delete from public.notifications where recipient_profile_id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002');
  delete from public.drivers where profile_id='fa000000-0000-0000-0000-000000000001';
  delete from public.profiles where id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002');
  delete from auth.users where id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002');
  insert into auth.users(id) values ('fa000000-0000-0000-0000-000000000001'),('fa000000-0000-0000-0000-000000000002');
  insert into public.profiles(id,full_name,username,role,is_active) values
    ('fa000000-0000-0000-0000-000000000001','N1 Concurrent Driver','n1-concurrent-driver','driver',true),
    ('fa000000-0000-0000-0000-000000000002','N1 Concurrent Dispatcher','n1-concurrent-dispatcher','dispatcher',true);
  insert into public.drivers(id,profile_id,status) values ('fb000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000001','available');
  insert into public.notifications(id,recipient_profile_id,notification_type,title,message,created_at) values
    ('fc000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000001','shipment_assigned','Driver race A','A','2026-09-12T08:00:00Z'),
    ('fc000000-0000-0000-0000-000000000002','fa000000-0000-0000-0000-000000000001','shipment_assigned','Driver race B','B','2026-09-12T08:01:00Z'),
    ('fc000000-0000-0000-0000-000000000003','fa000000-0000-0000-0000-000000000001','shipment_assigned','Driver race C','C','2026-09-12T08:02:00Z'),
    ('fc000000-0000-0000-0000-000000000004','fa000000-0000-0000-0000-000000000001','shipment_assigned','Driver independent','D','2026-09-12T08:03:00Z'),
    ('fc000000-0000-0000-0000-000000000005','fa000000-0000-0000-0000-000000000002','status_approval_requested','Operations independent','E','2026-09-12T08:04:00Z');
$setup$);

select extensions.dblink_exec('n1_driver_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''fa000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('n1_driver_b', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''fa000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('n1_driver_a', $$select public.acknowledge_notification('fc000000-0000-0000-0000-000000000001')::text$$)=1, 'First Driver acknowledgement starts');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('n1_driver_b', $$select public.acknowledge_notification('fc000000-0000-0000-0000-000000000001')::text$$)=1, 'Competing Driver acknowledgement starts');
create temporary table n1_first_result(result text);
insert into n1_first_result select result from extensions.dblink_get_result('n1_driver_a', false) as r(result text);
select * from extensions.dblink_get_result('n1_driver_a', false) as r(result text);
select extensions.dblink_exec('n1_driver_a', 'commit');
create temporary table n1_second_result(result text);
insert into n1_second_result select result from extensions.dblink_get_result('n1_driver_b', false) as r(result text);
select * from extensions.dblink_get_result('n1_driver_b', false) as r(result text);
select extensions.dblink_exec('n1_driver_b', 'commit');
select ok((select result::timestamptz = n.read_at from n1_first_result cross join public.notifications n where n.id='fc000000-0000-0000-0000-000000000001'), 'First acknowledgement returns final timestamp');
select ok((select result::timestamptz = n.read_at from n1_second_result cross join public.notifications n where n.id='fc000000-0000-0000-0000-000000000001'), 'Both acknowledgements preserve one timestamp');
select is((select count(*) from public.notifications where id='fc000000-0000-0000-0000-000000000001' and read_at is not null), 1::bigint, 'Acknowledgement race establishes one read timestamp');
select ok(position('deadlock detected' in extensions.dblink_error_message('n1_driver_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('n1_driver_b'))=0, 'Acknowledgement race has no deadlock');

select extensions.dblink_exec('n1_setup', $$update public.profiles set is_active=false where id='fa000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('n1_driver_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''fa000000-0000-0000-0000-000000000001''');
select results_eq($query$select result from extensions.dblink('n1_driver_a', $$select public.acknowledge_notification('fc000000-0000-0000-0000-000000000002')::text$$) as r(result text)$query$, $$values (null::text)$$, 'Deactivation committed first denies Driver acknowledgement');
select extensions.dblink_exec('n1_driver_a', 'rollback');
select is((select read_at from public.notifications where id='fc000000-0000-0000-0000-000000000002'), null, 'Deactivation-first leaves read_at unchanged');

select extensions.dblink_exec('n1_setup', $$update public.profiles set is_active=true where id='fa000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('n1_driver_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''fa000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('n1_driver_b', 'begin; set local lock_timeout=''5s''; set local statement_timeout=''10s''');
select ok(extensions.dblink_send_query('n1_driver_a', $$select public.acknowledge_notification('fc000000-0000-0000-0000-000000000003')::text$$)=1, 'Driver acknowledgement takes Profile lock first');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('n1_driver_b', $$update public.profiles set is_active=false where id='fa000000-0000-0000-0000-000000000001' returning is_active::text$$)=1, 'Deactivation competes for the Profile lock');
select * from extensions.dblink_get_result('n1_driver_a', false) as r(result text);
select * from extensions.dblink_get_result('n1_driver_a', false) as r(result text);
select extensions.dblink_exec('n1_driver_a', 'commit');
select * from extensions.dblink_get_result('n1_driver_b', false) as r(result text);
select * from extensions.dblink_get_result('n1_driver_b', false) as r(result text);
select extensions.dblink_exec('n1_driver_b', 'commit');
select ok((select not is_active from public.profiles where id='fa000000-0000-0000-0000-000000000001') and (select read_at is not null from public.notifications where id='fc000000-0000-0000-0000-000000000003'), 'Profile-first race serializes acknowledgement before deactivation');
select ok(position('deadlock detected' in extensions.dblink_error_message('n1_driver_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('n1_driver_b'))=0, 'Profile-first race has no deadlock');

select extensions.dblink_exec('n1_setup', $$update public.profiles set is_active=true where id='fa000000-0000-0000-0000-000000000001'$$);
select extensions.dblink_exec('n1_driver_a', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''fa000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('n1_operations', 'begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''fa000000-0000-0000-0000-000000000002''');
select ok(extensions.dblink_send_query('n1_driver_a', $$select public.acknowledge_notification('fc000000-0000-0000-0000-000000000004')::text$$)=1, 'Driver independent acknowledgement starts');
select ok(extensions.dblink_send_query('n1_operations', $$select public.acknowledge_notification('fc000000-0000-0000-0000-000000000005')::text$$)=1, 'Operations independent acknowledgement starts');
select * from extensions.dblink_get_result('n1_driver_a', false) as r(result text);
select * from extensions.dblink_get_result('n1_driver_a', false) as r(result text);
select * from extensions.dblink_get_result('n1_operations', false) as r(result text);
select * from extensions.dblink_get_result('n1_operations', false) as r(result text);
select extensions.dblink_exec('n1_driver_a', 'commit');
select extensions.dblink_exec('n1_operations', 'commit');
select is((select count(*) from public.notifications where id in ('fc000000-0000-0000-0000-000000000004','fc000000-0000-0000-0000-000000000005') and read_at is not null), 2::bigint, 'Driver and Operations acknowledge different notifications independently');
select ok(position('deadlock detected' in extensions.dblink_error_message('n1_driver_a'))=0 and position('deadlock detected' in extensions.dblink_error_message('n1_operations'))=0, 'Cross-role independent acknowledgements have no deadlock');

select results_eq($query$select result from extensions.dblink('n1_driver_a', 'select public.acknowledge_notification(''fc000000-0000-0000-0000-000000000005'')::text') as r(result text)$query$, $$values (null::text)$$, 'Driver cannot acknowledge Operations notification');
select results_eq($query$select result from extensions.dblink('n1_operations', 'select public.acknowledge_notification(''fc000000-0000-0000-0000-000000000004'')::text') as r(result text)$query$, $$values (null::text)$$, 'Operations cannot acknowledge Driver notification');
select is((select count(*) from public.activity_logs where actor_profile_id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002')), 0::bigint, 'Concurrency cases create no activity');
select is((select count(*) from public.alerts), 0::bigint, 'Concurrency cases create no alert');
select is((select count(*) from public.notifications where recipient_profile_id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002')), 5::bigint, 'Concurrency cases create no notification');

select extensions.dblink_disconnect('n1_driver_a');
select extensions.dblink_disconnect('n1_driver_b');
select extensions.dblink_disconnect('n1_operations');
select extensions.dblink_exec('n1_setup', $$delete from public.notifications where recipient_profile_id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002'); delete from public.drivers where profile_id='fa000000-0000-0000-0000-000000000001'; delete from public.profiles where id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002'); delete from auth.users where id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002')$$);
select extensions.dblink_disconnect('n1_setup');

select * from finish();
rollback;
