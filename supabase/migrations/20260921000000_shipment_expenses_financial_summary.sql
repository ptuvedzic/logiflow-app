create function public.get_operations_shipment_financial_detail(target_shipment_id uuid)
returns table (
  id uuid,
  tracking_number text,
  shipment_status public.shipment_status,
  delayed boolean,
  client_company text,
  pickup_address text,
  delivery_address text,
  pickup_at timestamptz,
  expected_delivery_at timestamptz,
  cargo_type text,
  revenue numeric,
  total_expenses numeric,
  profit numeric,
  expense_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'expense_read_access_denied';
  end if;

  return query
  select shipments.id,
    shipments.tracking_number,
    shipments.status,
    shipments.delayed,
    clients.company_name,
    shipments.pickup_address,
    shipments.delivery_address,
    shipments.pickup_at,
    shipments.expected_delivery_at,
    shipments.cargo_type,
    shipments.price,
    coalesce(sum(expenses.amount), 0::numeric),
    shipments.price - coalesce(sum(expenses.amount), 0::numeric),
    count(expenses.id)
  from public.shipments
  join public.clients on clients.id = shipments.client_id
  left join public.expenses on expenses.shipment_id = shipments.id
  where shipments.id = target_shipment_id
  group by shipments.id, clients.company_name;
end;
$$;

create function public.list_shipment_expenses(target_shipment_id uuid)
returns table (
  id uuid,
  category public.expense_category,
  amount numeric,
  expense_date date,
  description text,
  creator_name text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.profiles
    where profiles.id = (select auth.uid())
      and profiles.is_active
      and profiles.role in ('admin', 'dispatcher')
  ) then
    raise exception using errcode = '42501', message = 'expense_read_access_denied';
  end if;

  if not exists (select 1 from public.shipments where shipments.id = target_shipment_id) then
    raise exception using errcode = 'P0001', message = 'expense_shipment_not_found';
  end if;

  return query
  select expenses.id,
    expenses.category,
    expenses.amount,
    expenses.expense_date,
    expenses.description,
    profiles.full_name,
    expenses.created_at,
    expenses.updated_at
  from public.expenses
  join public.profiles on profiles.id = expenses.created_by_profile_id
  where expenses.shipment_id = target_shipment_id
  order by expenses.expense_date desc, expenses.created_at desc, expenses.id desc;
end;
$$;

create function public.create_shipment_expense(
  target_shipment_id uuid,
  input_category public.expense_category,
  input_amount numeric,
  input_expense_date date,
  input_description text default null
)
returns table (id uuid, updated_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_role public.profile_role;
  expense_id uuid := gen_random_uuid();
  normalized_description text := nullif(pg_catalog.btrim(input_description), '');
  result_updated_at timestamptz;
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = actor_id and profiles.is_active
  for update;
  if not found or actor_role not in ('admin', 'dispatcher') then
    raise exception using errcode = '42501', message = 'expense_mutation_access_denied';
  end if;

  if input_category is null
    or input_amount is null
    or input_amount <= 0
    or input_amount > 9999999999.99
    or input_expense_date is null
  then
    raise exception using errcode = 'P0001', message = 'expense_validation_failed';
  end if;

  perform 1
  from public.shipments
  where shipments.id = target_shipment_id
  for key share;
  if not found then
    raise exception using errcode = 'P0001', message = 'expense_shipment_not_found';
  end if;

  insert into public.expenses (
    id, shipment_id, created_by_profile_id, category, amount, expense_date, description
  ) values (
    expense_id, target_shipment_id, actor_id, input_category, input_amount,
    input_expense_date, normalized_description
  )
  returning expenses.updated_at into result_updated_at;

  insert into public.activity_logs (
    id, actor_profile_id, action_type, expense_id, metadata
  ) values (
    gen_random_uuid(), actor_id, 'expense_created', expense_id,
    pg_catalog.jsonb_build_object('category', input_category, 'amount', input_amount)
  );

  return query select expense_id, result_updated_at;
end;
$$;

create function public.update_shipment_expense(
  target_expense_id uuid,
  target_shipment_id uuid,
  expected_updated_at timestamptz,
  input_category public.expense_category,
  input_amount numeric,
  input_expense_date date,
  input_description text default null
)
returns table (mutation_result text, updated_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  actor_role public.profile_role;
  target_expense public.expenses%rowtype;
  normalized_description text := nullif(pg_catalog.btrim(input_description), '');
  changed_fields text[] := array[]::text[];
  result_updated_at timestamptz;
begin
  select profiles.role into actor_role
  from public.profiles
  where profiles.id = actor_id and profiles.is_active
  for update;
  if not found or actor_role not in ('admin', 'dispatcher') then
    raise exception using errcode = '42501', message = 'expense_mutation_access_denied';
  end if;

  if expected_updated_at is null
    or input_category is null
    or input_amount is null
    or input_amount <= 0
    or input_amount > 9999999999.99
    or input_expense_date is null
  then
    raise exception using errcode = 'P0001', message = 'expense_validation_failed';
  end if;

  select * into target_expense
  from public.expenses
  where expenses.id = target_expense_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'expense_not_found';
  end if;
  if target_expense.shipment_id is distinct from target_shipment_id then
    raise exception using errcode = 'P0001', message = 'expense_not_found';
  end if;
  if target_expense.updated_at is distinct from expected_updated_at then
    raise exception using errcode = '40001', message = 'expense_stale';
  end if;

  if target_expense.category is distinct from input_category then changed_fields := pg_catalog.array_append(changed_fields, 'category'); end if;
  if target_expense.amount is distinct from input_amount then changed_fields := pg_catalog.array_append(changed_fields, 'amount'); end if;
  if target_expense.expense_date is distinct from input_expense_date then changed_fields := pg_catalog.array_append(changed_fields, 'expense_date'); end if;
  if target_expense.description is distinct from normalized_description then changed_fields := pg_catalog.array_append(changed_fields, 'description'); end if;

  if pg_catalog.cardinality(changed_fields) = 0 then
    return query select 'noop'::text, target_expense.updated_at;
    return;
  end if;

  update public.expenses
  set category = input_category,
    amount = input_amount,
    expense_date = input_expense_date,
    description = normalized_description
  where expenses.id = target_expense.id
  returning expenses.updated_at into result_updated_at;

  insert into public.activity_logs (
    id, actor_profile_id, action_type, expense_id, metadata
  ) values (
    gen_random_uuid(), actor_id, 'expense_updated', target_expense.id,
    pg_catalog.jsonb_build_object('changed_fields', changed_fields)
  );

  return query select 'updated'::text, result_updated_at;
end;
$$;

revoke all on function public.get_operations_shipment_financial_detail(uuid) from public, anon, authenticated;
revoke all on function public.list_shipment_expenses(uuid) from public, anon, authenticated;
revoke all on function public.create_shipment_expense(uuid, public.expense_category, numeric, date, text) from public, anon, authenticated;
revoke all on function public.update_shipment_expense(uuid, uuid, timestamptz, public.expense_category, numeric, date, text) from public, anon, authenticated;

grant execute on function public.get_operations_shipment_financial_detail(uuid) to authenticated;
grant execute on function public.list_shipment_expenses(uuid) to authenticated;
grant execute on function public.create_shipment_expense(uuid, public.expense_category, numeric, date, text) to authenticated;
grant execute on function public.update_shipment_expense(uuid, uuid, timestamptz, public.expense_category, numeric, date, text) to authenticated;

comment on function public.create_shipment_expense(uuid, public.expense_category, numeric, date, text)
is 'Atomic Expense workflow: derives the active Operations actor and creates one retained Shipment expense plus one expense_created activity. This is not a ninth controlled-function category.';
comment on function public.update_shipment_expense(uuid, uuid, timestamptz, public.expense_category, numeric, date, text)
is 'Atomic Expense workflow: optimistic update plus one expense_updated activity for meaningful changes. This is not a ninth controlled-function category.';
