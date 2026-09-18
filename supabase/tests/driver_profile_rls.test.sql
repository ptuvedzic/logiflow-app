begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

insert into auth.users (id)
values
  ('14000000-0000-0000-0000-000000000001'),
  ('14000000-0000-0000-0000-000000000002'),
  ('14000000-0000-0000-0000-000000000003'),
  ('14000000-0000-0000-0000-000000000004'),
  ('14000000-0000-0000-0000-000000000005');

insert into public.profiles (id, full_name, username, role, is_active)
values
  ('14000000-0000-0000-0000-000000000001', 'C5 Driver A', 'c5-driver-a', 'driver', true),
  ('14000000-0000-0000-0000-000000000002', 'C5 Driver B', 'c5-driver-b', 'driver', true),
  ('14000000-0000-0000-0000-000000000003', 'C5 Inactive Driver', 'c5-inactive', 'driver', false),
  ('14000000-0000-0000-0000-000000000004', 'C5 Admin', 'c5-admin', 'admin', true),
  ('14000000-0000-0000-0000-000000000005', 'C5 Dispatcher', 'c5-dispatcher', 'dispatcher', true);

insert into public.drivers (id, profile_id, phone, status)
values
  ('24000000-0000-0000-0000-000000000001', '14000000-0000-0000-0000-000000000001', '+381600000001', 'available'),
  ('24000000-0000-0000-0000-000000000002', '14000000-0000-0000-0000-000000000002', '+381600000002', 'off_duty'),
  ('24000000-0000-0000-0000-000000000003', '14000000-0000-0000-0000-000000000003', '+381600000003', 'inactive');

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000001', true);

select results_eq(
  $$select full_name, username from public.profiles$$,
  $$values ('C5 Driver A'::text, 'c5-driver-a'::text)$$,
  'Driver A reads their permitted own profile presentation fields'
);

select is_empty(
  $$select id from public.profiles where id = '14000000-0000-0000-0000-000000000002'::uuid$$,
  'Driver A cannot probe Driver B profile by ID'
);

select results_eq(
  $$select id, profile_id from public.drivers$$,
  $$values ('24000000-0000-0000-0000-000000000001'::uuid, '14000000-0000-0000-0000-000000000001'::uuid)$$,
  'Driver A resolves only their own permitted Driver identity row'
);

select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000002', true);

select is_empty(
  $$select id from public.drivers where id = '24000000-0000-0000-0000-000000000001'::uuid$$,
  'Driver B cannot probe Driver A Driver row by ID'
);

select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000003', true);

select is_empty(
  $$select id from public.drivers$$,
  'Inactive Driver cannot use the own-active-Driver policy'
);

select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000004', true);

select is(
  (select count(*) from public.drivers),
  3::bigint,
  'Active Admin can read Operations Driver master-data rows'
);

select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000005', true);

select is(
  (select count(*) from public.drivers),
  3::bigint,
  'Active Dispatcher can read Operations Driver master-data rows'
);

select set_config('request.jwt.claim.sub', '14000000-0000-0000-0000-000000000001', true);

select throws_ok(
  $$select phone, status, created_at, updated_at from public.drivers$$,
  '42501',
  null,
  'Driver cannot read ungranted Driver presentation and audit columns'
);

select throws_ok(
  $$update public.profiles set full_name = 'Changed' where id = '14000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Driver cannot update profile fields'
);

select throws_ok(
  $$update public.drivers set profile_id = '14000000-0000-0000-0000-000000000002'::uuid where id = '24000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Driver cannot update Driver fields or ownership'
);

select throws_ok(
  $$insert into public.profiles (id, full_name, username, role) values ('14000000-0000-0000-0000-000000000099', 'Denied', 'c5-denied', 'driver')$$,
  '42501',
  null,
  'Driver cannot insert profiles'
);

select throws_ok(
  $$delete from public.profiles where id = '14000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Driver cannot delete profiles'
);

select throws_ok(
  $$insert into public.drivers (id, profile_id, status) values ('24000000-0000-0000-0000-000000000099', '14000000-0000-0000-0000-000000000001', 'available')$$,
  '42501',
  null,
  'Driver cannot insert Driver rows'
);

select throws_ok(
  $$delete from public.drivers where id = '24000000-0000-0000-0000-000000000001'::uuid$$,
  '42501',
  null,
  'Driver cannot delete Driver rows'
);

reset role;
set local role anon;

select throws_ok(
  $$select id from public.profiles$$,
  '42501',
  null,
  'Anonymous users cannot read profiles'
);

select throws_ok(
  $$select id from public.drivers$$,
  '42501',
  null,
  'Anonymous users cannot read Driver rows'
);

reset role;
select * from finish();
rollback;
