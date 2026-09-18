alter type public.activity_action_type add value if not exists 'document_restored' after 'document_archived';

create or replace function public.document_type_allowed(owner_kind text, candidate text)
returns boolean language sql immutable parallel safe set search_path = '' as $$
  select case owner_kind
    when 'vehicle' then candidate = any(array['registration','insurance','technical_inspection','road_tax','tachograph_calibration'])
    when 'shipment' then candidate = any(array['cmr','invoice','delivery_note','proof_of_delivery','photos'])
    when 'driver' then candidate = any(array['driving_license','professional_license','certificate'])
    else false end
$$;
revoke all on function public.document_type_allowed(text,text) from public, anon, authenticated;

alter table public.documents add constraint documents_canonical_type_check check (
  (vehicle_id is not null and public.document_type_allowed('vehicle', document_type)) or
  (shipment_id is not null and public.document_type_allowed('shipment', document_type)) or
  (driver_id is not null and public.document_type_allowed('driver', document_type))
) not valid;

create or replace function public.reconcile_document_expiry_alerts(target_document_id uuid, lifecycle_actor_profile_id uuid default null)
returns table(created_count integer,resolved_count integer,updated_count integer)
language plpgsql volatile security definer set search_path = '' as $function$
declare
  discovered public.documents%rowtype; target public.documents%rowtype; current_alert public.alerts%rowtype;
  expected_type public.alert_type; expected_severity public.alert_severity; expected_message text;
  eligible boolean := false; evaluation_time timestamptz := pg_catalog.clock_timestamp();
  created_total integer := 0; resolved_total integer := 0; old_type public.alert_type;
begin
  if lifecycle_actor_profile_id is null then
    if current_user not in ('postgres','service_role') then raise exception using errcode='42501',message='document_alert_access_denied'; end if;
  elsif lifecycle_actor_profile_id is distinct from (select auth.uid()) or not exists(
    select 1 from public.profiles where id=lifecycle_actor_profile_id and is_active and role in ('admin','dispatcher','driver')
  ) then raise exception using errcode='42501',message='document_alert_access_denied'; end if;

  select * into discovered from public.documents where id=target_document_id;
  if not found then raise exception using errcode='P0001',message='document_not_found'; end if;
  if discovered.driver_id is not null then perform 1 from public.drivers where id=discovered.driver_id for update;
  elsif discovered.vehicle_id is not null then perform 1 from public.vehicles where id=discovered.vehicle_id for update;
  else perform 1 from public.shipments where id=discovered.shipment_id for update; end if;
  select * into target from public.documents where id=target_document_id for update;
  if not found then raise exception using errcode='P0001',message='document_not_found'; end if;

  eligible := target.lifecycle_status='active' and target.valid_until is not null and (
    (target.driver_id is not null and exists(select 1 from public.drivers where id=target.driver_id and status not in ('inactive','archived'))) or
    (target.vehicle_id is not null and exists(select 1 from public.vehicles where id=target.vehicle_id and status <> 'archived')) or
    (target.shipment_id is not null and exists(select 1 from public.shipments where id=target.shipment_id and status in ('pending','assigned','loading','in_transit')))
  );
  if eligible and target.valid_until < current_date then expected_type:='document_expired'; expected_severity:='critical'; expected_message:=target.file_name||' expired on '||target.valid_until::text||'.';
  elsif eligible and target.valid_until <= current_date + 30 then expected_type:='document_expiring'; expected_severity:='warning'; expected_message:=target.file_name||' expires on '||target.valid_until::text||'.';
  else expected_type:=null; end if;

  if (select count(*) from public.alerts where document_id=target.id and alert_type in ('document_expiring','document_expired') and alert_state='active') > 1 then
    raise exception using errcode='P0001',message='document_alert_integrity';
  end if;
  select * into current_alert from public.alerts where document_id=target.id and alert_type in ('document_expiring','document_expired') and alert_state='active' order by id for update;
  if current_alert.id is not null and current_alert.alert_type is distinct from expected_type then
    old_type:=current_alert.alert_type;
    update public.alerts set alert_state='resolved',resolved_at=evaluation_time,resolved_by_profile_id=lifecycle_actor_profile_id where id=current_alert.id;
    insert into public.activity_logs(id,actor_profile_id,action_type,document_id,metadata,occurred_at)
    values(gen_random_uuid(),lifecycle_actor_profile_id,'alert_resolved',target.id,pg_catalog.jsonb_build_object('alert_type',old_type),evaluation_time);
    resolved_total:=1; current_alert:=null;
  end if;
  if expected_type is not null and current_alert.id is null then
    insert into public.alerts(id,alert_type,severity,message,document_id,created_at) values(gen_random_uuid(),expected_type,expected_severity,expected_message,target.id,evaluation_time);
    insert into public.activity_logs(id,actor_profile_id,action_type,document_id,metadata,occurred_at)
    values(gen_random_uuid(),lifecycle_actor_profile_id,'alert_created',target.id,pg_catalog.jsonb_build_object('alert_type',expected_type),evaluation_time);
    if target.driver_id is not null then
      insert into public.notifications(id,recipient_profile_id,notification_type,title,message,document_id,created_at)
      select gen_random_uuid(),drivers.profile_id,'driver_document_expiring',case when expected_type='document_expired' then 'Driver document expired' else 'Driver document expiring' end,expected_message,target.id,evaluation_time
      from public.drivers join public.profiles on profiles.id=drivers.profile_id where drivers.id=target.driver_id and profiles.is_active;
    elsif target.vehicle_id is not null then
      insert into public.notifications(id,recipient_profile_id,notification_type,title,message,document_id,created_at)
      select gen_random_uuid(),profiles.id,'vehicle_document_expiring',case when expected_type='document_expired' then 'Vehicle document expired' else 'Vehicle document expiring' end,expected_message,target.id,evaluation_time
      from public.profiles where profiles.is_active and profiles.role in ('admin','dispatcher');
    end if;
    created_total:=1;
  end if;
  return query select created_total,resolved_total,0;
end;$function$;

create function public.list_document_alert_ids(after_document_id uuid default null)
returns table(document_id uuid) language sql stable security definer set search_path = '' as $$
  select documents.id from public.documents where (after_document_id is null or documents.id>after_document_id)
  order by documents.id limit 50
$$;

create function public.list_abandoned_document_objects(after_object_name text default null)
returns table(object_name text) language plpgsql stable security definer set search_path = '' as $$
begin
  if current_user not in ('postgres','service_role') then raise exception using errcode='42501',message='document_cleanup_access_denied'; end if;
  return query select objects.name from storage.objects objects
  where objects.bucket_id='documents' and objects.created_at < pg_catalog.now()-interval '24 hours'
    and not exists(select 1 from public.documents where documents.file_path=objects.name)
    and (after_object_name is null or objects.name>after_object_name)
  order by objects.name limit 50;
end;$$;

create function public.list_operations_documents(search_text text default '',owner_filter text default null,type_filter text default null,lifecycle_filter text default 'active',validity_filter text default null,requested_page integer default 1)
returns table(id uuid,file_name text,document_type text,owner_type text,owner_label text,lifecycle_status public.document_lifecycle_status,valid_from date,valid_until date,derived_status text,uploaded_at timestamptz,updated_at timestamptz,total_count bigint)
language plpgsql stable security definer set search_path='' as $function$
declare actor_role public.profile_role; normalized text:=trim(coalesce(search_text,''));
begin
  select role into actor_role from public.profiles where id=(select auth.uid()) and is_active;
  if actor_role is null or actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_read_access_denied'; end if;
  if char_length(normalized)>100 or requested_page<1 or owner_filter is not null and owner_filter not in ('shipment','vehicle','driver') or lifecycle_filter not in ('active','archived','all') then raise exception using errcode='P0001',message='document_list_invalid'; end if;
  return query select d.id,d.file_name,d.document_type,
    case when d.shipment_id is not null then 'shipment' when d.vehicle_id is not null then 'vehicle' else 'driver' end,
    coalesce(s.tracking_number,v.registration,p.full_name,'Unavailable'),d.lifecycle_status,d.valid_from,d.valid_until,
    case when d.lifecycle_status='archived' then 'archived' when d.valid_until is null then 'no_expiry' when d.valid_until<current_date then 'expired' when d.valid_until<=current_date+30 then 'expiring' else 'valid' end,
    d.uploaded_at,d.updated_at,count(*) over()
  from public.documents d left join public.shipments s on s.id=d.shipment_id left join public.vehicles v on v.id=d.vehicle_id left join public.drivers dr on dr.id=d.driver_id left join public.profiles p on p.id=dr.profile_id
  where (normalized='' or d.file_name ilike '%'||normalized||'%' or d.document_type ilike '%'||normalized||'%' or coalesce(s.tracking_number,v.registration,p.full_name,'') ilike '%'||normalized||'%')
    and (owner_filter is null or (owner_filter='shipment' and d.shipment_id is not null) or (owner_filter='vehicle' and d.vehicle_id is not null) or (owner_filter='driver' and d.driver_id is not null))
    and (type_filter is null or d.document_type=type_filter) and (lifecycle_filter='all' or d.lifecycle_status::text=lifecycle_filter)
    and (validity_filter is null or validity_filter=(case when d.lifecycle_status='archived' then 'archived' when d.valid_until is null then 'no_expiry' when d.valid_until<current_date then 'expired' when d.valid_until<=current_date+30 then 'expiring' else 'valid' end))
  order by d.uploaded_at desc,d.id desc limit 10 offset ((requested_page-1)*10);
end;$function$;

create function public.list_document_owner_options(owner_kind text)
returns table(id uuid,label text) language plpgsql stable security definer set search_path='' as $$
declare actor_role public.profile_role;
begin
 select role into actor_role from public.profiles where id=(select auth.uid()) and is_active;
 if actor_role is null or actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_read_access_denied'; end if;
 if owner_kind='shipment' then return query select shipments.id,shipments.tracking_number from public.shipments where status in ('pending','assigned','loading','in_transit') order by tracking_number,id;
 elsif owner_kind='vehicle' then return query select vehicles.id,vehicles.registration from public.vehicles where status<>'archived' order by lower(registration),id;
 elsif owner_kind='driver' then return query select drivers.id,profiles.full_name from public.drivers join public.profiles on profiles.id=drivers.profile_id where drivers.status not in ('inactive','archived') order by lower(profiles.full_name),drivers.id;
 else raise exception using errcode='P0001',message='document_owner_invalid'; end if;
end;$$;

create function public.get_operations_document_for_edit(target_document_id uuid)
returns table(id uuid,document_type text,owner_type text,owner_label text,valid_from date,valid_until date,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from public.profiles where id=(select auth.uid()) and is_active and role='admin') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 return query select d.id,d.document_type,case when d.shipment_id is not null then 'shipment' when d.vehicle_id is not null then 'vehicle' else 'driver' end,coalesce(s.tracking_number,v.registration,p.full_name,'Unavailable'),d.valid_from,d.valid_until,d.updated_at
 from public.documents d left join public.shipments s on s.id=d.shipment_id left join public.vehicles v on v.id=d.vehicle_id left join public.drivers dr on dr.id=d.driver_id left join public.profiles p on p.id=dr.profile_id where d.id=target_document_id;
end;$$;

create function public.complete_document_upload(target_document_id uuid,owner_kind text,target_owner_id uuid,input_document_type text,input_file_path text,input_file_name text,input_valid_from date default null,input_valid_until date default null)
returns uuid language plpgsql volatile security definer set search_path='' as $function$
declare actor_id uuid:=(select auth.uid()); actor_role public.profile_role; expected_prefix text; old_id uuid;
begin
 select role into actor_role from public.profiles where id=actor_id and is_active for update;
 if actor_role is null then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 if input_valid_from is not null and input_valid_until is not null and input_valid_until<input_valid_from then raise exception using errcode='P0001',message='document_validation_failed'; end if;
 if not public.document_type_allowed(owner_kind,input_document_type) then raise exception using errcode='P0001',message='document_type_invalid'; end if;
 expected_prefix:=owner_kind||'/'||target_owner_id::text||'/'||target_document_id::text||'/';
 if input_file_path not like expected_prefix||'%' or trim(input_file_name)='' or not exists(select 1 from storage.objects where bucket_id='documents' and name=input_file_path) then raise exception using errcode='P0001',message='document_storage_invalid'; end if;
 if owner_kind='shipment' then
   perform 1 from public.shipments where id=target_owner_id and status in ('pending','assigned','loading','in_transit') for update;
   if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
   if actor_role='driver' and not exists(select 1 from public.shipments join public.drivers on drivers.id=shipments.driver_id where shipments.id=target_owner_id and drivers.profile_id=actor_id and shipments.status in ('assigned','loading','in_transit')) then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
   if actor_role='driver' and input_document_type<>'proof_of_delivery' then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 elsif owner_kind='vehicle' then
   if actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
   perform 1 from public.vehicles where id=target_owner_id and status<>'archived' for update; if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
 elsif owner_kind='driver' then
   if actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
   perform 1 from public.drivers where id=target_owner_id and status not in ('inactive','archived') for update; if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
 else raise exception using errcode='P0001',message='document_owner_invalid'; end if;
 if actor_role not in ('admin','dispatcher','driver') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 if input_document_type='proof_of_delivery' then
   for old_id in select id from public.documents where shipment_id=target_owner_id and document_type='proof_of_delivery' and lifecycle_status='active' order by id for update loop
     update public.documents set lifecycle_status='archived' where id=old_id;
     insert into public.activity_logs(id,actor_profile_id,action_type,document_id) values(gen_random_uuid(),actor_id,'document_archived',old_id);
     perform * from public.reconcile_document_expiry_alerts(old_id,actor_id);
   end loop;
 end if;
 insert into public.documents(id,shipment_id,vehicle_id,driver_id,uploader_profile_id,document_type,file_path,file_name,valid_from,valid_until)
 values(target_document_id,case when owner_kind='shipment' then target_owner_id end,case when owner_kind='vehicle' then target_owner_id end,case when owner_kind='driver' then target_owner_id end,actor_id,input_document_type,input_file_path,input_file_name,input_valid_from,input_valid_until);
 insert into public.activity_logs(id,actor_profile_id,action_type,document_id) values(gen_random_uuid(),actor_id,'document_uploaded',target_document_id);
 perform * from public.reconcile_document_expiry_alerts(target_document_id,actor_id);
 return target_document_id;
end;$function$;

create function public.update_document_metadata(target_document_id uuid,expected_updated_at timestamptz,input_document_type text,input_valid_from date default null,input_valid_until date default null)
returns text language plpgsql volatile security definer set search_path='' as $function$
declare actor_id uuid:=(select auth.uid()); discovered public.documents%rowtype; target public.documents%rowtype; owner_kind text;
begin
 if not exists(select 1 from public.profiles where id=actor_id and is_active and role='admin' for update) then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 select * into discovered from public.documents where id=target_document_id; if not found then raise exception using errcode='P0001',message='document_not_found'; end if;
 if discovered.driver_id is not null then owner_kind:='driver'; perform 1 from public.drivers where id=discovered.driver_id and status not in ('inactive','archived') for update;
 elsif discovered.vehicle_id is not null then owner_kind:='vehicle'; perform 1 from public.vehicles where id=discovered.vehicle_id and status<>'archived' for update;
 else owner_kind:='shipment'; perform 1 from public.shipments where id=discovered.shipment_id and status in ('pending','assigned','loading','in_transit') for update; end if;
 if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
 select * into target from public.documents where id=target_document_id for update;
 if target.updated_at is distinct from expected_updated_at then raise exception using errcode='P0001',message='document_stale'; end if;
 if not public.document_type_allowed(owner_kind,input_document_type) or input_valid_from is not null and input_valid_until is not null and input_valid_until<input_valid_from then raise exception using errcode='P0001',message='document_validation_failed'; end if;
 if target.document_type=input_document_type and target.valid_from is not distinct from input_valid_from and target.valid_until is not distinct from input_valid_until then return 'noop'; end if;
 update public.documents set document_type=input_document_type,valid_from=input_valid_from,valid_until=input_valid_until where id=target.id;
 perform * from public.reconcile_document_expiry_alerts(target.id,actor_id); return 'updated';
end;$function$;

create function public.set_document_lifecycle(target_document_id uuid,expected_updated_at timestamptz,requested_status public.document_lifecycle_status)
returns text language plpgsql volatile security definer set search_path='' as $function$
declare actor_id uuid:=(select auth.uid()); actor_role public.profile_role; discovered public.documents%rowtype; target public.documents%rowtype;
begin
 select role into actor_role from public.profiles where id=actor_id and is_active for update;
 if actor_role is null or (requested_status='active' and actor_role<>'admin') or (requested_status='archived' and actor_role not in ('admin','dispatcher')) then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 select * into discovered from public.documents where id=target_document_id; if not found then raise exception using errcode='P0001',message='document_not_found'; end if;
 if discovered.driver_id is not null then perform 1 from public.drivers where id=discovered.driver_id for update; elsif discovered.vehicle_id is not null then perform 1 from public.vehicles where id=discovered.vehicle_id for update; else perform 1 from public.shipments where id=discovered.shipment_id for update; end if;
 select * into target from public.documents where id=target_document_id for update;
 if target.updated_at is distinct from expected_updated_at then raise exception using errcode='P0001',message='document_stale'; end if;
 if target.lifecycle_status=requested_status then return 'noop'; end if;
 update public.documents set lifecycle_status=requested_status where id=target.id;
 insert into public.activity_logs(id,actor_profile_id,action_type,document_id) values(gen_random_uuid(),actor_id,case when requested_status='archived' then 'document_archived'::public.activity_action_type else 'document_restored'::public.activity_action_type end,target.id);
 perform * from public.reconcile_document_expiry_alerts(target.id,actor_id); return 'updated';
end;$function$;

create policy documents_operations_select on public.documents for select to authenticated using(exists(select 1 from public.profiles where id=(select auth.uid()) and is_active and role in ('admin','dispatcher')));
create policy documents_objects_operations_select on storage.objects for select to authenticated using(bucket_id='documents' and exists(select 1 from public.profiles where id=(select auth.uid()) and is_active and role in ('admin','dispatcher')));
create policy documents_objects_staged_insert on storage.objects for insert to authenticated with check(bucket_id='documents' and (
  exists(select 1 from public.profiles where id=(select auth.uid()) and is_active and role in ('admin','dispatcher')) or
  exists(select 1 from public.profiles join public.drivers on drivers.profile_id=profiles.id join public.shipments on shipments.driver_id=drivers.id where profiles.id=(select auth.uid()) and profiles.is_active and profiles.role='driver' and shipments.status in ('assigned','loading','in_transit') and (storage.foldername(name))[1]='shipment' and (storage.foldername(name))[2]=shipments.id::text)
));

revoke all on function public.reconcile_document_expiry_alerts(uuid,uuid),public.list_document_alert_ids(uuid),public.list_abandoned_document_objects(text) from public,anon,authenticated;
grant execute on function public.reconcile_document_expiry_alerts(uuid,uuid),public.list_document_alert_ids(uuid),public.list_abandoned_document_objects(text) to service_role;
revoke all on function public.list_operations_documents(text,text,text,text,text,integer),public.list_document_owner_options(text),public.get_operations_document_for_edit(uuid),public.complete_document_upload(uuid,text,uuid,text,text,text,date,date),public.update_document_metadata(uuid,timestamptz,text,date,date),public.set_document_lifecycle(uuid,timestamptz,public.document_lifecycle_status) from public,anon;
grant execute on function public.list_operations_documents(text,text,text,text,text,integer),public.list_document_owner_options(text),public.get_operations_document_for_edit(uuid),public.complete_document_upload(uuid,text,uuid,text,text,text,date,date),public.update_document_metadata(uuid,timestamptz,text,date,date),public.set_document_lifecycle(uuid,timestamptz,public.document_lifecycle_status) to authenticated;

select cron.schedule('logiflow-reconcile-documents-daily-0200-utc','0 2 * * *',$schedule$select net.http_post(url := (select decrypted_secret from vault.decrypted_secrets where name='project_url') || '/functions/v1/reconcile-operational-alerts',headers := pg_catalog.jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='scheduler_shared_secret')),body := '{"job":"documents"}'::jsonb);$schedule$);
select cron.schedule('logiflow-document-upload-cleanup-hourly','0 * * * *',$schedule$select net.http_post(url := (select decrypted_secret from vault.decrypted_secrets where name='project_url') || '/functions/v1/reconcile-operational-alerts',headers := pg_catalog.jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name='scheduler_shared_secret')),body := '{"job":"document_upload_cleanup"}'::jsonb);$schedule$);
