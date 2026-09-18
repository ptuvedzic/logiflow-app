create function public.authorize_document_upload_intent(owner_kind text,target_owner_id uuid,input_document_type text)
returns boolean language plpgsql stable security definer set search_path='' as $function$
declare actor_id uuid:=(select auth.uid()); actor_role public.profile_role;
begin
  select role into actor_role from public.profiles where id=actor_id and is_active;
  if actor_role is null or not public.document_type_allowed(owner_kind,input_document_type) then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
  if owner_kind='shipment' then
    if actor_role in ('admin','dispatcher') then return exists(select 1 from public.shipments where id=target_owner_id and status in ('pending','assigned','loading','in_transit')); end if;
    if actor_role='driver' and input_document_type='proof_of_delivery' then return exists(select 1 from public.shipments join public.drivers on drivers.id=shipments.driver_id where shipments.id=target_owner_id and drivers.profile_id=actor_id and shipments.status in ('assigned','loading','in_transit')); end if;
  elsif owner_kind='vehicle' and actor_role in ('admin','dispatcher') then return exists(select 1 from public.vehicles where id=target_owner_id and status<>'archived');
  elsif owner_kind='driver' and actor_role in ('admin','dispatcher') then return exists(select 1 from public.drivers where id=target_owner_id and status not in ('inactive','archived'));
  end if;
  return false;
end;$function$;

create or replace function public.list_document_alert_ids(after_document_id uuid default null)
returns table(document_id uuid) language plpgsql stable security definer set search_path = '' as $$
begin
  if current_user not in ('postgres','service_role') then raise exception using errcode='42501',message='document_alert_access_denied'; end if;
  return query select documents.id from public.documents where (after_document_id is null or documents.id>after_document_id) order by documents.id limit 50;
end;$$;

create or replace function public.complete_document_upload(target_document_id uuid,owner_kind text,target_owner_id uuid,input_document_type text,input_file_path text,input_file_name text,input_valid_from date default null,input_valid_until date default null)
returns uuid language plpgsql volatile security definer set search_path='' as $function$
declare actor_id uuid:=(select auth.uid()); actor_role public.profile_role; expected_prefix text; old_id uuid; stored_size bigint; stored_mime text;
begin
 select role into actor_role from public.profiles where id=actor_id and is_active for update;
 if actor_role is null then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 if input_valid_from is not null and input_valid_until is not null and input_valid_until<input_valid_from then raise exception using errcode='P0001',message='document_validation_failed'; end if;
 if not public.document_type_allowed(owner_kind,input_document_type) then raise exception using errcode='P0001',message='document_type_invalid'; end if;
 expected_prefix:=owner_kind||'/'||target_owner_id::text||'/'||target_document_id::text||'/';
 select (metadata->>'size')::bigint,coalesce(metadata->>'mimetype',metadata->>'contentType') into stored_size,stored_mime from storage.objects where bucket_id='documents' and name=input_file_path;
 if input_file_path not like expected_prefix||'%' or trim(input_file_name)='' or not found or stored_size is null or stored_size<=0 or stored_size>20971520 or stored_mime not in ('application/pdf','image/jpeg','image/png') then raise exception using errcode='P0001',message='document_storage_invalid'; end if;
 if owner_kind='shipment' then
   perform 1 from public.shipments where id=target_owner_id and status in ('pending','assigned','loading','in_transit') for update; if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
   if actor_role='driver' and not exists(select 1 from public.shipments join public.drivers on drivers.id=shipments.driver_id where shipments.id=target_owner_id and drivers.profile_id=actor_id and shipments.status in ('assigned','loading','in_transit')) then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
   if actor_role='driver' and input_document_type<>'proof_of_delivery' then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 elsif owner_kind='vehicle' then
   if actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
   perform 1 from public.vehicles where id=target_owner_id and status<>'archived' for update; if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
 elsif owner_kind='driver' then
   if actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
   perform 1 from public.drivers where id=target_owner_id and status not in ('inactive','archived') for update; if not found then raise exception using errcode='P0001',message='document_owner_ineligible'; end if;
 else raise exception using errcode='P0001',message='document_owner_invalid'; end if;
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
 perform * from public.reconcile_document_expiry_alerts(target_document_id,actor_id); return target_document_id;
end;$function$;

revoke all on function public.authorize_document_upload_intent(text,uuid,text) from public,anon;
grant execute on function public.authorize_document_upload_intent(text,uuid,text) to authenticated;
