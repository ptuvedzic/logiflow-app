begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

insert into auth.users (id)
values
  ('16000000-0000-0000-0000-000000000001'),
  ('16000000-0000-0000-0000-000000000002'),
  ('16000000-0000-0000-0000-000000000003'),
  ('16000000-0000-0000-0000-000000000004');

set local role service_role;

select ok(
  public.auth_username_local_part(' A1-Mapping ') = 'u1-61312d6d617070696e67',
  'Service role can reuse the canonical username mapping contract'
);

select lives_ok(
  $$select public.provision_account_profile(
    '16000000-0000-0000-0000-000000000001'::uuid,
    'A1 Dispatcher',
    'a1-dispatcher',
    'dispatcher',
    null
  )$$,
  'Service role provisions a Dispatcher account'
);

reset role;

select results_eq(
  $$select id, full_name, username, role, is_active
    from public.profiles
    where id = '16000000-0000-0000-0000-000000000001'::uuid$$,
  $$values (
    '16000000-0000-0000-0000-000000000001'::uuid,
    'A1 Dispatcher'::text,
    'a1-dispatcher'::text,
    'dispatcher'::public.profile_role,
    true
  )$$,
  'Dispatcher profile is active and matches the Auth user ID'
);

select is_empty(
  $$select id from public.drivers
    where profile_id = '16000000-0000-0000-0000-000000000001'::uuid$$,
  'Dispatcher provisioning creates no Driver row'
);

set local role service_role;

select lives_ok(
  $$select public.provision_account_profile(
    '16000000-0000-0000-0000-000000000002'::uuid,
    'A1 Driver',
    'a1-driver',
    'driver',
    '26000000-0000-0000-0000-000000000002'::uuid
  )$$,
  'Service role provisions a Driver account atomically'
);

reset role;

select results_eq(
  $$select id, role, is_active
    from public.profiles
    where id = '16000000-0000-0000-0000-000000000002'::uuid$$,
  $$values (
    '16000000-0000-0000-0000-000000000002'::uuid,
    'driver'::public.profile_role,
    true
  )$$,
  'Driver profile is active and matches the Auth user ID'
);

select results_eq(
  $$select id, profile_id, phone, status
    from public.drivers
    where profile_id = '16000000-0000-0000-0000-000000000002'::uuid$$,
  $$values (
    '26000000-0000-0000-0000-000000000002'::uuid,
    '16000000-0000-0000-0000-000000000002'::uuid,
    null::text,
    'available'::public.driver_status
  )$$,
  'Driver row belongs to the profile and defaults to available with no phone'
);

set local role service_role;

select throws_ok(
  $$select public.provision_account_profile(
    '16000000-0000-0000-0000-000000000003'::uuid,
    'A1 Unsupported',
    'a1-unsupported',
    'admin',
    null
  )$$,
  '22023',
  'Unsupported account role.',
  'Unsupported roles are rejected'
);

reset role;

select is_empty(
  $$select id from public.profiles
    where id = '16000000-0000-0000-0000-000000000003'::uuid$$,
  'Unsupported role failure leaves no profile'
);

set local role service_role;

select throws_ok(
  $$select public.provision_account_profile(
    '16000000-0000-0000-0000-000000000004'::uuid,
    'A1 Atomic Driver',
    'a1-driver',
    'driver',
    '26000000-0000-0000-0000-000000000004'::uuid
  )$$,
  '23505',
  null,
  'A transaction failure is surfaced'
);

reset role;

select is_empty(
  $$select id from public.profiles
    where id = '16000000-0000-0000-0000-000000000004'::uuid$$,
  'Transaction failure rolls back the profile insert'
);

set local role authenticated;

select throws_ok(
  $$select public.provision_account_profile(
    '16000000-0000-0000-0000-000000000003'::uuid,
    'Denied',
    'a1-denied',
    'dispatcher',
    null
  )$$,
  '42501',
  null,
  'Authenticated users cannot execute account provisioning'
);

reset role;
set local role anon;

select throws_ok(
  $$select public.provision_account_profile(
    '16000000-0000-0000-0000-000000000003'::uuid,
    'Denied',
    'a1-denied',
    'dispatcher',
    null
  )$$,
  '42501',
  null,
  'Anonymous users cannot execute account provisioning'
);

reset role;
select * from finish();
rollback;
