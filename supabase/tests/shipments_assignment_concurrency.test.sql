begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
select plan(39);

select extensions.dblink_connect('setup','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('setup',$setup$
  insert into auth.users(id) select ('81000000-0000-0000-0000-' || lpad(value::text,12,'0'))::uuid from generate_series(1,9) value;
  insert into public.profiles(id,full_name,username,role,is_active) values
    ('81000000-0000-0000-0000-000000000001','Race Admin','race-admin','admin',true),
    ('81000000-0000-0000-0000-000000000002','Race Driver A','race-driver-a','driver',true),
    ('81000000-0000-0000-0000-000000000003','Race Driver B','race-driver-b','driver',true),
    ('81000000-0000-0000-0000-000000000004','Race Driver C','race-driver-c','driver',true),
    ('81000000-0000-0000-0000-000000000005','Race Driver D','race-driver-d','driver',true),
    ('81000000-0000-0000-0000-000000000006','Race Driver E','race-driver-e','driver',true),
    ('81000000-0000-0000-0000-000000000007','Race Driver F','race-driver-f','driver',true),
    ('81000000-0000-0000-0000-000000000008','Race Driver G','race-driver-g','driver',true),
    ('81000000-0000-0000-0000-000000000009','Race Driver H','race-driver-h','driver',true);
  insert into public.drivers(id,profile_id,status) values
    ('82000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000002','available'),
    ('82000000-0000-0000-0000-000000000002','81000000-0000-0000-0000-000000000003','available'),
    ('82000000-0000-0000-0000-000000000003','81000000-0000-0000-0000-000000000004','available'),
    ('82000000-0000-0000-0000-000000000004','81000000-0000-0000-0000-000000000005','available'),
    ('82000000-0000-0000-0000-000000000005','81000000-0000-0000-0000-000000000006','available'),
    ('82000000-0000-0000-0000-000000000006','81000000-0000-0000-0000-000000000007','available'),
    ('82000000-0000-0000-0000-000000000007','81000000-0000-0000-0000-000000000008','available'),
    ('82000000-0000-0000-0000-000000000008','81000000-0000-0000-0000-000000000009','available');
  insert into public.clients(id,company_name,status) values
    ('83000000-0000-0000-0000-000000000001','Race Client A','active'),
    ('83000000-0000-0000-0000-000000000002','Race Client B','active'),
    ('83000000-0000-0000-0000-000000000003','Race Client C','active'),
    ('83000000-0000-0000-0000-000000000004','Race Client D','active'),
    ('83000000-0000-0000-0000-000000000005','Race Client E','active'),
    ('83000000-0000-0000-0000-000000000006','Race Client F','active');
  insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
    ('84000000-0000-0000-0000-000000000001','RACE-1','Make','One','Truck','available'),
    ('84000000-0000-0000-0000-000000000002','RACE-2','Make','Two','Truck','available'),
    ('84000000-0000-0000-0000-000000000003','RACE-3','Make','Three','Truck','available'),
    ('84000000-0000-0000-0000-000000000004','RACE-4','Make','Four','Truck','available'),
    ('84000000-0000-0000-0000-000000000005','RACE-5','Make','Five','Truck','available'),
    ('84000000-0000-0000-0000-000000000006','RACE-6','Make','Six','Truck','available'),
    ('84000000-0000-0000-0000-000000000007','RACE-7','Make','Seven','Truck','available'),
    ('84000000-0000-0000-0000-000000000008','RACE-8','Make','Eight','Truck','available');
  insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price) values
    ('85000000-0000-0000-0000-000000000001','RACE-SAME','83000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000002','RACE-DRIVER','83000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000003','RACE-DRIVER-B','83000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000004','RACE-VEHICLE-A','83000000-0000-0000-0000-000000000002','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000005','RACE-VEHICLE-B','83000000-0000-0000-0000-000000000002','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000006','RACE-CLIENT','83000000-0000-0000-0000-000000000003','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000007','RACE-DRIVER-LIFE','83000000-0000-0000-0000-000000000004','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000008','RACE-ACCOUNT','83000000-0000-0000-0000-000000000005','A','B',now(),now(),'Cargo',1),
    ('85000000-0000-0000-0000-000000000009','RACE-VEHICLE-LIFE','83000000-0000-0000-0000-000000000006','A','B',now(),now(),'Cargo',1);
$setup$);

select extensions.dblink_connect('race_a','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_connect('race_b','host=host.docker.internal port=54322 dbname=postgres user=postgres password=postgres');
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000001')$$)=1,'First same-Shipment assignment started');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('race_b',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-000000000002','84000000-0000-0000-0000-000000000002')$$)=1,'Competing same-Shipment assignment started');
select * from extensions.dblink_get_result('race_a',false) as result(id uuid,tracking_number text);
select * from extensions.dblink_get_result('race_a',false) as result(id uuid,tracking_number text);
select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as result(id uuid,tracking_number text);
select * from extensions.dblink_get_result('race_b',false) as result(id uuid,tracking_number text);
select extensions.dblink_exec('race_b','rollback');
select is((select count(*) from public.activity_logs where shipment_id='85000000-0000-0000-0000-000000000001' and action_type='shipment_assigned'),1::bigint,'Same-Shipment race creates one assignment activity');
select is((select count(*) from public.notifications where shipment_id='85000000-0000-0000-0000-000000000001'),1::bigint,'Same-Shipment race creates one notification');
select is((select status from public.shipments where id='85000000-0000-0000-0000-000000000001'),'assigned'::public.shipment_status,'Same-Shipment race leaves consistent Shipment state');

-- Two Shipments compete for one Driver.
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000002','82000000-0000-0000-0000-000000000002','84000000-0000-0000-0000-000000000002')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('race_b',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000002','84000000-0000-0000-0000-000000000003')$$);
select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_b',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_b','rollback');
select is((select count(*) from public.shipments where id in ('85000000-0000-0000-0000-000000000002','85000000-0000-0000-0000-000000000003') and status='assigned'),1::bigint,'Driver race assigns exactly one Shipment');
select is((select status from public.drivers where id='82000000-0000-0000-0000-000000000002'),'assigned'::public.driver_status,'Driver race synchronizes Driver once');
select is((select count(*) from public.activity_logs where shipment_id in ('85000000-0000-0000-0000-000000000002','85000000-0000-0000-0000-000000000003') and action_type='shipment_assigned'),1::bigint,'Driver race creates one activity');
select is((select count(*) from public.notifications where shipment_id in ('85000000-0000-0000-0000-000000000002','85000000-0000-0000-0000-000000000003')),1::bigint,'Driver race creates one notification');

-- Two Shipments compete for one Vehicle.
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000004','82000000-0000-0000-0000-000000000003','84000000-0000-0000-0000-000000000004')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('race_b',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000005','82000000-0000-0000-0000-000000000004','84000000-0000-0000-0000-000000000004')$$);
select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_b',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_b','rollback');
select is((select count(*) from public.shipments where id in ('85000000-0000-0000-0000-000000000004','85000000-0000-0000-0000-000000000005') and status='assigned'),1::bigint,'Vehicle race assigns exactly one Shipment');
select is((select status from public.vehicles where id='84000000-0000-0000-0000-000000000004'),'in_use'::public.vehicle_status,'Vehicle race synchronizes Vehicle once');
select is((select count(*) from public.activity_logs where shipment_id in ('85000000-0000-0000-0000-000000000004','85000000-0000-0000-0000-000000000005') and action_type='shipment_assigned'),1::bigint,'Vehicle race creates one activity');
select is((select count(*) from public.notifications where shipment_id in ('85000000-0000-0000-0000-000000000004','85000000-0000-0000-0000-000000000005')),1::bigint,'Vehicle race creates one notification');

-- Assignment wins while Client archive waits on the Client lock, then archive rejects.
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000006','82000000-0000-0000-0000-000000000005','84000000-0000-0000-0000-000000000005')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('race_b',$$update public.clients set status='archived' where id='83000000-0000-0000-0000-000000000003' returning id$$);
select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as r(id uuid); select * from extensions.dblink_get_result('race_b',false) as r(id uuid); select extensions.dblink_exec('race_b','rollback');
select is((select status from public.shipments where id='85000000-0000-0000-0000-000000000006'),'assigned'::public.shipment_status,'Client archive race preserves assignment');
select is((select status from public.clients where id='83000000-0000-0000-0000-000000000003'),'active'::public.client_status,'Client archive race preserves active Client');
select is((select count(*) from public.activity_logs where shipment_id='85000000-0000-0000-0000-000000000006' and action_type='shipment_assigned'),1::bigint,'Client archive race creates one assignment activity');
select is((select count(*) from public.notifications where shipment_id='85000000-0000-0000-0000-000000000006'),1::bigint,'Client archive race creates one notification');

-- Assignment versus Driver operational lifecycle.
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000007','82000000-0000-0000-0000-000000000006','84000000-0000-0000-0000-000000000006')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('race_b',$$select public.change_driver_operational_status('82000000-0000-0000-0000-000000000006','mark_off_duty')$$);
select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as r(status public.driver_status); select * from extensions.dblink_get_result('race_b',false) as r(status public.driver_status); select extensions.dblink_exec('race_b','rollback');
select is((select status from public.shipments where id='85000000-0000-0000-0000-000000000007'),'assigned'::public.shipment_status,'Driver lifecycle race preserves assignment');
select is((select status from public.drivers where id='82000000-0000-0000-0000-000000000006'),'assigned'::public.driver_status,'Driver lifecycle race preserves assigned Driver');
select is((select count(*) from public.activity_logs where shipment_id='85000000-0000-0000-0000-000000000007' and action_type='shipment_assigned'),1::bigint,'Driver lifecycle race creates one Shipment activity');
select is((select count(*) from public.notifications where shipment_id='85000000-0000-0000-0000-000000000007'),1::bigint,'Driver lifecycle race creates one notification');

-- Assignment versus Driver account deactivation.
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000008','82000000-0000-0000-0000-000000000007','84000000-0000-0000-0000-000000000007')$$); select pg_sleep(0.1);
select extensions.dblink_exec('race_b','set local role service_role');
select extensions.dblink_send_query('race_b',$$select * from public.set_managed_account_active_state('race-driver-g',false)$$);
select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as r(account_role public.profile_role,account_is_active boolean); select * from extensions.dblink_get_result('race_b',false) as r(account_role public.profile_role,account_is_active boolean); select extensions.dblink_exec('race_b','rollback');
select is((select status from public.shipments where id='85000000-0000-0000-0000-000000000008'),'assigned'::public.shipment_status,'Account race preserves assignment');
select ok((select is_active from public.profiles where id='81000000-0000-0000-0000-000000000008'),'Account race preserves active profile');
select is((select status from public.drivers where id='82000000-0000-0000-0000-000000000007'),'assigned'::public.driver_status,'Account race preserves assigned Driver');
select is((select count(*) from public.activity_logs where shipment_id='85000000-0000-0000-0000-000000000008' and action_type='shipment_assigned'),1::bigint,'Account race creates one Shipment activity');
select is((select count(*) from public.notifications where shipment_id='85000000-0000-0000-0000-000000000008'),1::bigint,'Account race creates one notification');

-- Assignment versus Vehicle lifecycle.
select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_send_query('race_a',$$select * from public.assign_pending_shipment('85000000-0000-0000-0000-000000000009','82000000-0000-0000-0000-000000000008','84000000-0000-0000-0000-000000000008')$$); select pg_sleep(0.1);
select extensions.dblink_send_query('race_b',$$select public.change_vehicle_operational_status('84000000-0000-0000-0000-000000000008','mark_maintenance')$$);
select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select * from extensions.dblink_get_result('race_a',false) as r(id uuid,tracking_number text); select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as r(status public.vehicle_status); select * from extensions.dblink_get_result('race_b',false) as r(status public.vehicle_status); select extensions.dblink_exec('race_b','rollback');
select is((select status from public.shipments where id='85000000-0000-0000-0000-000000000009'),'assigned'::public.shipment_status,'Vehicle lifecycle race preserves assignment');
select is((select status from public.vehicles where id='84000000-0000-0000-0000-000000000008'),'in_use'::public.vehicle_status,'Vehicle lifecycle race preserves in-use Vehicle');
select is((select count(*) from public.activity_logs where shipment_id='85000000-0000-0000-0000-000000000009' and action_type='shipment_assigned'),1::bigint,'Vehicle lifecycle race creates one Shipment activity');
select is((select count(*) from public.notifications where shipment_id='85000000-0000-0000-0000-000000000009'),1::bigint,'Vehicle lifecycle race creates one notification');

select extensions.dblink_exec('race_a','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select extensions.dblink_exec('race_b','begin; set local role authenticated; set local lock_timeout=''5s''; set local statement_timeout=''10s''; set local "request.jwt.claim.sub"=''81000000-0000-0000-0000-000000000001''');
select ok(extensions.dblink_send_query('race_a',$$select * from public.create_pending_shipment('83000000-0000-0000-0000-000000000001','A','B',now(),now(),'Cargo',1)$$)=1,'First concurrent creation started');
select pg_sleep(0.1);
select ok(extensions.dblink_send_query('race_b',$$select * from public.create_pending_shipment('83000000-0000-0000-0000-000000000002','A','B',now(),now(),'Cargo',1)$$)=1,'Second concurrent creation started');
select * from extensions.dblink_get_result('race_a',false) as result(id uuid,tracking_number text);
select * from extensions.dblink_get_result('race_a',false) as result(id uuid,tracking_number text);
select extensions.dblink_exec('race_a','commit');
select * from extensions.dblink_get_result('race_b',false) as result(id uuid,tracking_number text);
select * from extensions.dblink_get_result('race_b',false) as result(id uuid,tracking_number text);
select extensions.dblink_exec('race_b','commit');
select is((select count(distinct tracking_number) from public.shipments where tracking_number like 'SHP-%'),2::bigint,'Concurrent creation allocates unique tracking numbers');
select is((select count(*) from public.activity_logs where action_type='shipment_created' and actor_profile_id='81000000-0000-0000-0000-000000000001'),2::bigint,'Concurrent creation records exactly two activities');

select ok((select indexdef like 'CREATE UNIQUE INDEX%' from pg_indexes where schemaname='public' and indexname='shipments_active_driver_key'),'Active Driver assignment backstop is unique');
select ok((select indexdef like 'CREATE UNIQUE INDEX%' from pg_indexes where schemaname='public' and indexname='shipments_active_vehicle_key'),'Active Vehicle assignment backstop is unique');
select ok(position('deadlock detected' in extensions.dblink_error_message('race_b'))=0,'Concurrent workflows do not deadlock');
select is((select count(*) from public.activity_logs where shipment_id='85000000-0000-0000-0000-000000000001' and action_type<>'shipment_assigned'),0::bigint,'Same-Shipment loser creates no unrelated activity');
select is((select count(*) from public.notifications where shipment_id='85000000-0000-0000-0000-000000000001' and notification_type<>'shipment_assigned'),0::bigint,'Same-Shipment loser creates no unrelated notification');

select extensions.dblink_disconnect('race_a'); select extensions.dblink_disconnect('race_b');
select extensions.dblink_exec('setup',$cleanup$
  delete from public.notifications where shipment_id in (select id from public.shipments where client_id::text like '83000000-%');
  delete from public.activity_logs where actor_profile_id='81000000-0000-0000-0000-000000000001';
  delete from public.shipments where client_id::text like '83000000-%';
  delete from public.vehicles where id::text like '84000000-%'; delete from public.drivers where id::text like '82000000-%';
  delete from public.clients where id::text like '83000000-%'; delete from public.profiles where id::text like '81000000-%'; delete from auth.users where id::text like '81000000-%';
$cleanup$);
select extensions.dblink_disconnect('setup');
select * from finish(); rollback;
