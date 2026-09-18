begin;
create extension if not exists pgtap with schema extensions;
select plan(30);

insert into auth.users(id)
select id from (
  values
    ('f1000000-0000-0000-0000-000000000001'::uuid),
    ('f1000000-0000-0000-0000-000000000002'::uuid),
    ('f1000000-0000-0000-0000-000000000003'::uuid),
    ('f1000000-0000-0000-0000-000000000004'::uuid)
) identities(id);
insert into auth.users(id)
select ('f1100000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid
from generate_series(1, 7) series;

insert into public.profiles(id,full_name,username,role,is_active) values
  ('f1000000-0000-0000-0000-000000000001','E1 Admin','e1-admin','admin',true),
  ('f1000000-0000-0000-0000-000000000002','E1 Dispatcher','e1-dispatcher','dispatcher',true),
  ('f1000000-0000-0000-0000-000000000003','E1 Driver','e1-driver','driver',true),
  ('f1000000-0000-0000-0000-000000000004','E1 Inactive','e1-inactive','admin',false);
insert into public.profiles(id,full_name,username,role,is_active)
select
  ('f1100000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  'Dashboard Driver ' || series,
  'dashboard-driver-' || series,
  'driver',
  true
from generate_series(1, 7) series;

insert into public.drivers(id,profile_id,status)
select
  ('f2000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  ('f1100000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  case when series <= 6 then 'assigned'::public.driver_status else 'available'::public.driver_status end
from generate_series(1, 7) series;
insert into public.clients(id,company_name,status)
values ('f6000000-0000-0000-0000-000000000001','E1 Client','active');
insert into public.vehicles(id,registration,make,model,vehicle_type,status)
select
  ('f3000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  'E1-' || series,
  'Make',
  'Model',
  'Truck',
  case when series <= 6 then 'in_use'::public.vehicle_status else 'available'::public.vehicle_status end
from generate_series(1, 7) series;

insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status,delayed)
select
  ('f4000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  'SHP-E1-' || series,
  'f6000000-0000-0000-0000-000000000001',
  'Pickup',
  'Delivery',
  '2026-09-20 08:00:00+00'::timestamptz,
  '2026-09-20 10:00:00+00'::timestamptz,
  'Cargo',
  ('f2000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  ('f3000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  999,
  (array['assigned','loading','in_transit']::public.shipment_status[])[((series - 1) % 3) + 1],
  series = 3
from generate_series(1, 6) series;
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price,status) values
  ('f4000000-0000-0000-0000-000000000007','SHP-E1-PENDING','f6000000-0000-0000-0000-000000000001','Pickup','Delivery',now(),now()+interval '1 hour','Cargo',999,'pending'),
  ('f4000000-0000-0000-0000-000000000009','SHP-E1-CANCELLED','f6000000-0000-0000-0000-000000000001','Pickup','Delivery',now(),now()+interval '1 hour','Cargo',999,'cancelled');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status)
values ('f4000000-0000-0000-0000-000000000008','SHP-E1-DELIVERED','f6000000-0000-0000-0000-000000000001','Pickup','Delivery',now(),now()+interval '1 hour','Cargo','f2000000-0000-0000-0000-000000000007','f3000000-0000-0000-0000-000000000007',999,'delivered');

insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status,requested_at)
select
  ('f5000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  ('f4000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  ('f2000000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  (array['assigned','loading','in_transit']::public.shipment_status[])[((series - 1) % 3) + 1],
  (array['loading','in_transit','delivered']::public.shipment_status[])[((series - 1) % 3) + 1],
  '2026-09-20 08:00:00+00'::timestamptz + (case when series <= 2 then 0 else series - 2 end) * interval '1 minute'
from generate_series(1, 6) series;
insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status,request_state,requested_at,resolved_at,resolved_by_profile_id)
values ('f5000000-0000-0000-0000-000000000007','f4000000-0000-0000-0000-000000000008','f2000000-0000-0000-0000-000000000007','in_transit','delivered','approved','2026-09-19 08:00:00+00','2026-09-19 09:00:00+00','f1000000-0000-0000-0000-000000000001');

insert into public.alerts(id,alert_type,severity,message,shipment_id) values
  ('f7000000-0000-0000-0000-000000000001','shipment_delayed','warning','Active one','f4000000-0000-0000-0000-000000000003'),
  ('f7000000-0000-0000-0000-000000000002','stale_vehicle_location','critical','Active two','f4000000-0000-0000-0000-000000000006');
insert into public.alerts(id,alert_type,severity,message,shipment_id,alert_state,resolved_at,resolved_by_profile_id)
values ('f7000000-0000-0000-0000-000000000003','shipment_delayed','warning','Resolved','f4000000-0000-0000-0000-000000000006','resolved',now(),'f1000000-0000-0000-0000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000001',true);
select results_eq($$select * from public.get_operations_dashboard_kpis()$$,$$values (6::bigint,6::bigint,6::bigint,2::bigint)$$,'Admin receives exact operational KPI counts');
select is((select active_shipments from public.get_operations_dashboard_kpis()),6::bigint,'Active Shipments includes assigned, loading, and in-transit rows only');
reset role;
select is((select count(*) from public.shipments where status='pending'),1::bigint,'Pending fixture is present and excluded from Active Shipments');
select is((select count(*) from public.shipments where status='delivered'),1::bigint,'Delivered fixture is present and excluded from Active Shipments');
select is((select count(*) from public.shipments where status='cancelled'),1::bigint,'Cancelled fixture is present and excluded from Active Shipments');
select is((select count(*) from public.shipments where status='in_transit' and delayed),1::bigint,'Delayed in-transit fixture is counted once');
set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000001',true);
select is((select in_use_vehicles from public.get_operations_dashboard_kpis()),6::bigint,'In-use Vehicles uses vehicle status exactly');
select is((select assigned_drivers from public.get_operations_dashboard_kpis()),6::bigint,'Assigned Drivers uses driver status exactly');
select is((select active_alerts from public.get_operations_dashboard_kpis()),2::bigint,'Active Alerts excludes resolved alerts and combines severities');
select is((select count(*) from public.list_operations_dashboard_pending_status_requests(5)),5::bigint,'Pending preview returns at most five rows');
select results_eq($$select id from public.list_operations_dashboard_pending_status_requests(5)$$,$$values ('f5000000-0000-0000-0000-000000000001'::uuid),('f5000000-0000-0000-0000-000000000002'::uuid),('f5000000-0000-0000-0000-000000000003'::uuid),('f5000000-0000-0000-0000-000000000004'::uuid),('f5000000-0000-0000-0000-000000000005'::uuid)$$,'Pending preview orders by requested_at then id');
select is((select count(*) from public.list_operations_dashboard_pending_status_requests(5) where id='f5000000-0000-0000-0000-000000000007'),0::bigint,'Pending preview excludes resolved requests');
select is((select driver_name from public.list_operations_dashboard_pending_status_requests(1)),'Dashboard Driver 1','Pending preview returns the safe Driver display label');
select is((select tracking_number from public.list_operations_dashboard_pending_status_requests(1)),'SHP-E1-1','Pending preview returns the safe Shipment tracking number');
select ok(not exists(select 1 from public.list_operations_dashboard_pending_status_requests(1) row cross join lateral jsonb_object_keys(to_jsonb(row)) keys(key) where keys.key in ('price','phone','profile_id','auth_id','metadata')),'Pending preview returns no financial, contact, Auth, or raw metadata fields');
select throws_ok($$select * from public.list_operations_dashboard_pending_status_requests(0)$$,'22023','operations_dashboard_preview_limit_invalid','Preview rejects a limit below one');
select throws_ok($$select * from public.list_operations_dashboard_pending_status_requests(6)$$,'22023','operations_dashboard_preview_limit_invalid','Preview rejects a limit above five');

reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000002',true);
select results_eq($$select * from public.get_operations_dashboard_kpis()$$,$$values (6::bigint,6::bigint,6::bigint,2::bigint)$$,'Dispatcher receives the same four non-financial KPI counts');
select is((select count(*) from public.list_operations_dashboard_pending_status_requests(5)),5::bigint,'Dispatcher receives the same bounded pending preview');

reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000003',true);
select throws_ok($$select * from public.get_operations_dashboard_kpis()$$,'42501','operations_dashboard_read_access_denied','Driver is denied KPI access');
select throws_ok($$select * from public.list_operations_dashboard_pending_status_requests(5)$$,'42501','operations_dashboard_read_access_denied','Driver is denied preview access');
reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','f1000000-0000-0000-0000-000000000004',true);
select throws_ok($$select * from public.get_operations_dashboard_kpis()$$,'42501','operations_dashboard_read_access_denied','Inactive Operations profile is denied');
reset role; set local role authenticated; reset "request.jwt.claim.sub";
select throws_ok($$select * from public.get_operations_dashboard_kpis()$$,'42501','operations_dashboard_read_access_denied','Authenticated caller without an identity is denied');

reset role; set local role anon;
select throws_ok($$select * from public.get_operations_dashboard_kpis()$$,'42501',null,'Anonymous caller lacks KPI function execution');
select throws_ok($$select * from public.list_operations_dashboard_pending_status_requests(5)$$,'42501',null,'Anonymous caller lacks preview function execution');
reset role;
select ok(not has_function_privilege('public','public.get_operations_dashboard_kpis()','EXECUTE'),'Public lacks KPI function execution');
select ok(not has_function_privilege('anon','public.get_operations_dashboard_kpis()','EXECUTE'),'Anon lacks KPI function execution');
select ok(has_function_privilege('authenticated','public.get_operations_dashboard_kpis()','EXECUTE'),'Authenticated has KPI execution subject to the internal role check');
select ok(not has_function_privilege('public','public.list_operations_dashboard_pending_status_requests(integer)','EXECUTE'),'Public lacks preview function execution');
select ok(not has_function_privilege('anon','public.list_operations_dashboard_pending_status_requests(integer)','EXECUTE'),'Anon lacks preview function execution');

select * from finish();
rollback;
