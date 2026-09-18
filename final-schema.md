We have completed the full manual schema review for LogiFlow.

You must now create the final DATABASE.md using ONLY the decisions below.

Do not redesign the schema.
Do not introduce alternative tables, generic entity references, polymorphic foreign keys, extra normalization, SaaS concepts, public registration, or additional V1 features.

Your task is to:

1. Produce a complete DATABASE.md.
2. Document every table, enum, foreign key, check constraint, unique constraint, partial unique index, normal index, default, retention rule, and server-side rule.
3. Clearly separate:
   - database-enforced integrity;
   - server-side business logic;
   - derived values;
   - current-state tables;
   - immutable historical tables.
4. Include the intended PostgreSQL/Supabase implementation details.
5. Include table creation order based on dependencies.
6. Include a final list of all enums and indexes.
7. Include notes about RLS and transactional workflows, but do not write the full RLS policies yet unless necessary for clarification.
8. Do not leave open schema questions.

The following decisions are final.

==================================================
PRODUCT CONTEXT
==================================================

LogiFlow is a single-company logistics management application.

It is not SaaS.

There is no public registration.

Admin creates all user accounts.

Roles:

- admin
- dispatcher
- driver

Core shipment workflow:

pending
→ assigned
→ loading
→ in_transit
→ delivered

cancelled is a separate terminal state.

delayed is a boolean flag, not a shipment status.

Drivers submit shipment status change requests.

Dispatchers or Admins approve or reject those requests.

Proof of Delivery is required before approving Delivered.

Realtime vehicle tracking is simulated.

Expenses are shipment-level.

Messages are one-way:

Admin / Dispatcher
→ Driver

Notifications are in-app only.

Admin and Dispatcher interfaces are desktop-first.

Driver interface is mobile-first.

==================================================
GLOBAL DATABASE PRINCIPLES
==================================================

Use UUID primary keys.

Use timestamptz for timestamps.

Use date for date-only business values.

Use numeric(12,2) for money.

Operational entities are archived or deactivated instead of hard-deleted.

Historical and audit rows are retained.

Foreign keys to historical entities normally use ON DELETE RESTRICT.

Derived values must not be duplicated in stored columns unless explicitly defined below.

Cross-table workflow rules belong to controlled server-side functions or transactions rather than unsupported cross-table CHECK constraints.

updated_at should be maintained automatically on tables that support metadata changes.

Immutable event/history tables do not need updated_at.

==================================================
1. profiles
==================================================

Purpose:

Application identity linked one-to-one with auth.users.

Columns:

- id uuid PRIMARY KEY
- full_name text NOT NULL
- username text NOT NULL
- role profile_role NOT NULL
- is_active boolean NOT NULL DEFAULT true
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign key:

- id → auth.users.id
- ON DELETE RESTRICT or equivalent safe behavior

Enum:

profile_role:

- admin
- dispatcher
- driver

Constraints:

- trim(full_name) <> ''
- trim(username) <> ''
- username must be unique case-insensitively

Use a unique index such as:

UNIQUE (lower(username))

Important decisions:

- Do not duplicate email.
- Do not store passwords.
- Do not add metadata jsonb.
- Do not create separate admin or dispatcher tables.
- Only profiles with role=driver may have a drivers row.
- Profiles are deactivated with is_active=false.
- No normal hard delete.

Server-side rules:

- Only Admin creates accounts.
- Role and account activation permissions remain server-side.
- Deactivated profiles cannot perform application actions.
- Deactivating a driver profile blocks new assignments.

Indexes:

- unique lower(username)
- role if useful for account management queries
- is_active if useful for active account lists

==================================================
2. drivers
==================================================

Purpose:

Stores driver-specific operational state for profiles whose role is driver.

Columns:

- id uuid PRIMARY KEY
- profile_id uuid NOT NULL
- phone text NULL
- status driver_status NOT NULL
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign key:

- profile_id → profiles.id
- ON DELETE RESTRICT

Unique constraints:

- UNIQUE(profile_id)

Enum:

driver_status:

- available
- assigned
- off_duty
- inactive
- archived

Constraints:

- phone IS NULL OR trim(phone) <> ''

Database-level integrity:

- one driver row per profile

Server-side rules:

- profile.role must equal driver
- assigned status is synchronized with active shipment assignment
- inactive or archived drivers cannot receive assignments
- profile.is_active=false also blocks assignments
- one driver may have only one active shipment
- driver status cannot be manually changed in a way that contradicts shipment assignment

Indexes:

- profile_id unique
- status

==================================================
3. clients
==================================================

Purpose:

Represents logistics clients.

Columns:

- id uuid PRIMARY KEY
- company_name text NOT NULL
- contact_person text NULL
- phone text NULL
- email text NULL
- address text NULL
- notes text NULL
- status client_status NOT NULL DEFAULT 'active'
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Enum:

client_status:

- active
- archived

Constraints:

- trim(company_name) <> ''
- contact_person IS NULL OR trim(contact_person) <> ''
- phone IS NULL OR trim(phone) <> ''
- email IS NULL OR trim(email) <> ''
- address IS NULL OR trim(address) <> ''
- notes IS NULL OR trim(notes) <> ''

Important decisions:

- company_name is not unique
- email is not unique
- no separate client-history table
- shipment history is obtained through shipments.client_id
- archived clients remain historically referenced

Server-side rules:

- archived clients cannot receive new shipments
- archived clients may still appear in historical shipment records

Indexes:

- status
- company_name if useful for search

==================================================
4. vehicles
==================================================

Purpose:

Represents transport vehicles.

Columns:

- id uuid PRIMARY KEY
- registration text NOT NULL
- make text NOT NULL
- model text NOT NULL
- vehicle_type text NOT NULL
- vin text NULL
- mileage integer NOT NULL DEFAULT 0
- fuel_type text NULL
- first_registration_date date NULL
- status vehicle_status NOT NULL
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Enum:

vehicle_status:

- available
- in_use
- maintenance
- out_of_service
- archived

Constraints:

- trim(registration) <> ''
- trim(make) <> ''
- trim(model) <> ''
- trim(vehicle_type) <> ''
- vin IS NULL OR trim(vin) <> ''
- fuel_type IS NULL OR trim(fuel_type) <> ''
- mileage >= 0

Unique constraints:

- registration unique case-insensitively
- VIN unique when present

Suggested indexes:

- UNIQUE(lower(registration))
- UNIQUE(vin) WHERE vin IS NOT NULL
- status

Server-side rules:

- mileage must never decrease
- in_use is synchronized with active shipment assignment
- maintenance, out_of_service, and archived vehicles cannot receive assignments
- a vehicle may have only one active shipment
- status changes must not silently invalidate an active shipment
- mileage updates may be synchronized with maintenance records

==================================================
5. shipments
==================================================

Purpose:

Represents one logistics shipment.

Columns:

- id uuid PRIMARY KEY
- tracking_number text NOT NULL
- client_id uuid NOT NULL
- pickup_address text NOT NULL
- delivery_address text NOT NULL
- pickup_at timestamptz NOT NULL
- expected_delivery_at timestamptz NOT NULL
- cargo_type text NOT NULL
- driver_id uuid NULL
- vehicle_id uuid NULL
- price numeric(12,2) NOT NULL
- status shipment_status NOT NULL DEFAULT 'pending'
- delayed boolean NOT NULL DEFAULT false
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign keys:

- client_id → clients.id ON DELETE RESTRICT
- driver_id → drivers.id ON DELETE RESTRICT
- vehicle_id → vehicles.id ON DELETE RESTRICT

Enum:

shipment_status:

- pending
- assigned
- loading
- in_transit
- delivered
- cancelled

Constraints:

- trim(tracking_number) <> ''
- trim(pickup_address) <> ''
- trim(delivery_address) <> ''
- trim(cargo_type) <> ''
- expected_delivery_at >= pickup_at
- price >= 0

Assignment consistency:

Driver and vehicle must always be paired.

Use a CHECK equivalent to:

(driver_id IS NULL AND vehicle_id IS NULL)
OR
(driver_id IS NOT NULL AND vehicle_id IS NOT NULL)

Status/assignment consistency:

- pending requires driver_id NULL and vehicle_id NULL
- assigned requires driver_id and vehicle_id
- loading requires driver_id and vehicle_id
- in_transit requires driver_id and vehicle_id
- delivered requires driver_id and vehicle_id
- cancelled may have assignment or no assignment

Delayed consistency:

- delayed=true is only allowed while status=in_transit
- other statuses must have delayed=false

Unique constraints:

- tracking_number unique, preferably case-insensitive if its format permits mixed case

Partial unique indexes:

UNIQUE(driver_id)
WHERE status IN ('assigned', 'loading', 'in_transit')

UNIQUE(vehicle_id)
WHERE status IN ('assigned', 'loading', 'in_transit')

Server-side rules:

- only valid status transitions are allowed
- assignment must use an active available driver and vehicle
- client must be active for new shipment creation
- Proof of Delivery must exist before Delivered approval
- shipment status approval is transactional
- assignment synchronizes driver.status and vehicle.status
- delivery or cancellation releases active driver and vehicle
- activity logs and notifications are created in the same business workflow where practical

Derived values:

- total expenses = SUM(expenses.amount)
- profit = shipments.price - total expenses
- do not store total expenses or profit columns

Indexes:

- tracking number unique
- client_id
- status
- pickup_at
- expected_delivery_at
- driver_id where not null
- vehicle_id where not null

==================================================
6. shipment_status_requests
==================================================

Purpose:

Represents a Driver request to move an assigned shipment to its next workflow status.

Columns:

- id uuid PRIMARY KEY
- shipment_id uuid NOT NULL
- driver_id uuid NOT NULL
- current_status shipment_status NOT NULL
- requested_status shipment_status NOT NULL
- request_state status_request_state NOT NULL DEFAULT 'pending'
- requested_at timestamptz NOT NULL DEFAULT now()
- resolved_at timestamptz NULL
- resolved_by_profile_id uuid NULL
- rejection_reason text NULL
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign keys:

- shipment_id → shipments.id ON DELETE RESTRICT
- driver_id → drivers.id ON DELETE RESTRICT
- resolved_by_profile_id → profiles.id ON DELETE RESTRICT

Enum:

status_request_state:

- pending
- approved
- rejected

Constraints:

- current_status <> requested_status
- rejection_reason IS NULL OR trim(rejection_reason) <> ''

Resolution consistency:

When request_state='pending':

- resolved_at IS NULL
- resolved_by_profile_id IS NULL
- rejection_reason IS NULL

When request_state='approved':

- resolved_at IS NOT NULL
- resolved_by_profile_id IS NOT NULL
- rejection_reason IS NULL

When request_state='rejected':

- resolved_at IS NOT NULL
- resolved_by_profile_id IS NOT NULL
- rejection_reason may be NULL or populated

Also:

- resolved_at IS NULL OR resolved_at >= requested_at

Partial unique index:

UNIQUE(shipment_id)
WHERE request_state='pending'

Do not use UNIQUE(shipment_id, driver_id) for pending requests.

A shipment may have only one unresolved request regardless of driver.

Server-side rules:

- only the currently assigned Driver may create a request
- the request must represent the next valid status transition
- before approval, verify shipments.status = current_status
- if shipment status has already changed, approval must fail or the request must be rejected
- only Admin or Dispatcher may approve or reject
- Delivered approval requires active Proof of Delivery
- approval must atomically:
  - lock/revalidate the shipment
  - update shipment status
  - resolve the request
  - synchronize driver/vehicle state
  - create notifications
  - create activity logs

Indexes:

- shipment_id
- driver_id
- request_state
- requested_at
- partial unique pending shipment index

==================================================
7. maintenance_records
==================================================

Purpose:

Represents completed or recorded vehicle maintenance.

Columns:

- id uuid PRIMARY KEY
- vehicle_id uuid NOT NULL
- service_type text NOT NULL
- service_date date NOT NULL
- mileage_at_service integer NOT NULL
- workshop text NULL
- cost numeric(12,2) NULL
- notes text NULL
- next_service_date date NULL
- next_service_mileage integer NULL
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign key:

- vehicle_id → vehicles.id ON DELETE RESTRICT

Constraints:

- trim(service_type) <> ''
- mileage_at_service >= 0
- cost IS NULL OR cost >= 0
- workshop IS NULL OR trim(workshop) <> ''
- notes IS NULL OR trim(notes) <> ''
- next_service_date IS NULL OR next_service_date > service_date
- next_service_mileage IS NULL OR next_service_mileage > mileage_at_service

service_type remains text.

Do not create a service type enum or lookup table in V1.

Server-side rules:

- only Admin creates or edits maintenance records
- vehicles.mileage must never decrease
- if mileage_at_service is greater than vehicles.mileage, vehicle mileage may be increased in the same controlled transaction
- maintenance alerts are derived from the latest relevant maintenance record and current date/mileage
- alert thresholds are application constants
- recording historical maintenance does not automatically set vehicle.status='maintenance'
- maintenance cost is not automatically duplicated into expenses

Indexes:

- (vehicle_id, service_date DESC)
- next_service_date WHERE next_service_date IS NOT NULL
- next_service_mileage WHERE next_service_mileage IS NOT NULL

==================================================
8. documents
==================================================

Purpose:

Stores metadata for Shipment, Vehicle, or Driver documents.

Columns:

- id uuid PRIMARY KEY
- shipment_id uuid NULL
- vehicle_id uuid NULL
- driver_id uuid NULL
- uploader_profile_id uuid NOT NULL
- document_type text NOT NULL
- file_path text NOT NULL
- file_name text NOT NULL
- lifecycle_status document_lifecycle_status NOT NULL DEFAULT 'active'
- uploaded_at timestamptz NOT NULL DEFAULT now()
- valid_from date NULL
- valid_until date NULL
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign keys:

- shipment_id → shipments.id ON DELETE RESTRICT
- vehicle_id → vehicles.id ON DELETE RESTRICT
- driver_id → drivers.id ON DELETE RESTRICT
- uploader_profile_id → profiles.id ON DELETE RESTRICT

Enum:

document_lifecycle_status:

- active
- archived

Do not store valid, expiring, and expired as manually maintained status values.

Expiry state is derived from lifecycle_status and valid_until.

Exactly one owner constraint:

num_nonnulls(
  shipment_id,
  vehicle_id,
  driver_id
) = 1

Constraints:

- trim(document_type) <> ''
- trim(file_path) <> ''
- trim(file_name) <> ''
- valid_from IS NULL
  OR valid_until IS NULL
  OR valid_until >= valid_from
- document_type <> 'proof_of_delivery'
  OR shipment_id IS NOT NULL

Unique constraint:

- UNIQUE(file_path)

file_path represents a unique Supabase Storage object path.

document_type remains text, but the server uses stable canonical constants.

Proof of Delivery canonical type:

proof_of_delivery

Proof of Delivery must always be a Shipment document.

Derived expiry state:

If lifecycle_status='archived':

- archived

Else if valid_until IS NULL:

- no_expiry

Else if valid_until < current_date:

- expired

Else if valid_until <= current_date + configured V1 threshold:

- expiring

Else:

- valid

The V1 document expiry threshold is an application constant, currently 30 days.

Important final decision:

Keep both:

- uploaded_at
- updated_at

uploaded_at represents original upload time.

updated_at represents later metadata changes such as validity-date corrections, file-name correction, type correction where permitted, or archival.

Replacing the physical file should normally create a new document row and archive the old row rather than silently replacing the original file.

Server-side rules:

- validate upload permissions
- use canonical document type values
- ensure Storage upload succeeds before metadata insert
- clean up Storage object if metadata creation fails
- ensure POD belongs to the correct shipment
- require an active non-archived POD before Delivered approval
- calculate expiry state from dates
- create appropriate alerts and notifications
- do not hard-delete document metadata through normal workflow

Indexes:

- (shipment_id, uploaded_at DESC) WHERE shipment_id IS NOT NULL
- (vehicle_id, uploaded_at DESC) WHERE vehicle_id IS NOT NULL
- (driver_id, uploaded_at DESC) WHERE driver_id IS NOT NULL
- uploader_profile_id
- valid_until WHERE valid_until IS NOT NULL
- lifecycle_status
- unique file_path

==================================================
9. expenses
==================================================

Purpose:

Represents one shipment-level expense.

Columns:

- id uuid PRIMARY KEY
- shipment_id uuid NOT NULL
- created_by_profile_id uuid NOT NULL
- category expense_category NOT NULL
- amount numeric(12,2) NOT NULL
- expense_date date NOT NULL
- description text NULL
- created_at timestamptz NOT NULL DEFAULT now()
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign keys:

- shipment_id → shipments.id ON DELETE RESTRICT
- created_by_profile_id → profiles.id ON DELETE RESTRICT

Enum:

expense_category:

- fuel
- toll
- driver
- maintenance
- other

Constraints:

- amount > 0
- description IS NULL OR trim(description) <> ''

Important decisions:

- expenses are only shipment-level
- revenue is shipments.price
- total expenses and profit are derived
- do not duplicate totals
- maintenance_records.cost is not automatically copied into expenses
- a maintenance expense may be manually recorded only when it genuinely belongs to a specific shipment

Server-side rules:

- only Admin and Dispatcher may create or edit expenses
- important changes must be written to activity_logs
- created_by_profile_id records original creator
- later editor identity may be represented through activity_logs rather than an updated_by column

Indexes:

- (shipment_id, expense_date DESC)
- created_by_profile_id
- expense_date

==================================================
10. messages
==================================================

Purpose:

Represents immutable one-way communication from Admin or Dispatcher to Driver.

Columns:

- id uuid PRIMARY KEY
- sender_profile_id uuid NOT NULL
- recipient_driver_id uuid NOT NULL
- shipment_id uuid NULL
- body text NOT NULL
- sent_at timestamptz NOT NULL DEFAULT now()
- read_at timestamptz NULL

Foreign keys:

- sender_profile_id → profiles.id ON DELETE RESTRICT
- recipient_driver_id → drivers.id ON DELETE RESTRICT
- shipment_id → shipments.id ON DELETE RESTRICT

Do not include updated_at.

Messages are immutable after sending except for read_at.

Constraints:

- trim(body) <> ''
- read_at IS NULL OR read_at >= sent_at

Server-side and RLS rules:

- only Admin or Dispatcher may send
- sender_profile_id must match the authenticated sender
- Driver cannot reply in V1
- Driver may read only messages sent to their drivers row
- Driver may update only read_at
- body, sender, recipient, and shipment cannot be edited after sending
- when shipment_id is present, recipient_driver_id should match the assigned driver for that shipment
- inactive, archived, or deactivated drivers cannot receive new messages
- historical messages are retained
- no normal hard delete

Indexes:

- (recipient_driver_id, sent_at DESC)
- (recipient_driver_id, sent_at DESC) WHERE read_at IS NULL
- (shipment_id, sent_at DESC) WHERE shipment_id IS NOT NULL

==================================================
11. notifications
==================================================

Purpose:

Stores user-specific in-app informational events.

Columns:

- id uuid PRIMARY KEY
- recipient_profile_id uuid NOT NULL
- notification_type notification_type NOT NULL
- title text NOT NULL
- message text NOT NULL
- shipment_id uuid NULL
- vehicle_id uuid NULL
- driver_id uuid NULL
- document_id uuid NULL
- created_at timestamptz NOT NULL DEFAULT now()
- read_at timestamptz NULL

Foreign keys:

- recipient_profile_id → profiles.id ON DELETE RESTRICT
- shipment_id → shipments.id ON DELETE RESTRICT
- vehicle_id → vehicles.id ON DELETE RESTRICT
- driver_id → drivers.id ON DELETE RESTRICT
- document_id → documents.id ON DELETE RESTRICT

Enum:

notification_type:

- shipment_assigned
- status_approval_requested
- status_approved
- status_rejected
- shipment_delayed
- vehicle_maintenance_due
- vehicle_document_expiring
- driver_document_expiring
- new_dispatcher_message
- shipment_delivered

Specific nullable foreign keys are the final V1 design.

Do not introduce:

- related_entity_type
- related_entity_id
- generic polymorphic references

A later phase may reconsider this only if the system gains many additional entity types and the concrete FK model becomes demonstrably unmanageable.

Related entity constraint:

A notification may reference zero or exactly one related entity.

num_nonnulls(
  shipment_id,
  vehicle_id,
  driver_id,
  document_id
) <= 1

Constraints:

- trim(title) <> ''
- trim(message) <> ''
- read_at IS NULL OR read_at >= created_at

Notifications are immutable except read_at.

Unread state:

- read_at IS NULL means unread
- do not add is_read

Server-side rules:

- notification type must match its related entity
- relevant notification types should provide the expected FK
- only recipient may mark notification as read
- no user may edit notification content
- header unread count is derived from unread rows
- avoid generating unnecessary duplicate notifications
- notifications are separate from alerts

Indexes:

- (recipient_profile_id, created_at DESC)
- (recipient_profile_id, created_at DESC) WHERE read_at IS NULL
- optional entity timeline indexes only where required by actual queries

==================================================
12. alerts
==================================================

Purpose:

Represents an active or resolved operational condition requiring attention.

Columns:

- id uuid PRIMARY KEY
- alert_type alert_type NOT NULL
- severity alert_severity NOT NULL
- message text NOT NULL
- alert_state alert_state NOT NULL DEFAULT 'active'
- shipment_id uuid NULL
- vehicle_id uuid NULL
- driver_id uuid NULL
- document_id uuid NULL
- created_at timestamptz NOT NULL DEFAULT now()
- resolved_at timestamptz NULL
- resolved_by_profile_id uuid NULL

Foreign keys:

- shipment_id → shipments.id ON DELETE RESTRICT
- vehicle_id → vehicles.id ON DELETE RESTRICT
- driver_id → drivers.id ON DELETE RESTRICT
- document_id → documents.id ON DELETE RESTRICT
- resolved_by_profile_id → profiles.id ON DELETE RESTRICT

Enums:

alert_state:

- active
- resolved

alert_severity:

- info
- warning
- critical

Severity must be a strict V1 enum.

Do not use unrestricted text.

Suggested V1 alert_type values:

- shipment_delayed
- document_expiring
- document_expired
- maintenance_due_date
- maintenance_due_mileage
- stale_vehicle_location

alert_type should be constrained to the actual finalized V1 set.

Specific nullable foreign keys are the final V1 design.

Do not introduce a generic related-entity pattern.

Exactly one related operational entity is required:

num_nonnulls(
  shipment_id,
  vehicle_id,
  driver_id,
  document_id
) = 1

Constraints:

- trim(message) <> ''
- resolved_at IS NULL OR resolved_at >= created_at

Resolution consistency:

When alert_state='active':

- resolved_at IS NULL
- resolved_by_profile_id IS NULL

When alert_state='resolved':

- resolved_at IS NOT NULL
- resolved_by_profile_id IS NOT NULL

Prevent duplicate active alerts using partial unique indexes:

UNIQUE(alert_type, shipment_id)
WHERE alert_state='active'
AND shipment_id IS NOT NULL

UNIQUE(alert_type, vehicle_id)
WHERE alert_state='active'
AND vehicle_id IS NOT NULL

UNIQUE(alert_type, driver_id)
WHERE alert_state='active'
AND driver_id IS NOT NULL

UNIQUE(alert_type, document_id)
WHERE alert_state='active'
AND document_id IS NOT NULL

After an alert is resolved, a later recurrence creates a new row rather than reactivating the historical row.

Server-side or scheduled-process rules:

- calculate conditions using fixed V1 application thresholds
- document expiry warning threshold: 30 days
- maintenance date threshold: 14 days
- maintenance mileage threshold: 1,000 km
- stale vehicle location threshold: 10 minutes
- choose severity consistently
- automatically or manually resolve alerts according to alert type
- create a new alert if the condition reappears after resolution
- alerts are separate from notifications

Indexes:

- (alert_state, severity, created_at DESC)
- entity history partial indexes as needed
- all four partial unique active-alert indexes

==================================================
13. vehicle_locations
==================================================

Purpose:

Stores the current/latest location for realtime UI subscriptions.

This is a mutable current-state table.

Columns:

- vehicle_id uuid PRIMARY KEY
- shipment_id uuid NULL
- latitude double precision NOT NULL
- longitude double precision NOT NULL
- speed numeric(6,2) NULL
- heading double precision NULL
- route_progress numeric(5,2) NULL
- updated_at timestamptz NOT NULL DEFAULT now()

Foreign keys:

- vehicle_id → vehicles.id
- shipment_id → shipments.id

For this current-state table, ON DELETE CASCADE is acceptable because the row has no independent historical value.

Normal workflows still archive operational entities rather than hard-delete them.

Constraints:

- latitude BETWEEN -90 AND 90
- longitude BETWEEN -180 AND 180
- speed IS NULL OR speed >= 0
- heading IS NULL OR (heading >= 0 AND heading < 360)
- route_progress IS NULL OR route_progress BETWEEN 0 AND 100

Unique constraints:

- PRIMARY KEY(vehicle_id)
- UNIQUE(shipment_id) WHERE shipment_id IS NOT NULL

This provides:

- one current location row per vehicle
- no shipment represented by multiple current vehicle rows

Semantics:

- speed unit must be documented consistently, preferably km/h
- heading uses degrees from 0 inclusive to 360 exclusive
- route_progress is percent of route completed

Server-side rules:

- active tracking normally exists only while shipment.status='in_transit'
- shipment.vehicle_id must equal vehicle_locations.vehicle_id
- simulator performs UPSERT by vehicle_id
- updated_at is refreshed on every location update
- do not accept arbitrary client-generated tracking updates
- delete the current vehicle_locations row when tracking stops
- stale alert logic uses updated_at
- historical data remains in tracking_history

Indexes:

- primary key on vehicle_id
- unique partial shipment_id index

==================================================
14. tracking_history
==================================================

Purpose:

Stores periodic immutable historical location snapshots.

Columns:

- id uuid PRIMARY KEY
- vehicle_id uuid NOT NULL
- shipment_id uuid NOT NULL
- latitude double precision NOT NULL
- longitude double precision NOT NULL
- speed numeric(6,2) NULL
- heading double precision NULL
- route_progress numeric(5,2) NULL
- recorded_at timestamptz NOT NULL DEFAULT now()

Foreign keys:

- vehicle_id → vehicles.id ON DELETE RESTRICT
- shipment_id → shipments.id ON DELETE RESTRICT

Constraints:

- latitude BETWEEN -90 AND 90
- longitude BETWEEN -180 AND 180
- speed IS NULL OR speed >= 0
- heading IS NULL OR (heading >= 0 AND heading < 360)
- route_progress IS NULL OR route_progress BETWEEN 0 AND 100

Historical rows are append-only.

No normal UPDATE or DELETE.

Do not store every animation frame.

Snapshot frequency belongs in ARCHITECTURE.md.

Server-side rules:

- shipment and vehicle must match
- simulator uses trusted server/database time
- snapshots should be created at an appropriate interval
- route_progress should normally be non-decreasing
- final snapshot may reach 100
- removing vehicle_locations does not remove tracking_history
- historical rows are retained indefinitely in V1

Indexes:

- (shipment_id, recorded_at ASC)
- (vehicle_id, recorded_at DESC)

The primary route-history query is chronological per shipment.

==================================================
15. activity_logs
==================================================

Purpose:

Stores important user and system actions for audit and history.

Columns:

- id uuid PRIMARY KEY
- actor_profile_id uuid NULL
- action_type activity_action_type NOT NULL
- occurred_at timestamptz NOT NULL DEFAULT now()
- shipment_id uuid NULL
- vehicle_id uuid NULL
- driver_id uuid NULL
- client_id uuid NULL
- document_id uuid NULL
- status_request_id uuid NULL
- maintenance_record_id uuid NULL
- expense_id uuid NULL
- metadata jsonb NULL

Foreign keys:

- actor_profile_id → profiles.id ON DELETE RESTRICT
- shipment_id → shipments.id ON DELETE RESTRICT
- vehicle_id → vehicles.id ON DELETE RESTRICT
- driver_id → drivers.id ON DELETE RESTRICT
- client_id → clients.id ON DELETE RESTRICT
- document_id → documents.id ON DELETE RESTRICT
- status_request_id → shipment_status_requests.id ON DELETE RESTRICT
- maintenance_record_id → maintenance_records.id ON DELETE RESTRICT
- expense_id → expenses.id ON DELETE RESTRICT

actor_profile_id is nullable.

Meaning:

- user-generated action → actor_profile_id populated
- system-generated action → actor_profile_id NULL

activity_action_type must be a controlled V1 enum.

Suggested initial values:

- profile_created
- profile_deactivated
- profile_reactivated
- driver_created
- driver_status_changed
- client_created
- client_updated
- client_archived
- client_reactivated
- vehicle_created
- vehicle_updated
- vehicle_status_changed
- vehicle_archived
- shipment_created
- shipment_updated
- shipment_assigned
- shipment_status_changed
- shipment_delayed
- shipment_cancelled
- status_request_created
- status_request_approved
- status_request_rejected
- document_uploaded
- document_archived
- maintenance_record_created
- maintenance_record_updated
- expense_created
- expense_updated
- message_sent
- alert_created
- alert_resolved
- tracking_started
- tracking_stopped

Only keep action types that correspond to actual finalized V1 workflows.

Do not log trivial UI interactions such as:

- page opened
- search performed
- table filter changed
- message marked read
- notification marked read
- every tracking update

Exactly one primary related entity must be enforced strictly in the database:

num_nonnulls(
  shipment_id,
  vehicle_id,
  driver_id,
  client_id,
  document_id,
  status_request_id,
  maintenance_record_id,
  expense_id
) = 1

This is a final decision.

Do not leave it as application-only logic.

Additional context may be stored in metadata.

Metadata constraint:

metadata IS NULL
OR jsonb_typeof(metadata) = 'object'

Metadata must remain minimal and structured.

Allowed examples:

{
  "from_status": "assigned",
  "to_status": "loading"
}

{
  "old_amount": 120.00,
  "new_amount": 145.00,
  "category": "fuel"
}

Do not store:

- passwords
- auth tokens
- private Storage signed URLs
- full entity objects
- arbitrary API responses
- unnecessary duplicated data
- sensitive personal data

Activity rows are immutable.

No updated_at.

No normal UPDATE or DELETE.

Server-side rules:

- only trusted server workflows may insert logs
- users cannot manually select actor_profile_id
- authenticated actor is derived from the session
- system actions use actor_profile_id=NULL
- action type must match the primary entity
- activity insertion should happen in the same transaction as the business action where practical
- multi-entity actions choose one primary entity

Example:

Shipment assignment:

- shipment_id is populated
- driver and vehicle details may be placed in metadata
- driver_id and vehicle_id columns remain NULL in that activity row

Indexes:

- occurred_at DESC
- (actor_profile_id, occurred_at DESC) WHERE actor_profile_id IS NOT NULL
- (shipment_id, occurred_at DESC) WHERE shipment_id IS NOT NULL
- (vehicle_id, occurred_at DESC) WHERE vehicle_id IS NOT NULL
- (driver_id, occurred_at DESC) WHERE driver_id IS NOT NULL
- add other entity timeline indexes only where needed

==================================================
FINAL ANSWERS TO THE LAST OPEN QUESTIONS
==================================================

1. Notifications and alerts related entities

Final decision:

Use only the specific nullable foreign keys defined above.

Do not introduce a generic related-entity pattern in V1.

A generic pattern may be considered only in a later phase if the number of supported entity types becomes large enough that concrete foreign-key columns are clearly unmanageable.

2. activity_logs primary entity

Final decision:

Enforce exactly one primary related entity strictly at the database level with a CHECK using num_nonnulls(...)=1.

Do not leave this as application-only logic.

3. documents timestamps

Final decision:

Keep both uploaded_at and updated_at.

uploaded_at is the original creation/upload timestamp.

updated_at tracks later metadata changes.

4. alerts severity

Final decision:

Use a strict V1 enum:

- info
- warning
- critical

Do not use unrestricted text.

==================================================
DERIVED VALUES
==================================================

Do not store:

- shipment total expenses
- shipment profit
- notification unread boolean
- message unread boolean
- document valid/expiring/expired state
- client shipment history
- maintenance alert state directly on maintenance_records

Derive them from source data.

Examples:

Notification unread:

read_at IS NULL

Message unread:

read_at IS NULL

Document expiry state:

derived from lifecycle_status and valid_until

Shipment total expenses:

SUM(expenses.amount)

Shipment profit:

shipments.price - SUM(expenses.amount)

==================================================
MUTABILITY AND RETENTION SUMMARY
==================================================

Mutable operational tables:

- profiles
- drivers
- clients
- vehicles
- shipments
- shipment_status_requests until resolved
- maintenance_records
- documents metadata
- expenses
- notifications read_at
- alerts until resolved
- vehicle_locations

Immutable or append-only after creation:

- messages, except read_at
- tracking_history
- activity_logs
- resolved status requests should not be modified through normal workflow
- resolved alerts should not be modified through normal workflow

Current-state table:

- vehicle_locations

Historical tables:

- tracking_history
- activity_logs
- maintenance_records
- expenses
- documents
- messages
- resolved alerts
- resolved shipment status requests

==================================================
TRANSACTIONAL WORKFLOWS
==================================================

DATABASE.md must identify workflows that should run atomically.

At minimum:

Shipment assignment:

- validate shipment is pending
- validate active client
- validate driver and vehicle availability
- assign driver and vehicle
- set shipment status assigned
- set driver status assigned
- set vehicle status in_use
- create activity log
- create notification

Status request approval:

- lock/revalidate shipment and request
- verify request is pending
- verify shipment.status=current_status
- verify transition is allowed
- verify POD before delivered
- update shipment
- resolve request
- synchronize driver and vehicle state
- stop tracking if shipment leaves in_transit
- create notifications
- create activity logs

Maintenance creation:

- create maintenance record
- increase vehicle mileage if required
- never reduce mileage
- create activity log
- refresh relevant alert logic

Document upload:

- upload physical file
- create metadata
- clean up physical file if metadata insert fails
- create activity log
- refresh expiry alerts if applicable

Tracking start:

- validate shipment and vehicle
- create or upsert current location
- create initial history snapshot if required
- create activity log

Tracking stop:

- create final history snapshot if appropriate
- delete vehicle_locations row
- resolve stale tracking alerts
- create activity log

==================================================
TABLE CREATION ORDER
==================================================

DATABASE.md should provide a dependency-safe creation order similar to:

1. enums
2. profiles
3. drivers
4. clients
5. vehicles
6. shipments
7. shipment_status_requests
8. maintenance_records
9. documents
10. expenses
11. messages
12. notifications
13. alerts
14. vehicle_locations
15. tracking_history
16. activity_logs
17. indexes
18. updated_at triggers
19. helper functions / controlled transactional functions
20. RLS enablement and policy planning notes

Adjust the exact order only when required by real foreign-key dependencies.

==================================================
OUTPUT REQUIREMENT
==================================================

Now write the complete DATABASE.md.

It must be implementation-ready and internally consistent.

Do not return another questionnaire.

Do not propose alternative schemas.

Do not mark approved decisions as optional.

If you identify a direct technical contradiction, explain it before changing anything. Otherwise, preserve every final decision exactly.