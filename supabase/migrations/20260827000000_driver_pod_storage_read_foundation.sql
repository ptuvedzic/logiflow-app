do $$
declare
  existing_bucket storage.buckets%rowtype;
begin
  select *
  into existing_bucket
  from storage.buckets
  where id = 'documents';

  if found then
    if existing_bucket.name <> 'documents'
      or existing_bucket.public
      or existing_bucket.file_size_limit is distinct from 20971520
      or existing_bucket.allowed_mime_types is distinct from array[
        'application/pdf',
        'image/jpeg',
        'image/png'
      ]::text[]
    then
      raise exception 'Existing documents bucket conflicts with the approved private Storage contract';
    end if;
  else
    insert into storage.buckets (
      id,
      name,
      public,
      file_size_limit,
      allowed_mime_types
    )
    values (
      'documents',
      'documents',
      false,
      20971520,
      array['application/pdf', 'image/jpeg', 'image/png']::text[]
    );
  end if;
end;
$$;

grant select (
  id,
  shipment_id,
  document_type,
  file_path,
  file_name,
  lifecycle_status,
  uploaded_at
) on table public.documents to authenticated;

create policy "documents_select_own_current_active_pod"
on public.documents
for select
to authenticated
using (
  document_type = 'proof_of_delivery'
  and lifecycle_status = 'active'
  and shipment_id is not null
  and exists (
    select 1
    from public.shipments
    join public.drivers
      on drivers.id = shipments.driver_id
    join public.profiles
      on profiles.id = drivers.profile_id
    where shipments.id = documents.shipment_id
      and shipments.status in ('assigned', 'loading', 'in_transit')
      and drivers.profile_id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'driver'
  )
);

create policy "documents_objects_select_own_current_active_pod"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'documents'
  and exists (
    select 1
    from public.documents
    join public.shipments
      on shipments.id = documents.shipment_id
    join public.drivers
      on drivers.id = shipments.driver_id
    join public.profiles
      on profiles.id = drivers.profile_id
    where documents.file_path = storage.objects.name
      and documents.document_type = 'proof_of_delivery'
      and documents.lifecycle_status = 'active'
      and shipments.status in ('assigned', 'loading', 'in_transit')
      and drivers.profile_id = (select auth.uid())
      and profiles.is_active
      and profiles.role = 'driver'
  )
);
