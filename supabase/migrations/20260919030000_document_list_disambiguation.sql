create or replace function public.list_operations_documents(search_text text default '',owner_filter text default null,type_filter text default null,lifecycle_filter text default 'active',validity_filter text default null,requested_page integer default 1)
returns table(id uuid,file_name text,document_type text,owner_type text,owner_label text,lifecycle_status public.document_lifecycle_status,valid_from date,valid_until date,derived_status text,uploaded_at timestamptz,updated_at timestamptz,total_count bigint)
language plpgsql stable security definer set search_path='' as $function$
#variable_conflict use_column
declare actor_role public.profile_role; normalized text:=trim(coalesce(search_text,''));
begin
  select profiles.role into actor_role from public.profiles where profiles.id=(select auth.uid()) and profiles.is_active;
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
