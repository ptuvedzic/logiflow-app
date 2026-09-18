begin;

create extension if not exists pgtap with schema extensions;

select plan(25);

insert into auth.users (id)
values
  ('12000000-0000-0000-0000-000000000001'),
  ('12000000-0000-0000-0000-000000000002'),
  ('12000000-0000-0000-0000-000000000003'),
  ('12000000-0000-0000-0000-000000000004'),
  ('12000000-0000-0000-0000-000000000005'),
  ('12000000-0000-0000-0000-000000000006');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('12000000-0000-0000-0000-000000000001', 'C3 Driver A', 'c3-driver-a', 'driver', true),
  ('12000000-0000-0000-0000-000000000002', 'C3 Driver B', 'c3-driver-b', 'driver', true),
  ('12000000-0000-0000-0000-000000000003', 'C3 No Current', 'c3-no-current', 'driver', true),
  ('12000000-0000-0000-0000-000000000004', 'C3 Inactive', 'c3-inactive', 'driver', false),
  ('12000000-0000-0000-0000-000000000005', 'C3 Admin', 'c3-admin', 'admin', true),
  ('12000000-0000-0000-0000-000000000006', 'C3 Dispatcher', 'c3-dispatcher', 'dispatcher', true);

insert into public.drivers (id, profile_id, status)
values
  ('22000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000001', 'assigned'),
  ('22000000-0000-0000-0000-000000000002', '12000000-0000-0000-0000-000000000002', 'assigned'),
  ('22000000-0000-0000-0000-000000000003', '12000000-0000-0000-0000-000000000003', 'available'),
  ('22000000-0000-0000-0000-000000000004', '12000000-0000-0000-0000-000000000004', 'assigned');

insert into public.clients (id, company_name)
values ('32000000-0000-0000-0000-000000000001', 'C3 Client');

insert into public.vehicles (id, registration, make, model, vehicle_type, status)
values
  ('42000000-0000-0000-0000-000000000001', 'C3-A', 'Test', 'A', 'Truck', 'in_use'),
  ('42000000-0000-0000-0000-000000000002', 'C3-B', 'Test', 'B', 'Truck', 'in_use'),
  ('42000000-0000-0000-0000-000000000003', 'C3-H', 'Test', 'History', 'Truck', 'available'),
  ('42000000-0000-0000-0000-000000000004', 'C3-I', 'Test', 'Inactive', 'Truck', 'in_use');

insert into public.shipments (
  id, tracking_number, client_id, pickup_address, delivery_address,
  pickup_at, expected_delivery_at, cargo_type, driver_id, vehicle_id, price, status
)
values
  (
    '52000000-0000-0000-0000-000000000001', 'SHP-C3-A',
    '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo',
    '22000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', 100, 'assigned'
  ),
  (
    '52000000-0000-0000-0000-000000000002', 'SHP-C3-B',
    '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo',
    '22000000-0000-0000-0000-000000000002', '42000000-0000-0000-0000-000000000002', 100, 'in_transit'
  ),
  (
    '52000000-0000-0000-0000-000000000003', 'SHP-C3-HISTORY',
    '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo',
    '22000000-0000-0000-0000-000000000003', '42000000-0000-0000-0000-000000000003', 100, 'delivered'
  ),
  (
    '52000000-0000-0000-0000-000000000004', 'SHP-C3-INACTIVE',
    '32000000-0000-0000-0000-000000000001', 'A', 'B', now(), now(), 'Cargo',
    '22000000-0000-0000-0000-000000000004', '42000000-0000-0000-0000-000000000004', 100, 'loading'
  );

insert into public.documents (
  id, shipment_id, vehicle_id, driver_id, uploader_profile_id,
  document_type, file_path, file_name, lifecycle_status
)
values
  (
    '62000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', null, null,
    '12000000-0000-0000-0000-000000000005', 'proof_of_delivery',
    'shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000001/pod-a.pdf',
    'pod-a.pdf', 'active'
  ),
  (
    '62000000-0000-0000-0000-000000000002', '52000000-0000-0000-0000-000000000002', null, null,
    '12000000-0000-0000-0000-000000000005', 'proof_of_delivery',
    'shipment/52000000-0000-0000-0000-000000000002/62000000-0000-0000-0000-000000000002/pod-b.pdf',
    'pod-b.pdf', 'active'
  ),
  (
    '62000000-0000-0000-0000-000000000003', '52000000-0000-0000-0000-000000000003', null, null,
    '12000000-0000-0000-0000-000000000005', 'proof_of_delivery',
    'shipment/52000000-0000-0000-0000-000000000003/62000000-0000-0000-0000-000000000003/pod-history.pdf',
    'pod-history.pdf', 'active'
  ),
  (
    '62000000-0000-0000-0000-000000000004', '52000000-0000-0000-0000-000000000001', null, null,
    '12000000-0000-0000-0000-000000000005', 'proof_of_delivery',
    'shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000004/pod-archived.pdf',
    'pod-archived.pdf', 'archived'
  ),
  (
    '62000000-0000-0000-0000-000000000005', '52000000-0000-0000-0000-000000000001', null, null,
    '12000000-0000-0000-0000-000000000005', 'cmr',
    'shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000005/cmr.pdf',
    'cmr.pdf', 'active'
  ),
  (
    '62000000-0000-0000-0000-000000000006', null, '42000000-0000-0000-0000-000000000001', null,
    '12000000-0000-0000-0000-000000000005', 'registration',
    'vehicle/42000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000006/registration.pdf',
    'registration.pdf', 'active'
  ),
  (
    '62000000-0000-0000-0000-000000000007', null, null, '22000000-0000-0000-0000-000000000001',
    '12000000-0000-0000-0000-000000000005', 'driving_license',
    'driver/22000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000007/license.pdf',
    'license.pdf', 'active'
  ),
  (
    '62000000-0000-0000-0000-000000000008', '52000000-0000-0000-0000-000000000004', null, null,
    '12000000-0000-0000-0000-000000000005', 'proof_of_delivery',
    'shipment/52000000-0000-0000-0000-000000000004/62000000-0000-0000-0000-000000000008/pod-inactive.pdf',
    'pod-inactive.pdf', 'active'
  );

insert into storage.objects (bucket_id, name, owner_id)
select 'documents', file_path, uploader_profile_id::text
from public.documents;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select id, file_name from public.documents order by id$$,
  $$values ('62000000-0000-0000-0000-000000000001'::uuid, 'pod-a.pdf'::text)$$,
  'Driver A reads only their active current-shipment POD metadata'
);

select results_eq(
  $$select name from storage.objects order by name$$,
  $$values ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000001/pod-a.pdf'::text)$$,
  'Driver A reads only the exact authorized Storage object'
);

select is_empty(
  $$select id from public.documents where id = '62000000-0000-0000-0000-000000000002'::uuid$$,
  'Driver A cannot probe Driver B document UUID'
);

select is_empty(
  $$select name from storage.objects where name = 'shipment/arbitrary/object.pdf'$$,
  'Arbitrary object-name probing returns no object'
);

select is_empty(
  $$select name from storage.objects where name like 'shipment/52000000-0000-0000-0000-000000000002/%'$$,
  'Unauthorized prefix probing returns no objects'
);

select is_empty(
  $$select id from public.documents where id in ('62000000-0000-0000-0000-000000000003', '62000000-0000-0000-0000-000000000004')$$,
  'Historical and archived PODs remain hidden'
);

select is_empty(
  $$select id from public.documents where id in ('62000000-0000-0000-0000-000000000005', '62000000-0000-0000-0000-000000000006', '62000000-0000-0000-0000-000000000007')$$,
  'Non-POD, Vehicle-owned, and Driver-owned documents remain hidden'
);

select throws_ok(
  $$select uploader_profile_id, valid_from, valid_until, updated_at from public.documents$$,
  '42501', null,
  'Driver cannot read ungranted document metadata columns'
);

select throws_ok(
  $$insert into public.documents (id, shipment_id, uploader_profile_id, document_type, file_path, file_name) values ('62000000-0000-0000-0000-000000000099', '52000000-0000-0000-0000-000000000001', '12000000-0000-0000-0000-000000000001', 'proof_of_delivery', 'denied.pdf', 'denied.pdf')$$,
  '42501', null,
  'Document metadata insert remains denied'
);

select throws_ok(
  $$update public.documents set file_name = 'changed.pdf' where id = '62000000-0000-0000-0000-000000000001'$$,
  '42501', null,
  'Document metadata update remains denied'
);

select throws_ok(
  $$delete from public.documents where id = '62000000-0000-0000-0000-000000000001'$$,
  '42501', null,
  'Document metadata delete remains denied'
);

select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('documents', 'shipment/denied.pdf')$$,
  '42501', null,
  'Storage insert remains denied'
);

select is_empty(
  $$update storage.objects set name = 'changed.pdf' where bucket_id = 'documents' returning name$$,
  'Storage update remains denied by affecting no objects'
);

select throws_ok(
  $$delete from storage.objects where bucket_id = 'documents'$$,
  '42501', null,
  'Storage delete remains denied'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000002', true);

select results_eq(
  $$select file_name from public.documents$$,
  $$values ('pod-b.pdf'::text)$$,
  'Driver B reads only Driver B POD metadata'
);

select is_empty(
  $$select id from public.documents where id = '62000000-0000-0000-0000-000000000001'::uuid$$,
  'Driver B cannot read Driver A metadata'
);

select is_empty(
  $$select name from storage.objects where name like '%pod-a.pdf'$$,
  'Driver B cannot read Driver A Storage object'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000003', true);
select is_empty($$select id from public.documents$$, 'Driver with no current shipment reads no POD');

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000004', true);
select is_empty($$select id from public.documents$$, 'Inactive Driver reads no POD');

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000005', true);
select results_eq(
  $$select id from public.documents order by id$$,
  $$values
    ('62000000-0000-0000-0000-000000000001'::uuid), ('62000000-0000-0000-0000-000000000002'::uuid),
    ('62000000-0000-0000-0000-000000000003'::uuid), ('62000000-0000-0000-0000-000000000004'::uuid),
    ('62000000-0000-0000-0000-000000000005'::uuid), ('62000000-0000-0000-0000-000000000006'::uuid),
    ('62000000-0000-0000-0000-000000000007'::uuid), ('62000000-0000-0000-0000-000000000008'::uuid)$$,
  'Active Admin reads all retained document metadata rows through the D1 Operations policy'
);
select results_eq(
  $$select name from storage.objects order by name$$,
  $$values
    ('driver/22000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000007/license.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000001/pod-a.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000004/pod-archived.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000005/cmr.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000002/62000000-0000-0000-0000-000000000002/pod-b.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000003/62000000-0000-0000-0000-000000000003/pod-history.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000004/62000000-0000-0000-0000-000000000008/pod-inactive.pdf'::text),
    ('vehicle/42000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000006/registration.pdf'::text)$$,
  'Active Admin reads retained private objects through the D1 Operations Storage policy'
);

select set_config('request.jwt.claim.sub', '12000000-0000-0000-0000-000000000006', true);
select results_eq(
  $$select id from public.documents order by id$$,
  $$values
    ('62000000-0000-0000-0000-000000000001'::uuid), ('62000000-0000-0000-0000-000000000002'::uuid),
    ('62000000-0000-0000-0000-000000000003'::uuid), ('62000000-0000-0000-0000-000000000004'::uuid),
    ('62000000-0000-0000-0000-000000000005'::uuid), ('62000000-0000-0000-0000-000000000006'::uuid),
    ('62000000-0000-0000-0000-000000000007'::uuid), ('62000000-0000-0000-0000-000000000008'::uuid)$$,
  'Active Dispatcher reads all retained document metadata rows through the D1 Operations policy'
);
select results_eq(
  $$select name from storage.objects order by name$$,
  $$values
    ('driver/22000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000007/license.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000001/pod-a.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000004/pod-archived.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000005/cmr.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000002/62000000-0000-0000-0000-000000000002/pod-b.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000003/62000000-0000-0000-0000-000000000003/pod-history.pdf'::text),
    ('shipment/52000000-0000-0000-0000-000000000004/62000000-0000-0000-0000-000000000008/pod-inactive.pdf'::text),
    ('vehicle/42000000-0000-0000-0000-000000000001/62000000-0000-0000-0000-000000000006/registration.pdf'::text)$$,
  'Active Dispatcher reads retained private objects through the D1 Operations Storage policy'
);

reset role;
set local role anon;
select throws_ok($$select id from public.documents$$, '42501', null, 'Anon cannot read document metadata');
select is_empty($$select name from storage.objects$$, 'Anon cannot read document objects');

reset role;
select * from finish();
rollback;
