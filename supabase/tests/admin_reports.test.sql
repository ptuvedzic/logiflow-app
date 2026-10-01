begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
  ('22100000-0000-0000-0000-000000000001'),
  ('22100000-0000-0000-0000-000000000002'),
  ('22100000-0000-0000-0000-000000000003'),
  ('22100000-0000-0000-0000-000000000004'),
  ('22100000-0000-0000-0000-000000000005');

insert into public.profiles(id,full_name,username,role,is_active) values
  ('22100000-0000-0000-0000-000000000001','R1 Admin','r1-admin','admin',true),
  ('22100000-0000-0000-0000-000000000002','R1 Dispatcher','r1-dispatcher','dispatcher',true),
  ('22100000-0000-0000-0000-000000000003','R1 Driver One','r1-driver-one','driver',true),
  ('22100000-0000-0000-0000-000000000004','R1 Inactive Admin','r1-inactive','admin',false);

insert into auth.users(id)
select ('22110000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid
from generate_series(1, 8) series;
insert into public.profiles(id,full_name,username,role,is_active)
select
  ('22110000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  'Report Driver ' || series,
  'report-driver-' || series,
  'driver',
  true
from generate_series(1, 8) series;
insert into public.drivers(id,profile_id,status)
select
  ('22200000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  ('22110000-0000-0000-0000-' || lpad(series::text, 12, '0'))::uuid,
  (array['available','assigned','off_duty','inactive','archived','available','available','available']::public.driver_status[])[series]
from generate_series(1, 8) series;

insert into public.clients(id,company_name,status) values
  ('22300000-0000-0000-0000-000000000001','Alpha Logistics','active'),
  ('22300000-0000-0000-0000-000000000002','Beta Cargo','active');

insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
  ('22400000-0000-0000-0000-000000000001','R1-AVAILABLE','Make','Model','Truck','available'),
  ('22400000-0000-0000-0000-000000000002','R1-IN-USE','Make','Model','Truck','in_use'),
  ('22400000-0000-0000-0000-000000000003','R1-MAINT','Make','Model','Truck','maintenance'),
  ('22400000-0000-0000-0000-000000000004','R1-OUT','Make','Model','Truck','out_of_service'),
  ('22400000-0000-0000-0000-000000000005','R1-ARCHIVED','Make','Model','Truck','archived'),
  ('22400000-0000-0000-0000-000000000006','R1-D6','Make','Model','Truck','available'),
  ('22400000-0000-0000-0000-000000000007','R1-D7','Make','Model','Truck','available'),
  ('22400000-0000-0000-0000-000000000008','R1-D8','Make','Model','Truck','available');

-- Three qualifying deliveries. Pickup dates remain in the report cohort, while
-- resolution timestamps prove the inclusive Belgrade boundary behavior.
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
  ('22500000-0000-0000-0000-000000000001','SHP-R1-D1','22300000-0000-0000-0000-000000000001','A','B','2026-07-31 22:00+00','2026-08-01 04:00+00','Cargo','22200000-0000-0000-0000-000000000006','22400000-0000-0000-0000-000000000006',1000,'delivered'),
  ('22500000-0000-0000-0000-000000000002','SHP-R1-D2','22300000-0000-0000-0000-000000000002','A','B','2026-08-15 08:00+00','2026-08-15 12:00+00','Cargo','22200000-0000-0000-0000-000000000007','22400000-0000-0000-0000-000000000007',500,'delivered'),
  ('22500000-0000-0000-0000-000000000003','SHP-R1-D3','22300000-0000-0000-0000-000000000001','A','B','2026-08-31 21:00+00','2026-08-31 21:30+00','Cargo','22200000-0000-0000-0000-000000000006','22400000-0000-0000-0000-000000000006',50,'delivered');

insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status,delayed) values
  ('22500000-0000-0000-0000-000000000004','SHP-R1-ASSIGNED','22300000-0000-0000-0000-000000000001','A','B','2026-08-15 09:00+00','2026-08-15 13:00+00','Cargo','22200000-0000-0000-0000-000000000002','22400000-0000-0000-0000-000000000002',900,'assigned',false),
  ('22500000-0000-0000-0000-000000000005','SHP-R1-LOADING','22300000-0000-0000-0000-000000000001','A','B','2026-08-15 10:00+00','2026-08-15 14:00+00','Cargo','22200000-0000-0000-0000-000000000003','22400000-0000-0000-0000-000000000003',900,'loading',false),
  ('22500000-0000-0000-0000-000000000006','SHP-R1-TRANSIT','22300000-0000-0000-0000-000000000002','A','B','2026-08-15 11:00+00','2026-08-15 15:00+00','Cargo','22200000-0000-0000-0000-000000000004','22400000-0000-0000-0000-000000000004',900,'in_transit',true);
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price,status) values
  ('22500000-0000-0000-0000-000000000007','SHP-R1-PENDING','22300000-0000-0000-0000-000000000001','A','B','2026-08-15 12:00+00','2026-08-15 16:00+00','Cargo',900,'pending'),
  ('22500000-0000-0000-0000-000000000008','SHP-R1-CANCELLED','22300000-0000-0000-0000-000000000002','A','B','2026-08-15 13:00+00','2026-08-15 17:00+00','Cargo',500,'cancelled'),
  ('22500000-0000-0000-0000-000000000009','SHP-R1-OUTSIDE','22300000-0000-0000-0000-000000000002','A','B','2026-09-01 08:00+00','2026-09-01 12:00+00','Cargo',999,'cancelled');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
  ('22500000-0000-0000-0000-000000000010','SHP-R1-DELIVERY-OUTSIDE','22300000-0000-0000-0000-000000000002','A','B','2026-09-01 09:00+00','2026-09-01 13:00+00','Cargo','22200000-0000-0000-0000-000000000008','22400000-0000-0000-0000-000000000008',999,'delivered');

insert into public.shipment_status_requests(id,shipment_id,driver_id,current_status,requested_status,request_state,requested_at,resolved_at,resolved_by_profile_id) values
  ('22600000-0000-0000-0000-000000000001','22500000-0000-0000-0000-000000000001','22200000-0000-0000-0000-000000000006','in_transit','delivered','approved','2026-07-31 21:59+00','2026-07-31 22:00+00','22100000-0000-0000-0000-000000000001'),
  ('22600000-0000-0000-0000-000000000002','22500000-0000-0000-0000-000000000002','22200000-0000-0000-0000-000000000007','in_transit','delivered','approved','2026-08-15 12:00+00','2026-08-15 13:00+00','22100000-0000-0000-0000-000000000001'),
  ('22600000-0000-0000-0000-000000000003','22500000-0000-0000-0000-000000000003','22200000-0000-0000-0000-000000000006','in_transit','delivered','approved','2026-08-31 21:58+00','2026-08-31 21:59:59+00','22100000-0000-0000-0000-000000000001'),
  ('22600000-0000-0000-0000-000000000004','22500000-0000-0000-0000-000000000010','22200000-0000-0000-0000-000000000008','in_transit','delivered','approved','2026-08-31 21:59+00','2026-08-31 22:00+00','22100000-0000-0000-0000-000000000001');

insert into public.expenses(id,shipment_id,created_by_profile_id,category,amount,expense_date) values
  ('22700000-0000-0000-0000-000000000001','22500000-0000-0000-0000-000000000001','22100000-0000-0000-0000-000000000001','fuel',100,'2025-01-01'),
  ('22700000-0000-0000-0000-000000000002','22500000-0000-0000-0000-000000000002','22100000-0000-0000-0000-000000000001','toll',50,'2027-01-01'),
  ('22700000-0000-0000-0000-000000000003','22500000-0000-0000-0000-000000000003','22100000-0000-0000-0000-000000000001','other',1550,'2026-08-30'),
  ('22700000-0000-0000-0000-000000000004','22500000-0000-0000-0000-000000000004','22100000-0000-0000-0000-000000000001','maintenance',777,'2026-08-15');

insert into public.maintenance_records(id,vehicle_id,service_type,service_date,mileage_at_service,cost) values
  ('22800000-0000-0000-0000-000000000001','22400000-0000-0000-0000-000000000001','Service','2026-08-10',100,200),
  ('22800000-0000-0000-0000-000000000002','22400000-0000-0000-0000-000000000003','Inspection','2026-08-20',200,null),
  ('22800000-0000-0000-0000-000000000003','22400000-0000-0000-0000-000000000001','Outside','2026-07-20',50,999);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000001',true);
create temporary table r1_report as
select public.get_admin_reports('2026-08-01','2026-08-31') as value;

select is((select (value#>>'{financial,completed_shipments}')::bigint from r1_report),3::bigint,'Financial report counts authoritative delivered resolutions at both Belgrade boundaries');
select is((select (value#>>'{financial,revenue}')::numeric from r1_report),1550::numeric,'Revenue sums stored prices only for qualifying delivered Shipments');
select is((select (value#>>'{financial,total_expenses}')::numeric from r1_report),1700::numeric,'Expenses include all retained qualifying Shipment expenses regardless of expense date');
select is((select (value#>>'{financial,profit}')::numeric from r1_report),-150::numeric,'Profit derives correctly and may be negative');
select isnt((select (value#>>'{financial,total_expenses}')::numeric from r1_report),1900::numeric,'Maintenance record cost is not copied into Shipment expenses');
select isnt((select (value#>>'{financial,total_expenses}')::numeric from r1_report),2477::numeric,'Active Shipment expenses do not enter completed-delivery finance');

select is((select (value#>>'{shipments,scheduled_shipments}')::bigint from r1_report),8::bigint,'Pickup cohort includes every status and honors the Belgrade range');
select is((select (value#>>'{shipments,completed_shipments}')::bigint from r1_report),3::bigint,'Completed Shipment report uses delivered resolution time');
select is((select (value#>>'{shipments,delayed_shipments}')::bigint from r1_report),1::bigint,'Delayed is reported separately from status');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,statuses}') entry where entry->>'status'='pending'),1::bigint,'Pending status count is exact');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,statuses}') entry where entry->>'status'='assigned'),1::bigint,'Assigned status count is exact');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,statuses}') entry where entry->>'status'='loading'),1::bigint,'Loading status count is exact');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,statuses}') entry where entry->>'status'='in_transit'),1::bigint,'In-transit status count is exact');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,statuses}') entry where entry->>'status'='delivered'),3::bigint,'Delivered pickup-cohort status count is exact');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,statuses}') entry where entry->>'status'='cancelled'),1::bigint,'Cancelled appears in status reporting but not finance');
select is((select value#>>'{period,bucket_granularity}' from r1_report),'day','A 31-day inclusive month uses daily buckets');
select is((select jsonb_array_length(value#>'{shipments,volume}') from r1_report),31,'Daily series includes zero-count dates');
select is((select (entry->>'count')::bigint from r1_report cross join lateral jsonb_array_elements(value#>'{shipments,volume}') entry where entry->>'bucket_start'='2026-08-02'),0::bigint,'Shipment volume explicitly returns zero-count buckets');

select is((select (value#>>'{fleet,serviceable_vehicles}')::bigint from r1_report),5::bigint,'Serviceable fleet includes only available and in-use Vehicles');
select is((select (value#>>'{fleet,in_use_vehicles}')::bigint from r1_report),1::bigint,'Fleet numerator uses current in-use status');
select is((select (value#>>'{fleet,utilization_percent}')::numeric from r1_report),20::numeric,'Current utilization uses the approved denominator');
select is((select (value#>>'{fleet,maintenance,records}')::bigint from r1_report),2::bigint,'Maintenance summary filters by service date');
select is((select (value#>>'{fleet,maintenance,vehicles_serviced}')::bigint from r1_report),2::bigint,'Maintenance summary counts distinct serviced Vehicles');
select is((select (value#>>'{fleet,maintenance,costed_records}')::bigint from r1_report),1::bigint,'Maintenance summary reports records containing cost');
select is((select (value#>>'{fleet,maintenance,recorded_cost}')::numeric from r1_report),200::numeric,'Maintenance recorded cost ignores null and out-of-period records');
select is((select jsonb_array_length(value#>'{fleet,statuses}') from r1_report),5,'Every Vehicle status is present, including zero counts');
reset role;
update public.vehicles set status='maintenance';
set local role authenticated;
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000001',true);
select ok(public.get_admin_reports('2026-08-01','2026-08-31')#>'{fleet,utilization_percent}' = 'null'::jsonb,'Utilization is null when no serviceable Vehicle exists');
reset role;
update public.vehicles set status = case id
  when '22400000-0000-0000-0000-000000000001' then 'available'::public.vehicle_status
  when '22400000-0000-0000-0000-000000000002' then 'in_use'::public.vehicle_status
  when '22400000-0000-0000-0000-000000000003' then 'maintenance'::public.vehicle_status
  when '22400000-0000-0000-0000-000000000004' then 'out_of_service'::public.vehicle_status
  when '22400000-0000-0000-0000-000000000005' then 'archived'::public.vehicle_status
  else 'available'::public.vehicle_status end;
set local role authenticated;
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000001',true);

select is((select jsonb_array_length(value#>'{drivers,statuses}') from r1_report),5,'Every Driver status is present, including zero counts');
select is((select value#>>'{drivers,completions,0,driver_name}' from r1_report),'Report Driver 6','Driver completions order by count without inventing a score');
select is((select (value#>>'{drivers,completions,0,completed_shipments}')::bigint from r1_report),2::bigint,'Driver completion aggregation is exact');
select is((select jsonb_array_length(value#>'{drivers,completions}') from r1_report),2,'Drivers with no qualifying completion are omitted from the completion table');

select is((select value#>>'{clients,0,company_name}' from r1_report),'Alpha Logistics','Client results order by delivered revenue');
select is((select (value#>>'{clients,0,completed_shipments}')::bigint from r1_report),2::bigint,'Client completed Shipment count is exact');
select is((select (value#>>'{clients,0,revenue}')::numeric from r1_report),1050::numeric,'Client revenue uses stored qualifying Shipment prices');
select is((select jsonb_array_length(value#>'{clients}') from r1_report),2,'Client report includes each Client with a qualifying delivery');

select is((public.get_admin_reports('2026-06-01','2026-07-31')#>>'{period,bucket_granularity}'),'week','A 61-day range uses weekly buckets');
select is((public.get_admin_reports('2026-01-01','2026-08-30')#>>'{period,bucket_granularity}'),'month','A range above 92 days uses monthly buckets');
select is((public.get_admin_reports('2026-07-01','2026-07-30')#>>'{financial,revenue}')::numeric,0::numeric,'An empty period returns zero financial values');
select is(jsonb_array_length(public.get_admin_reports('2026-07-01','2026-07-30')#>'{drivers,completions}'),0,'An empty period returns an empty Driver completion list');
select is(jsonb_array_length(public.get_admin_reports('2026-07-01','2026-07-30')#>'{clients}'),0,'An empty period returns an empty Client list');
select throws_ok($$select public.get_admin_reports(null,'2026-08-30')$$,'22023','admin_reports_date_invalid','Null start date is rejected');
select throws_ok($$select public.get_admin_reports('2026-09-01','2026-08-30')$$,'22023','admin_reports_date_invalid','Reversed date range is rejected');
select throws_ok($$select public.get_admin_reports('2025-08-29','2026-08-30')$$,'22023','admin_reports_date_invalid','A range above 366 inclusive days is rejected');
select throws_ok($$select public.get_admin_reports('2099-01-01','2099-01-01')$$,'22023','admin_reports_date_invalid','Future end date is rejected');

reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000002',true);
select throws_ok($$select public.get_admin_reports('2026-08-01','2026-08-30')$$,'42501','admin_reports_access_denied','Dispatcher cannot execute Reports successfully');
reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000003',true);
select throws_ok($$select public.get_admin_reports('2026-08-01','2026-08-30')$$,'42501','admin_reports_access_denied','Driver cannot execute Reports successfully');
reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000004',true);
select throws_ok($$select public.get_admin_reports('2026-08-01','2026-08-30')$$,'42501','admin_reports_access_denied','Inactive Admin cannot execute Reports');
reset role; set local role authenticated;
select set_config('request.jwt.claim.sub','22100000-0000-0000-0000-000000000005',true);
select throws_ok($$select public.get_admin_reports('2026-08-01','2026-08-30')$$,'42501','admin_reports_access_denied','Missing profile cannot execute Reports');
reset role; set local role authenticated; reset "request.jwt.claim.sub";
select throws_ok($$select public.get_admin_reports('2026-08-01','2026-08-30')$$,'42501','admin_reports_access_denied','Identity-less authenticated caller is denied');
reset role; set local role anon;
select throws_ok($$select public.get_admin_reports('2026-08-01','2026-08-30')$$,'42501',null,'Anonymous caller lacks function execution');

reset role;
select ok(not has_function_privilege('public','public.get_admin_reports(date,date)','EXECUTE'),'Public lacks report execution');
select ok(not has_function_privilege('anon','public.get_admin_reports(date,date)','EXECUTE'),'Anon lacks report execution');
select ok(has_function_privilege('authenticated','public.get_admin_reports(date,date)','EXECUTE'),'Authenticated receives only narrow execution subject to internal Admin authorization');
select is((select prosecdef from pg_proc where oid='public.get_admin_reports(date,date)'::regprocedure),true,'Report function is SECURITY DEFINER');
select is((select provolatile from pg_proc where oid='public.get_admin_reports(date,date)'::regprocedure),'s','Report function is STABLE');
select is((select proconfig from pg_proc where oid='public.get_admin_reports(date,date)'::regprocedure),array['search_path=""']::text[],'Report function has a fixed empty search path');
select ok(not has_table_privilege('authenticated','public.expenses','SELECT'),'Reports do not broaden direct Expense reads');
select ok(not exists(select 1 from information_schema.tables where table_schema='public' and table_name like '%report%'),'No persisted report table exists');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='shipments' and column_name in ('total_expenses','profit','delivered_at')),'Reports add no persisted financial or delivery aggregate columns');
select ok(position('expenses.expense_date' in lower(pg_get_functiondef('public.get_admin_reports(date,date)'::regprocedure)))=0,'Financial aggregation does not filter qualifying expenses by expense date');
select ok(position('shipments.updated_at' in lower(pg_get_functiondef('public.get_admin_reports(date,date)'::regprocedure)))=0,'Delivery timing never uses Shipments updated_at');
select ok(position('limit 100' in lower(pg_get_functiondef('public.get_admin_reports(date,date)'::regprocedure)))>0,'Driver and Client report lists are bounded');

select * from finish();
rollback;
