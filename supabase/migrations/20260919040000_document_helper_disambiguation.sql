create or replace function public.list_document_owner_options(owner_kind text)
returns table(id uuid,label text) language plpgsql stable security definer set search_path='' as $$
#variable_conflict use_column
declare actor_role public.profile_role;
begin
 select profiles.role into actor_role from public.profiles where profiles.id=(select auth.uid()) and profiles.is_active;
 if actor_role is null or actor_role not in ('admin','dispatcher') then raise exception using errcode='42501',message='document_read_access_denied'; end if;
 if owner_kind='shipment' then return query select shipments.id,shipments.tracking_number from public.shipments where shipments.status in ('pending','assigned','loading','in_transit') order by shipments.tracking_number,shipments.id;
 elsif owner_kind='vehicle' then return query select vehicles.id,vehicles.registration from public.vehicles where vehicles.status<>'archived' order by lower(vehicles.registration),vehicles.id;
 elsif owner_kind='driver' then return query select drivers.id,profiles.full_name from public.drivers join public.profiles on profiles.id=drivers.profile_id where drivers.status not in ('inactive','archived') order by lower(profiles.full_name),drivers.id;
 else raise exception using errcode='P0001',message='document_owner_invalid'; end if;
end;$$;

create or replace function public.get_operations_document_for_edit(target_document_id uuid)
returns table(id uuid,document_type text,owner_type text,owner_label text,valid_from date,valid_until date,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
#variable_conflict use_column
begin
 if not exists(select 1 from public.profiles actor where actor.id=(select auth.uid()) and actor.is_active and actor.role='admin') then raise exception using errcode='42501',message='document_mutation_access_denied'; end if;
 return query select d.id,d.document_type,case when d.shipment_id is not null then 'shipment' when d.vehicle_id is not null then 'vehicle' else 'driver' end,coalesce(s.tracking_number,v.registration,p.full_name,'Unavailable'),d.valid_from,d.valid_until,d.updated_at
 from public.documents d left join public.shipments s on s.id=d.shipment_id left join public.vehicles v on v.id=d.vehicle_id left join public.drivers dr on dr.id=d.driver_id left join public.profiles p on p.id=dr.profile_id where d.id=target_document_id;
end;$$;
