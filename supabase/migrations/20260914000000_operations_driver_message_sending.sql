do $block$
begin
  if exists (
    select 1
    from public.messages
    where body is distinct from pg_catalog.btrim(body)
      or pg_catalog.char_length(body) not between 1 and 500
  ) then
    raise exception using
      errcode = '23514',
      message = 'messages_body_contract_preflight_failed';
  end if;
end;
$block$;

alter table public.messages
  add constraint messages_body_trimmed_check
    check (body = pg_catalog.btrim(body)),
  add constraint messages_body_length_check
    check (pg_catalog.char_length(body) between 1 and 500);

create index messages_sender_sent_at_idx
on public.messages (sender_profile_id, sent_at desc);

create function public.list_message_recipient_options()
returns table (
  id uuid,
  display_name text
)
language sql
stable
security definer
set search_path = ''
as $function$
  select drivers.id, profiles.full_name
  from public.drivers
  join public.profiles on profiles.id = drivers.profile_id
  where exists (
    select 1
    from public.profiles actor
    where actor.id = auth.uid()
      and actor.is_active
      and actor.role in ('admin', 'dispatcher')
  )
    and profiles.is_active
    and profiles.role = 'driver'
    and drivers.status in ('available', 'assigned', 'off_duty')
  order by profiles.full_name, drivers.id;
$function$;

create function public.list_message_shipment_options()
returns table (
  id uuid,
  tracking_number text,
  driver_id uuid,
  status public.shipment_status
)
language sql
stable
security definer
set search_path = ''
as $function$
  select shipments.id, shipments.tracking_number, shipments.driver_id, shipments.status
  from public.shipments
  where exists (
    select 1
    from public.profiles actor
    where actor.id = auth.uid()
      and actor.is_active
      and actor.role in ('admin', 'dispatcher')
  )
    and shipments.driver_id is not null
  order by shipments.tracking_number, shipments.id;
$function$;

create function public.send_driver_message(
  target_driver_id uuid,
  target_shipment_id uuid,
  input_body text
)
returns table (
  message_id uuid,
  notification_id uuid,
  sent_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  actor_id uuid := auth.uid();
  recipient_profile_id uuid;
  normalized_body text;
  actor_profile public.profiles%rowtype;
  recipient_profile public.profiles%rowtype;
  recipient_driver public.drivers%rowtype;
  target_shipment public.shipments%rowtype;
  recent_send_count bigint;
  created_message_id uuid := gen_random_uuid();
  created_notification_id uuid := gen_random_uuid();
  created_at timestamptz := pg_catalog.transaction_timestamp();
begin
  normalized_body := pg_catalog.btrim(input_body);

  if target_driver_id is null
    or input_body is null
    or normalized_body = ''
    or pg_catalog.char_length(normalized_body) > 500 then
    raise exception using errcode = '22023', message = 'message_send_body_invalid';
  end if;

  if actor_id is null then
    raise exception using errcode = '42501', message = 'message_send_access_denied';
  end if;

  select drivers.profile_id
  into recipient_profile_id
  from public.drivers
  where drivers.id = target_driver_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'message_send_driver_unavailable';
  end if;

  perform profiles.id
  from public.profiles
  where profiles.id in (actor_id, recipient_profile_id)
  order by profiles.id
  for update;

  select profiles.*
  into actor_profile
  from public.profiles
  where profiles.id = actor_id;

  if not found
    or not actor_profile.is_active
    or actor_profile.role not in ('admin', 'dispatcher') then
    raise exception using errcode = '42501', message = 'message_send_access_denied';
  end if;

  select profiles.*
  into recipient_profile
  from public.profiles
  where profiles.id = recipient_profile_id;

  if not found
    or not recipient_profile.is_active
    or recipient_profile.role <> 'driver' then
    raise exception using errcode = 'P0002', message = 'message_send_driver_unavailable';
  end if;

  select drivers.*
  into recipient_driver
  from public.drivers
  where drivers.id = target_driver_id
    and drivers.profile_id = recipient_profile.id
  for update;

  if not found
    or recipient_driver.status not in ('available', 'assigned', 'off_duty') then
    raise exception using errcode = 'P0002', message = 'message_send_driver_unavailable';
  end if;

  if target_shipment_id is not null then
    select shipments.*
    into target_shipment
    from public.shipments
    where shipments.id = target_shipment_id
    for update;

    if not found then
      raise exception using errcode = 'P0002', message = 'message_send_shipment_unavailable';
    end if;

    if target_shipment.driver_id is null
      or target_shipment.driver_id <> recipient_driver.id then
      raise exception using errcode = 'P0001', message = 'message_send_shipment_driver_mismatch';
    end if;
  end if;

  select pg_catalog.count(*)
  into recent_send_count
  from public.messages
  where messages.sender_profile_id = actor_profile.id
    and messages.sent_at >= created_at - interval '10 minutes';

  if recent_send_count >= 10 then
    raise exception using errcode = 'P0001', message = 'message_send_rate_limited';
  end if;

  insert into public.messages (
    id, sender_profile_id, recipient_driver_id, shipment_id, body, sent_at, read_at
  ) values (
    created_message_id, actor_profile.id, recipient_driver.id,
    target_shipment_id, normalized_body, created_at, null
  );

  insert into public.notifications (
    id, recipient_profile_id, notification_type, title, message,
    shipment_id, vehicle_id, driver_id, document_id, created_at, read_at
  ) values (
    created_notification_id, recipient_profile.id, 'new_dispatcher_message',
    'New message from Operations',
    'You have received a new message from Operations.',
    target_shipment_id, null, null, null, created_at, null
  );

  return query select created_message_id, created_notification_id, created_at;
end;
$function$;

revoke all on function public.list_message_recipient_options() from public, anon, authenticated;
revoke all on function public.list_message_shipment_options() from public, anon, authenticated;
revoke all on function public.send_driver_message(uuid, uuid, text) from public, anon, authenticated;

grant execute on function public.list_message_recipient_options() to authenticated;
grant execute on function public.list_message_shipment_options() to authenticated;
grant execute on function public.send_driver_message(uuid, uuid, text) to authenticated;
