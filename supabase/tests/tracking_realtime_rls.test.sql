begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select ok(exists(select 1 from pg_catalog.pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='vehicle_locations'),'vehicle locations is published');
select ok(not exists(select 1 from pg_catalog.pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='tracking_history'),'tracking history is not published');
select ok(has_table_privilege('authenticated','public.vehicle_locations','SELECT'),'authenticated receives select grant');
select ok(not has_table_privilege('authenticated','public.vehicle_locations','INSERT'),'authenticated cannot insert locations');
select ok(not has_table_privilege('authenticated','public.vehicle_locations','UPDATE'),'authenticated cannot update locations');
select ok(not has_table_privilege('authenticated','public.vehicle_locations','DELETE'),'authenticated cannot delete locations');

insert into auth.users(id) values
('f1000000-0000-0000-0000-000000000001'),('f1000000-0000-0000-0000-000000000002'),
('f1000000-0000-0000-0000-000000000003'),('f1000000-0000-0000-0000-000000000004');
insert into public.profiles(id,full_name,username,role,is_active) values
('f1000000-0000-0000-0000-000000000001','Tracking Admin','tracking-admin','admin',true),
('f1000000-0000-0000-0000-000000000002','Tracking Dispatcher','tracking-dispatcher','dispatcher',true),
('f1000000-0000-0000-0000-000000000003','Tracking Driver','tracking-driver','driver',true),
('f1000000-0000-0000-0000-000000000004','Other Driver','tracking-other','driver',true);
insert into public.drivers(id,profile_id,status) values
('f2000000-0000-0000-0000-000000000001','f1000000-0000-0000-0000-000000000003','assigned'),
('f2000000-0000-0000-0000-000000000002','f1000000-0000-0000-0000-000000000004','assigned');
insert into public.clients(id,company_name,status) values('f3000000-0000-0000-0000-000000000001','Tracking Client','active');
insert into public.vehicles(id,registration,make,model,vehicle_type,status) values
('f4000000-0000-0000-0000-000000000001','S4-RLS-1','Make','One','Truck','in_use'),
('f4000000-0000-0000-0000-000000000002','S4-RLS-2','Make','Two','Truck','in_use');
insert into public.shipments(id,tracking_number,client_id,pickup_address,delivery_address,pickup_at,expected_delivery_at,cargo_type,driver_id,vehicle_id,price,status) values
('f5000000-0000-0000-0000-000000000001','SHP-S4-RLS-1','f3000000-0000-0000-0000-000000000001','A','B',now(),now()+interval '1 hour','Cargo','f2000000-0000-0000-0000-000000000001','f4000000-0000-0000-0000-000000000001',1,'in_transit'),
('f5000000-0000-0000-0000-000000000002','SHP-S4-RLS-2','f3000000-0000-0000-0000-000000000001','A','B',now(),now()+interval '1 hour','Cargo','f2000000-0000-0000-0000-000000000002','f4000000-0000-0000-0000-000000000002',1,'in_transit');
insert into public.vehicle_locations(vehicle_id,shipment_id,latitude,longitude) values
('f4000000-0000-0000-0000-000000000001','f5000000-0000-0000-0000-000000000001',45.2671,19.8335),
('f4000000-0000-0000-0000-000000000002','f5000000-0000-0000-0000-000000000002',45.2671,19.8335);

set local role authenticated;
set local "request.jwt.claim.sub"='f1000000-0000-0000-0000-000000000001';
select is((select count(*) from public.vehicle_locations),2::bigint,'active Admin sees active fleet');
set local "request.jwt.claim.sub"='f1000000-0000-0000-0000-000000000002';
select is((select count(*) from public.vehicle_locations),2::bigint,'active Dispatcher sees active fleet');
set local "request.jwt.claim.sub"='f1000000-0000-0000-0000-000000000003';
select is((select count(*) from public.vehicle_locations),1::bigint,'Driver sees only own current assignment');
select is((select vehicle_id from public.vehicle_locations),'f4000000-0000-0000-0000-000000000001'::uuid,'Driver receives the assigned vehicle row');
reset role;
set local role anon;
select throws_ok($$select * from public.vehicle_locations$$,'42501',null,'anonymous role cannot read tracking rows');
reset role;
select * from finish();
rollback;
