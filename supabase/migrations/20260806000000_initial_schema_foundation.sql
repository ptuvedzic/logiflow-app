create type public.profile_role as enum ('admin', 'dispatcher', 'driver');
create type public.driver_status as enum ('available', 'assigned', 'off_duty', 'inactive', 'archived');
create type public.client_status as enum ('active', 'archived');
create type public.vehicle_status as enum ('available', 'in_use', 'maintenance', 'out_of_service', 'archived');
create type public.shipment_status as enum ('pending', 'assigned', 'loading', 'in_transit', 'delivered', 'cancelled');
create type public.status_request_state as enum ('pending', 'approved', 'rejected');
create type public.document_lifecycle_status as enum ('active', 'archived');
create type public.expense_category as enum ('fuel', 'toll', 'driver', 'maintenance', 'other');
create type public.notification_type as enum (
  'shipment_assigned',
  'status_approval_requested',
  'status_approved',
  'status_rejected',
  'shipment_delayed',
  'vehicle_maintenance_due',
  'vehicle_document_expiring',
  'driver_document_expiring',
  'new_dispatcher_message',
  'shipment_delivered'
);
create type public.alert_type as enum (
  'shipment_delayed',
  'document_expiring',
  'document_expired',
  'maintenance_due_date',
  'maintenance_due_mileage',
  'stale_vehicle_location'
);
create type public.alert_state as enum ('active', 'resolved');
create type public.alert_severity as enum ('info', 'warning', 'critical');
create type public.activity_action_type as enum (
  'driver_created',
  'driver_status_changed',
  'client_created',
  'client_updated',
  'client_archived',
  'client_reactivated',
  'vehicle_created',
  'vehicle_updated',
  'vehicle_status_changed',
  'vehicle_archived',
  'shipment_created',
  'shipment_updated',
  'shipment_assigned',
  'shipment_status_changed',
  'shipment_delayed',
  'shipment_cancelled',
  'status_request_created',
  'status_request_approved',
  'status_request_rejected',
  'document_uploaded',
  'document_archived',
  'maintenance_record_created',
  'maintenance_record_updated',
  'expense_created',
  'expense_updated',
  'alert_created',
  'alert_resolved',
  'tracking_started',
  'tracking_stopped'
);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key,
  full_name text not null,
  username text not null,
  role public.profile_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_id_fkey foreign key (id) references auth.users (id) on delete restrict,
  constraint profiles_full_name_nonblank_check check (trim(full_name) <> ''),
  constraint profiles_username_nonblank_check check (trim(username) <> '')
);

create table public.drivers (
  id uuid primary key,
  profile_id uuid not null,
  phone text,
  status public.driver_status not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint drivers_profile_id_fkey foreign key (profile_id) references public.profiles (id) on delete restrict,
  constraint drivers_profile_id_key unique (profile_id),
  constraint drivers_phone_nonblank_check check (phone is null or trim(phone) <> '')
);

create table public.clients (
  id uuid primary key,
  company_name text not null,
  contact_person text,
  phone text,
  email text,
  address text,
  notes text,
  status public.client_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clients_company_name_nonblank_check check (trim(company_name) <> ''),
  constraint clients_contact_person_nonblank_check check (contact_person is null or trim(contact_person) <> ''),
  constraint clients_phone_nonblank_check check (phone is null or trim(phone) <> ''),
  constraint clients_email_nonblank_check check (email is null or trim(email) <> ''),
  constraint clients_address_nonblank_check check (address is null or trim(address) <> ''),
  constraint clients_notes_nonblank_check check (notes is null or trim(notes) <> '')
);

create table public.vehicles (
  id uuid primary key,
  registration text not null,
  make text not null,
  model text not null,
  vehicle_type text not null,
  vin text,
  mileage integer not null default 0,
  fuel_type text,
  first_registration_date date,
  status public.vehicle_status not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint vehicles_registration_nonblank_check check (trim(registration) <> ''),
  constraint vehicles_make_nonblank_check check (trim(make) <> ''),
  constraint vehicles_model_nonblank_check check (trim(model) <> ''),
  constraint vehicles_vehicle_type_nonblank_check check (trim(vehicle_type) <> ''),
  constraint vehicles_vin_nonblank_check check (vin is null or trim(vin) <> ''),
  constraint vehicles_mileage_check check (mileage >= 0),
  constraint vehicles_fuel_type_nonblank_check check (fuel_type is null or trim(fuel_type) <> '')
);

create table public.shipments (
  id uuid primary key,
  tracking_number text not null,
  client_id uuid not null,
  pickup_address text not null,
  delivery_address text not null,
  pickup_at timestamptz not null,
  expected_delivery_at timestamptz not null,
  cargo_type text not null,
  driver_id uuid,
  vehicle_id uuid,
  price numeric(12,2) not null,
  status public.shipment_status not null default 'pending',
  delayed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shipments_tracking_number_key unique (tracking_number),
  constraint shipments_client_id_fkey foreign key (client_id) references public.clients (id) on delete restrict,
  constraint shipments_driver_id_fkey foreign key (driver_id) references public.drivers (id) on delete restrict,
  constraint shipments_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint shipments_tracking_number_nonblank_check check (trim(tracking_number) <> ''),
  constraint shipments_pickup_address_nonblank_check check (trim(pickup_address) <> ''),
  constraint shipments_delivery_address_nonblank_check check (trim(delivery_address) <> ''),
  constraint shipments_expected_delivery_check check (expected_delivery_at >= pickup_at),
  constraint shipments_cargo_type_nonblank_check check (trim(cargo_type) <> ''),
  constraint shipments_price_check check (price >= 0),
  constraint shipments_assignment_pair_check check (
    (driver_id is null and vehicle_id is null)
    or (driver_id is not null and vehicle_id is not null)
  ),
  constraint shipments_assignment_status_check check (
    (status = 'pending' and driver_id is null and vehicle_id is null)
    or (status in ('assigned', 'loading', 'in_transit', 'delivered') and driver_id is not null and vehicle_id is not null)
    or status = 'cancelled'
  ),
  constraint shipments_delayed_status_check check (
    (status = 'in_transit') or delayed = false
  )
);

create table public.shipment_status_requests (
  id uuid primary key,
  shipment_id uuid not null,
  driver_id uuid not null,
  current_status public.shipment_status not null,
  requested_status public.shipment_status not null,
  request_state public.status_request_state not null default 'pending',
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by_profile_id uuid,
  rejection_reason text,
  updated_at timestamptz not null default now(),
  constraint shipment_status_requests_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint shipment_status_requests_driver_id_fkey foreign key (driver_id) references public.drivers (id) on delete restrict,
  constraint shipment_status_requests_resolved_by_profile_id_fkey foreign key (resolved_by_profile_id) references public.profiles (id) on delete restrict,
  constraint shipment_status_requests_distinct_status_check check (current_status <> requested_status),
  constraint shipment_status_requests_resolution_state_check check (
    (request_state = 'pending' and resolved_at is null and resolved_by_profile_id is null and rejection_reason is null)
    or (request_state = 'approved' and resolved_at is not null and resolved_by_profile_id is not null and rejection_reason is null)
    or (request_state = 'rejected' and resolved_at is not null and resolved_by_profile_id is not null)
  ),
  constraint shipment_status_requests_resolution_time_check check (resolved_at is null or resolved_at >= requested_at),
  constraint shipment_status_requests_rejection_reason_nonblank_check check (rejection_reason is null or trim(rejection_reason) <> '')
);

create table public.maintenance_records (
  id uuid primary key,
  vehicle_id uuid not null,
  service_type text not null,
  service_date date not null,
  mileage_at_service integer not null,
  workshop text,
  cost numeric(12,2),
  notes text,
  next_service_date date,
  next_service_mileage integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint maintenance_records_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint maintenance_records_service_type_nonblank_check check (trim(service_type) <> ''),
  constraint maintenance_records_mileage_at_service_check check (mileage_at_service >= 0),
  constraint maintenance_records_workshop_nonblank_check check (workshop is null or trim(workshop) <> ''),
  constraint maintenance_records_cost_check check (cost is null or cost >= 0),
  constraint maintenance_records_notes_nonblank_check check (notes is null or trim(notes) <> ''),
  constraint maintenance_records_next_service_date_check check (next_service_date is null or next_service_date > service_date),
  constraint maintenance_records_next_service_mileage_check check (next_service_mileage is null or next_service_mileage > mileage_at_service)
);

create table public.documents (
  id uuid primary key,
  shipment_id uuid,
  vehicle_id uuid,
  driver_id uuid,
  uploader_profile_id uuid not null,
  document_type text not null,
  file_path text not null,
  file_name text not null,
  lifecycle_status public.document_lifecycle_status not null default 'active',
  uploaded_at timestamptz not null default now(),
  valid_from date,
  valid_until date,
  updated_at timestamptz not null default now(),
  constraint documents_file_path_key unique (file_path),
  constraint documents_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint documents_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint documents_driver_id_fkey foreign key (driver_id) references public.drivers (id) on delete restrict,
  constraint documents_uploader_profile_id_fkey foreign key (uploader_profile_id) references public.profiles (id) on delete restrict,
  constraint documents_document_type_nonblank_check check (trim(document_type) <> ''),
  constraint documents_file_path_nonblank_check check (trim(file_path) <> ''),
  constraint documents_file_name_nonblank_check check (trim(file_name) <> ''),
  constraint documents_owner_check check (num_nonnulls(shipment_id, vehicle_id, driver_id) = 1),
  constraint documents_validity_range_check check (valid_from is null or valid_until is null or valid_until >= valid_from),
  constraint documents_pod_owner_check check (document_type <> 'proof_of_delivery' or shipment_id is not null)
);

create table public.expenses (
  id uuid primary key,
  shipment_id uuid not null,
  created_by_profile_id uuid not null,
  category public.expense_category not null,
  amount numeric(12,2) not null,
  expense_date date not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expenses_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint expenses_created_by_profile_id_fkey foreign key (created_by_profile_id) references public.profiles (id) on delete restrict,
  constraint expenses_amount_check check (amount > 0),
  constraint expenses_description_nonblank_check check (description is null or trim(description) <> '')
);

create table public.messages (
  id uuid primary key,
  sender_profile_id uuid not null,
  recipient_driver_id uuid not null,
  shipment_id uuid,
  body text not null,
  sent_at timestamptz not null default now(),
  read_at timestamptz,
  constraint messages_sender_profile_id_fkey foreign key (sender_profile_id) references public.profiles (id) on delete restrict,
  constraint messages_recipient_driver_id_fkey foreign key (recipient_driver_id) references public.drivers (id) on delete restrict,
  constraint messages_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint messages_body_nonblank_check check (trim(body) <> ''),
  constraint messages_read_at_check check (read_at is null or read_at >= sent_at)
);

create table public.notifications (
  id uuid primary key,
  recipient_profile_id uuid not null,
  notification_type public.notification_type not null,
  title text not null,
  message text not null,
  shipment_id uuid,
  vehicle_id uuid,
  driver_id uuid,
  document_id uuid,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint notifications_recipient_profile_id_fkey foreign key (recipient_profile_id) references public.profiles (id) on delete restrict,
  constraint notifications_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint notifications_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint notifications_driver_id_fkey foreign key (driver_id) references public.drivers (id) on delete restrict,
  constraint notifications_document_id_fkey foreign key (document_id) references public.documents (id) on delete restrict,
  constraint notifications_title_nonblank_check check (trim(title) <> ''),
  constraint notifications_message_nonblank_check check (trim(message) <> ''),
  constraint notifications_entity_count_check check (num_nonnulls(shipment_id, vehicle_id, driver_id, document_id) <= 1),
  constraint notifications_read_at_check check (read_at is null or read_at >= created_at)
);

create table public.alerts (
  id uuid primary key,
  alert_type public.alert_type not null,
  severity public.alert_severity not null,
  message text not null,
  alert_state public.alert_state not null default 'active',
  shipment_id uuid,
  vehicle_id uuid,
  driver_id uuid,
  document_id uuid,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by_profile_id uuid,
  constraint alerts_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint alerts_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint alerts_driver_id_fkey foreign key (driver_id) references public.drivers (id) on delete restrict,
  constraint alerts_document_id_fkey foreign key (document_id) references public.documents (id) on delete restrict,
  constraint alerts_resolved_by_profile_id_fkey foreign key (resolved_by_profile_id) references public.profiles (id) on delete restrict,
  constraint alerts_message_nonblank_check check (trim(message) <> ''),
  constraint alerts_entity_count_check check (num_nonnulls(shipment_id, vehicle_id, driver_id, document_id) = 1),
  constraint alerts_resolution_time_check check (resolved_at is null or resolved_at >= created_at),
  constraint alerts_resolution_state_check check (
    (alert_state = 'active' and resolved_at is null and resolved_by_profile_id is null)
    or (alert_state = 'resolved' and resolved_at is not null and resolved_by_profile_id is not null)
  )
);

create table public.vehicle_locations (
  vehicle_id uuid primary key,
  shipment_id uuid not null,
  latitude double precision not null,
  longitude double precision not null,
  speed numeric(6,2),
  heading double precision,
  route_progress numeric(5,2),
  updated_at timestamptz not null default now(),
  constraint vehicle_locations_shipment_id_key unique (shipment_id),
  constraint vehicle_locations_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete cascade,
  constraint vehicle_locations_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete cascade,
  constraint vehicle_locations_latitude_check check (latitude between -90 and 90),
  constraint vehicle_locations_longitude_check check (longitude between -180 and 180),
  constraint vehicle_locations_speed_check check (speed is null or speed >= 0),
  constraint vehicle_locations_heading_check check (heading is null or (heading >= 0 and heading < 360)),
  constraint vehicle_locations_route_progress_check check (route_progress is null or route_progress between 0 and 100)
);

create table public.tracking_history (
  id uuid primary key,
  vehicle_id uuid not null,
  shipment_id uuid not null,
  latitude double precision not null,
  longitude double precision not null,
  speed numeric(6,2),
  heading double precision,
  route_progress numeric(5,2),
  recorded_at timestamptz not null default now(),
  constraint tracking_history_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint tracking_history_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint tracking_history_latitude_check check (latitude between -90 and 90),
  constraint tracking_history_longitude_check check (longitude between -180 and 180),
  constraint tracking_history_speed_check check (speed is null or speed >= 0),
  constraint tracking_history_heading_check check (heading is null or (heading >= 0 and heading < 360)),
  constraint tracking_history_route_progress_check check (route_progress is null or route_progress between 0 and 100)
);

create table public.activity_logs (
  id uuid primary key,
  actor_profile_id uuid,
  action_type public.activity_action_type not null,
  occurred_at timestamptz not null default now(),
  shipment_id uuid,
  vehicle_id uuid,
  driver_id uuid,
  client_id uuid,
  document_id uuid,
  status_request_id uuid,
  maintenance_record_id uuid,
  expense_id uuid,
  metadata jsonb,
  constraint activity_logs_actor_profile_id_fkey foreign key (actor_profile_id) references public.profiles (id) on delete restrict,
  constraint activity_logs_shipment_id_fkey foreign key (shipment_id) references public.shipments (id) on delete restrict,
  constraint activity_logs_vehicle_id_fkey foreign key (vehicle_id) references public.vehicles (id) on delete restrict,
  constraint activity_logs_driver_id_fkey foreign key (driver_id) references public.drivers (id) on delete restrict,
  constraint activity_logs_client_id_fkey foreign key (client_id) references public.clients (id) on delete restrict,
  constraint activity_logs_document_id_fkey foreign key (document_id) references public.documents (id) on delete restrict,
  constraint activity_logs_status_request_id_fkey foreign key (status_request_id) references public.shipment_status_requests (id) on delete restrict,
  constraint activity_logs_maintenance_record_id_fkey foreign key (maintenance_record_id) references public.maintenance_records (id) on delete restrict,
  constraint activity_logs_expense_id_fkey foreign key (expense_id) references public.expenses (id) on delete restrict,
  constraint activity_logs_entity_count_check check (
    num_nonnulls(shipment_id, vehicle_id, driver_id, client_id, document_id, status_request_id, maintenance_record_id, expense_id) = 1
  ),
  constraint activity_logs_metadata_object_check check (metadata is null or jsonb_typeof(metadata) = 'object')
);

create unique index profiles_username_lower_key on public.profiles (lower(username));
create index drivers_status_idx on public.drivers (status);
create index clients_status_idx on public.clients (status);
create unique index vehicles_registration_lower_key on public.vehicles (lower(registration));
create unique index vehicles_vin_key on public.vehicles (vin) where vin is not null;
create index vehicles_status_idx on public.vehicles (status);

create index shipments_client_id_idx on public.shipments (client_id);
create index shipments_status_idx on public.shipments (status);
create index shipments_pickup_at_idx on public.shipments (pickup_at);
create index shipments_expected_delivery_at_idx on public.shipments (expected_delivery_at);
create index shipments_driver_id_idx on public.shipments (driver_id) where driver_id is not null;
create index shipments_vehicle_id_idx on public.shipments (vehicle_id) where vehicle_id is not null;
create unique index shipments_active_driver_key on public.shipments (driver_id)
where status in ('assigned', 'loading', 'in_transit');
create unique index shipments_active_vehicle_key on public.shipments (vehicle_id)
where status in ('assigned', 'loading', 'in_transit');

create index shipment_status_requests_shipment_id_idx on public.shipment_status_requests (shipment_id);
create index shipment_status_requests_driver_id_idx on public.shipment_status_requests (driver_id);
create index shipment_status_requests_request_state_idx on public.shipment_status_requests (request_state);
create index shipment_status_requests_requested_at_idx on public.shipment_status_requests (requested_at);
create unique index shipment_status_requests_pending_shipment_key on public.shipment_status_requests (shipment_id)
where request_state = 'pending';

create index maintenance_records_vehicle_service_date_idx on public.maintenance_records (vehicle_id, service_date desc);
create index maintenance_records_next_service_date_idx on public.maintenance_records (next_service_date)
where next_service_date is not null;
create index maintenance_records_next_service_mileage_idx on public.maintenance_records (next_service_mileage)
where next_service_mileage is not null;

create index documents_shipment_uploaded_at_idx on public.documents (shipment_id, uploaded_at desc)
where shipment_id is not null;
create index documents_vehicle_uploaded_at_idx on public.documents (vehicle_id, uploaded_at desc)
where vehicle_id is not null;
create index documents_driver_uploaded_at_idx on public.documents (driver_id, uploaded_at desc)
where driver_id is not null;
create index documents_uploader_profile_id_idx on public.documents (uploader_profile_id);
create index documents_lifecycle_status_idx on public.documents (lifecycle_status);
create index documents_valid_until_idx on public.documents (valid_until) where valid_until is not null;

create index expenses_shipment_expense_date_idx on public.expenses (shipment_id, expense_date desc);
create index expenses_created_by_profile_id_idx on public.expenses (created_by_profile_id);
create index expenses_expense_date_idx on public.expenses (expense_date);

create index messages_recipient_sent_at_idx on public.messages (recipient_driver_id, sent_at desc);
create index messages_unread_recipient_sent_at_idx on public.messages (recipient_driver_id, sent_at desc)
where read_at is null;
create index messages_shipment_sent_at_idx on public.messages (shipment_id, sent_at desc)
where shipment_id is not null;

create index notifications_recipient_created_at_idx on public.notifications (recipient_profile_id, created_at desc);
create index notifications_unread_recipient_created_at_idx on public.notifications (recipient_profile_id, created_at desc)
where read_at is null;

create index alerts_state_severity_created_at_idx on public.alerts (alert_state, severity, created_at desc);
create unique index alerts_active_shipment_key on public.alerts (alert_type, shipment_id)
where alert_state = 'active' and shipment_id is not null;
create unique index alerts_active_vehicle_key on public.alerts (alert_type, vehicle_id)
where alert_state = 'active' and vehicle_id is not null;
create unique index alerts_active_driver_key on public.alerts (alert_type, driver_id)
where alert_state = 'active' and driver_id is not null;
create unique index alerts_active_document_key on public.alerts (alert_type, document_id)
where alert_state = 'active' and document_id is not null;

create index tracking_history_shipment_recorded_at_idx on public.tracking_history (shipment_id, recorded_at asc);
create index tracking_history_vehicle_recorded_at_idx on public.tracking_history (vehicle_id, recorded_at desc);

create index activity_logs_occurred_at_idx on public.activity_logs (occurred_at desc);
create index activity_logs_actor_occurred_at_idx on public.activity_logs (actor_profile_id, occurred_at desc)
where actor_profile_id is not null;
create index activity_logs_shipment_occurred_at_idx on public.activity_logs (shipment_id, occurred_at desc)
where shipment_id is not null;
create index activity_logs_vehicle_occurred_at_idx on public.activity_logs (vehicle_id, occurred_at desc)
where vehicle_id is not null;
create index activity_logs_driver_occurred_at_idx on public.activity_logs (driver_id, occurred_at desc)
where driver_id is not null;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger drivers_set_updated_at
before update on public.drivers
for each row execute function public.set_updated_at();

create trigger clients_set_updated_at
before update on public.clients
for each row execute function public.set_updated_at();

create trigger vehicles_set_updated_at
before update on public.vehicles
for each row execute function public.set_updated_at();

create trigger shipments_set_updated_at
before update on public.shipments
for each row execute function public.set_updated_at();

create trigger shipment_status_requests_set_updated_at
before update on public.shipment_status_requests
for each row execute function public.set_updated_at();

create trigger maintenance_records_set_updated_at
before update on public.maintenance_records
for each row execute function public.set_updated_at();

create trigger documents_set_updated_at
before update on public.documents
for each row execute function public.set_updated_at();

create trigger expenses_set_updated_at
before update on public.expenses
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.drivers enable row level security;
alter table public.clients enable row level security;
alter table public.vehicles enable row level security;
alter table public.shipments enable row level security;
alter table public.shipment_status_requests enable row level security;
alter table public.maintenance_records enable row level security;
alter table public.documents enable row level security;
alter table public.expenses enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.alerts enable row level security;
alter table public.vehicle_locations enable row level security;
alter table public.tracking_history enable row level security;
alter table public.activity_logs enable row level security;

revoke all privileges on table
  public.profiles,
  public.drivers,
  public.clients,
  public.vehicles,
  public.shipments,
  public.shipment_status_requests,
  public.maintenance_records,
  public.documents,
  public.expenses,
  public.messages,
  public.notifications,
  public.alerts,
  public.vehicle_locations,
  public.tracking_history,
  public.activity_logs
from public, anon, authenticated;

revoke execute on function public.set_updated_at() from public, anon, authenticated;
