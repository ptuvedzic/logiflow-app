begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users(id) values
  ('19100000-0000-0000-0000-000000000001'),
  ('19100000-0000-0000-0000-000000000002'),
  ('19100000-0000-0000-0000-000000000003'),
  ('19100000-0000-0000-0000-000000000004'),
  ('19100000-0000-0000-0000-000000000005');
insert into public.profiles(id,full_name,username,role,is_active) values
  ('19100000-0000-0000-0000-000000000001','F1 Admin','f1-admin','admin',true),
  ('19100000-0000-0000-0000-000000000002','F1 Dispatcher','f1-dispatcher','dispatcher',true),
  ('19100000-0000-0000-0000-000000000003','F1 Driver','f1-driver','driver',true),
  ('19100000-0000-0000-0000-000000000004','F1 Inactive','f1-inactive','admin',false);
insert into public.clients(id,company_name) values
  ('19300000-0000-0000-0000-000000000001','F1 Client');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,price,status) values
  ('19500000-0000-0000-0000-000000000001','SHP-F1-001','19300000-0000-0000-0000-000000000001','Novi Sad','Belgrade','2026-09-24 08:00+00','2026-09-24 10:00+00','General',1000.00,'pending'),
  ('19500000-0000-0000-0000-000000000002','SHP-F1-002','19300000-0000-0000-0000-000000000001','Belgrade','Nis','2026-09-25 08:00+00','2026-09-25 12:00+00','Other',500.00,'pending');

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000001',true);
select results_eq(
  $$select revenue,total_expenses,profit,expense_count from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,
  $$values (1000.00::numeric,0::numeric,1000.00::numeric,0::bigint)$$,
  'Admin reads a correct zero-expense financial summary');
select is((select count(*) from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001')),0::bigint,'Admin reads an empty expense list');

select lives_ok(
  $$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','fuel',125.25,'2026-09-24','  Diesel  ')$$,
  'Admin creates an expense');
reset role;
select is((select created_by_profile_id from public.expenses where description='Diesel'),'19100000-0000-0000-0000-000000000001'::uuid,'Create derives creator from auth.uid()');
select is((select description from public.expenses where description='Diesel'),'Diesel','Create trims description');
select is((select count(*) from public.activity_logs where action_type='expense_created' and expense_id=(select id from public.expenses where description='Diesel')),1::bigint,'Create writes exactly one matching activity');
select ok((select num_nonnulls(shipment_id,vehicle_id,driver_id,client_id,document_id,status_request_id,maintenance_record_id,expense_id)=1 from public.activity_logs where expense_id=(select id from public.expenses where description='Diesel')),'Expense is the activity sole primary entity');

set local role authenticated;
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000002',true);
select lives_ok(
  $$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','toll',10.10,'2026-09-25','   ')$$,
  'Dispatcher creates an expense');
select lives_ok(
  $$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','other',0.15,'2026-09-23',null)$$,
  'Decimal expense is accepted');
select results_eq(
  $$select revenue,total_expenses,profit,expense_count from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,
  $$values (1000.00::numeric,135.50::numeric,864.50::numeric,3::bigint)$$,
  'Multiple decimal expenses aggregate and profit derives from stored price');
select is((select description from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where category='toll'),null,'Blank description normalizes to null');
select results_eq(
  $$select category from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001')$$,
  $$values ('toll'::public.expense_category),('fuel'::public.expense_category),('other'::public.expense_category)$$,
  'Expense list orders by date descending with deterministic secondary ordering');

select throws_ok(
  $$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','fuel',0,'2026-09-24',null)$$,
  'P0001','expense_validation_failed','Non-positive amount is rejected');
select throws_ok(
  $$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','fuel',10000000000,'2026-09-24',null)$$,
  'P0001','expense_validation_failed','Numeric upper bound is enforced');
select throws_ok(
  $$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','invalid'::public.expense_category,1,'2026-09-24',null)$$,
  '22P02',null,'Invalid category is rejected by the approved enum');
reset role;
select is((select count(*) from public.expenses),3::bigint,'Failed creates add no expense');
select is((select count(*) from public.activity_logs where action_type='expense_created'),3::bigint,'Failed creates add no activity');

set local role authenticated;
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000002',true);
select results_eq(
  $$select mutation_result from public.update_shipment_expense((select id from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Diesel'),'19500000-0000-0000-0000-000000000001',(select updated_at from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Diesel'),'fuel',125.25,'2026-09-24',' Diesel ')$$,
  $$values ('noop'::text)$$,
  'Normalized no-op is reported');
reset role;
select is((select count(*) from public.activity_logs where action_type='expense_updated'),0::bigint,'Normalized no-op creates no activity');

set local role authenticated;
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000002',true);
select results_eq(
  $$select mutation_result from public.update_shipment_expense((select id from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Diesel'),'19500000-0000-0000-0000-000000000001',(select updated_at from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Diesel'),'maintenance',200.50,'2026-09-26','Repair')$$,
  $$values ('updated'::text)$$,
  'Meaningful update succeeds');
reset role;
select is((select created_by_profile_id from public.expenses where description='Repair'),'19100000-0000-0000-0000-000000000001'::uuid,'Update preserves immutable creator');
select is((select shipment_id from public.expenses where description='Repair'),'19500000-0000-0000-0000-000000000001'::uuid,'Update cannot move expense to another Shipment');
select is((select count(*) from public.activity_logs where action_type='expense_updated' and expense_id=(select id from public.expenses where description='Repair')),1::bigint,'Meaningful update writes exactly one activity');

set local role authenticated;
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000002',true);
select throws_ok(
  $$select * from public.update_shipment_expense((select id from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Repair'),'19500000-0000-0000-0000-000000000002',(select updated_at from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Repair'),'fuel',1,'2026-09-24',null)$$,
  'P0001','expense_not_found','Expense cannot be edited through another Shipment route');
select throws_ok(
  $$select * from public.update_shipment_expense((select id from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001') where description='Repair'),'19500000-0000-0000-0000-000000000001','2000-01-01','fuel',1,'2026-09-24',null)$$,
  '40001','expense_stale','Stale update is rejected');
select results_eq(
  $$select total_expenses,profit from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,
  $$values (210.75::numeric,789.25::numeric)$$,
  'Expense edit changes derived totals without storing them');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='shipments' and column_name in ('total_expenses','profit')),'Derived financial totals are not stored');

select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000003',true);
select throws_ok($$select * from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,'42501','expense_read_access_denied','Driver cannot read financial summary');
select throws_ok($$select * from public.list_shipment_expenses('19500000-0000-0000-0000-000000000001')$$,'42501','expense_read_access_denied','Driver cannot read expenses');
select throws_ok($$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','fuel',1,current_date,null)$$,'42501','expense_mutation_access_denied','Driver cannot create expenses');
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000004',true);
select throws_ok($$select * from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,'42501','expense_read_access_denied','Inactive profile cannot read financial data');
select set_config('request.jwt.claim.sub','19100000-0000-0000-0000-000000000005',true);
select throws_ok($$select * from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,'42501','expense_read_access_denied','Missing profile cannot read financial data');
reset "request.jwt.claim.sub";
select throws_ok($$select * from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,'42501','expense_read_access_denied','Authenticated caller without identity is denied');
select throws_ok($$select * from public.expenses$$,'42501',null,'Direct authenticated SELECT is denied');
select throws_ok($$insert into public.expenses(id,shipment_id,created_by_profile_id,category,amount,expense_date) values(gen_random_uuid(),'19500000-0000-0000-0000-000000000001','19100000-0000-0000-0000-000000000002','fuel',1,current_date)$$,'42501',null,'Direct authenticated INSERT cannot forge creator');
select throws_ok($$update public.expenses set shipment_id='19500000-0000-0000-0000-000000000002'$$,'42501',null,'Direct authenticated UPDATE cannot move expense');
select throws_ok($$delete from public.expenses$$,'42501',null,'Expense retention denies direct DELETE');

reset role; set local role anon;
select throws_ok($$select * from public.get_operations_shipment_financial_detail('19500000-0000-0000-0000-000000000001')$$,'42501',null,'Anonymous cannot execute financial read');
select throws_ok($$select * from public.create_shipment_expense('19500000-0000-0000-0000-000000000001','fuel',1,current_date,null)$$,'42501',null,'Anonymous cannot execute expense create');
reset role;

select ok(not has_table_privilege('authenticated','public.expenses','SELECT'),'Authenticated has no direct expense SELECT grant');
select ok(not has_table_privilege('authenticated','public.expenses','INSERT'),'Authenticated has no direct expense INSERT grant');
select ok(not has_table_privilege('authenticated','public.expenses','UPDATE'),'Authenticated has no direct expense UPDATE grant');
select ok(not has_table_privilege('authenticated','public.expenses','DELETE'),'Authenticated has no expense DELETE grant');
select ok(has_function_privilege('authenticated','public.create_shipment_expense(uuid,public.expense_category,numeric,date,text)','EXECUTE'),'Authenticated has narrow create execution subject to internal authorization');
select ok(not has_function_privilege('anon','public.create_shipment_expense(uuid,public.expense_category,numeric,date,text)','EXECUTE'),'Anon lacks expense create execution');
select is((select prosecdef from pg_proc where oid='public.create_shipment_expense(uuid,public.expense_category,numeric,date,text)'::regprocedure),true,'Create is SECURITY DEFINER');
select is((select proconfig from pg_proc where oid='public.update_shipment_expense(uuid,uuid,timestamptz,public.expense_category,numeric,date,text)'::regprocedure),array['search_path=""']::text[],'Update has an empty search path');
select ok(to_regprocedure('public.get_company_financial_report()') is null,'F1 exposes no company-wide reporting function');
select ok(position('not a ninth controlled-function category' in lower(obj_description('public.create_shipment_expense(uuid,public.expense_category,numeric,date,text)'::regprocedure)))>0,'Expense workflow explicitly preserves the eight-category invariant');

select * from finish();
rollback;
