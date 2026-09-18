# LogiFlow Database Specification

**Version:** 1.0  
**Status:** Approved for V1 implementation  
**Database:** PostgreSQL via Supabase  
**Scope:** Single-company internal logistics application

This document is the data-structure source of truth for LogiFlow V1. It implements the approved product requirements in `PRD.md` and the finalized decisions in `final-schema.md`. It does not define the complete RLS policy SQL or application architecture.

## 1. Database conventions

- Use UUID primary keys. `profiles.id` is the matching `auth.users.id`, and `vehicle_locations.vehicle_id` is both its primary key and vehicle foreign key.
- Use `timestamptz` for instants and `date` for date-only business values.
- Use `numeric(12,2)` for money. Speed uses `numeric(6,2)` in km/h; route progress uses `numeric(5,2)` percent; headings use degrees in `[0, 360)`.
- Use `NOT NULL DEFAULT now()` for creation/event timestamps where specified. Tables supporting metadata changes have `updated_at`, maintained by a shared `BEFORE UPDATE` trigger that sets it to `now()`.
- Operational entities are archived, deactivated, or cancelled instead of hard-deleted. Historical relationships use `ON DELETE RESTRICT`. No normal application workflow hard-deletes retained rows.
- Cross-table invariants are enforced by controlled server-side functions/transactions, not cross-table `CHECK` constraints. Database constraints still protect row-local invariants and concurrency-sensitive uniqueness.
- Derived values are calculated from source data and are not duplicated in stored columns unless explicitly stated.
- Text checks use `trim(value) <> ''`. Case-insensitive identifiers use expression indexes on `lower(value)`.

## 2. Enums

Create all enums before their dependent tables.

| Enum | Final values |
|---|---|
| `profile_role` | `admin`, `dispatcher`, `driver` |
| `driver_status` | `available`, `assigned`, `off_duty`, `inactive`, `archived` |
| `client_status` | `active`, `archived` |
| `vehicle_status` | `available`, `in_use`, `maintenance`, `out_of_service`, `archived` |
| `shipment_status` | `pending`, `assigned`, `loading`, `in_transit`, `delivered`, `cancelled` |
| `status_request_state` | `pending`, `approved`, `rejected` |
| `document_lifecycle_status` | `active`, `archived` |
| `expense_category` | `fuel`, `toll`, `driver`, `maintenance`, `other` |
| `notification_type` | `shipment_assigned`, `status_approval_requested`, `status_approved`, `status_rejected`, `shipment_delayed`, `vehicle_maintenance_due`, `vehicle_document_expiring`, `driver_document_expiring`, `new_dispatcher_message`, `shipment_delivered` |
| `alert_type` | `shipment_delayed`, `document_expiring`, `document_expired`, `maintenance_due_date`, `maintenance_due_mileage`, `stale_vehicle_location` |
| `alert_state` | `active`, `resolved` |
| `alert_severity` | `info`, `warning`, `critical` |
| `activity_action_type` | `driver_created`, `driver_status_changed`, `client_created`, `client_updated`, `client_archived`, `client_reactivated`, `vehicle_created`, `vehicle_updated`, `vehicle_status_changed`, `vehicle_archived`, `shipment_created`, `shipment_updated`, `shipment_assigned`, `shipment_status_changed`, `shipment_delayed`, `shipment_cancelled`, `status_request_created`, `status_request_approved`, `status_request_rejected`, `document_uploaded`, `document_archived`, `document_restored`, `maintenance_record_created`, `maintenance_record_updated`, `expense_created`, `expense_updated`, `alert_created`, `alert_resolved`, `tracking_started`, `tracking_stopped` |

`service_type`, `document_type`, `vehicle_type`, and `fuel_type` remain text in V1. The server uses stable canonical constants where required; `proof_of_delivery` is the canonical POD document type.

## 3. Tables

### 3.1 `profiles`

Application identity in a one-to-one relationship with Supabase Auth. Supabase Auth is the credential authority. Application tables do not duplicate email; store plaintext passwords, current passwords, new passwords, or password hashes; contain arbitrary metadata; or split admins/dispatchers into separate tables.

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY`, FK to `auth.users.id ON DELETE RESTRICT` |
| `full_name` | `text NOT NULL`, check `trim(full_name) <> ''` |
| `username` | `text NOT NULL`, check `trim(username) <> ''` |
| `role` | `profile_role NOT NULL` |
| `is_active` | `boolean NOT NULL DEFAULT true` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database integrity: `lower(username)` is unique. A unique driver profile relationship is enforced from `drivers.profile_id`.

Server-side rules: only Admin provisions accounts, changes roles, performs administrative credential resets for other accounts, and controls activation. Separately, an authenticated active Driver may change only their own Supabase Auth password through the approved self-service workflow after current-password verification; this grants no other account-management authority. Only a profile whose role is `driver` may have a driver row. An inactive profile cannot perform application actions or receive a new driver assignment. Profiles are deactivated with `is_active=false`, not normally deleted.

`profiles.is_active` is the V1 application account-lifecycle authority. Administrative deactivation and reactivation do not mutate Supabase-managed Auth session or refresh-token tables and do not delete, ban, disable, recreate, or enable the Supabase Auth user. Dispatcher lifecycle changes only `profiles.is_active`. Driver lifecycle changes atomically synchronize `profiles.is_active` with `drivers.status`: deactivation sets `false` and `inactive`, while reactivation sets `true` and `available`. A Driver assigned to a shipment in `assigned`, `loading`, or `in_transit` cannot be deactivated. Immediate Auth-session destruction is outside the database transaction and is not required in V1.

Driver Settings has no application-database persistence model in V1. No Driver settings/preferences table or settings/preference columns on `profiles` or `drivers` are introduced. Driver self-service password change mutates only the authenticated user's credential in Supabase Auth and performs no application-database mutation to `profiles`, `drivers`, shipments, vehicles, other operational data, notifications, or activity logs. Existing tables, enums, relationships, constraints, indexes, grants, and RLS policies remain unchanged by this capability, and direct Driver mutation of `profiles` and `drivers` remains denied.

Required indexes: unique expression index on `lower(username)`.

### 3.2 `drivers`

Driver-specific operational state attached to a driver profile.

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `profile_id` | `uuid NOT NULL`, FK to `profiles.id ON DELETE RESTRICT`, `UNIQUE` |
| `phone` | `text NULL`, check null or trimmed nonblank with at most 32 characters |
| `status` | `driver_status NOT NULL` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database integrity: one driver row per profile. Active-shipment uniqueness is enforced by the partial unique shipment index described under `shipments`.

Server-side rules: `profile.role` must be `driver`. `assigned` is synchronized with active shipment assignment. `inactive` is synchronized only by account lifecycle. Inactive/archived drivers and drivers whose profile is inactive cannot receive assignments. Status cannot be manually changed to contradict an active assignment.

Driver creation remains exclusively part of Admin account provisioning. Operations Driver Master Data permits an active Admin to edit only `phone`; an active Dispatcher has read-only access. Phone is trimmed, empty input becomes null, it is limited to 32 characters, and it has no uniqueness or country-specific format rule. An inactive target profile is read-only. Phone updates use `updated_at` optimistic concurrency, remain allowed during an active Shipment, and create no activity.

The only Operations Driver status actions are `mark_off_duty` (`available -> off_duty`), `mark_available` (`off_duty -> available`), `archive` (`available|off_duty -> archived`), and `reactivate` (`archived -> available`). Every action requires an active related profile with role `driver` and rejects a Driver assigned to a Shipment in `assigned`, `loading`, or `in_transit`. It changes no profile, Shipment, or Vehicle. Successful actions atomically create exactly one `driver_status_changed` activity whose sole primary entity is `driver_id` and whose metadata contains only `from_status`, `to_status`, and `operation`. All rejected and no-op actions create no activity, notification, or alert.

The status transaction locks the related profile, then the Driver, then any blocking active Shipment rows before changing status and inserting activity. Future Shipment assignment must share this profile-to-Driver eligibility serialization order and revalidate active profile, `available` status, and absence of an active Shipment. Driver document validity is not an assignment prerequisite in this phase. Archive retains every historical relationship and never deletes or deactivates the account.

Required indexes: unique index/constraint on `profile_id`; index on `status`.

### 3.3 `clients`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `company_name` | `text NOT NULL`, check nonblank |
| `contact_person` | `text NULL`, check null or nonblank |
| `phone` | `text NULL`, check null or nonblank |
| `email` | `text NULL`, check null or nonblank |
| `address` | `text NULL`, check null or nonblank |
| `notes` | `text NULL`, check null or nonblank |
| `status` | `client_status NOT NULL DEFAULT 'active'` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Neither company name nor email is unique. Client shipment history is derived through `shipments.client_id`; there is no client-history table. Archived clients remain readable historically but cannot receive new shipments.

Client archive is the transition `active -> archived`; reactivation is `archived -> active`. Archive must lock and revalidate the Client row, require its current state to be `active`, and reject while any related shipment is `pending`, `assigned`, `loading`, or `in_transit`. `delivered` and `cancelled` shipments do not block archive, and the separate `delayed` flag has no effect on archive eligibility. A rejected archive changes no row and creates no activity. Archive never deletes or modifies shipments or their Driver/Vehicle assignments, and `shipments.client_id` remains intact.

Future shipment creation must lock and revalidate the same Client row and require `clients.status = 'active'` before inserting the shipment. Client archive and shipment creation therefore serialize through the Client lifecycle row. Shipment creation is not part of the Client-management implementation.

Each successful Client create, real business-field update, archive, or reactivation creates exactly one matching `client_created`, `client_updated`, `client_archived`, or `client_reactivated` activity row in the same transaction. A no-op edit, wrong lifecycle transition, stale edit, blocked archive, or other failed mutation creates no activity row.

Required indexes: index on `status`.

### 3.4 `vehicles`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `registration` | `text NOT NULL`, check nonblank |
| `make` | `text NOT NULL`, check nonblank |
| `model` | `text NOT NULL`, check nonblank |
| `vehicle_type` | `text NOT NULL`, check nonblank |
| `vin` | `text NULL`, check null or nonblank |
| `mileage` | `integer NOT NULL DEFAULT 0`, check `mileage >= 0` |
| `fuel_type` | `text NULL`, check null or nonblank |
| `first_registration_date` | `date NULL` |
| `status` | `vehicle_status NOT NULL` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database integrity: registration is trimmed, nonblank, at most 32 characters, preserves entered casing, and is unique case-insensitively. VIN is trimmed, empty input becomes null, is at most 64 characters when present, preserves casing, and is unique case-sensitively when present. Active-shipment uniqueness is enforced under `shipments`.

Server-side rules: only an active Admin creates or mutates Vehicle master data; Dispatcher access is read-only. Creation always uses `available` and may provide nonnegative initial mileage. Ordinary edits are limited to registration, make, model, vehicle type, VIN, fuel type, and first registration date and use `updated_at` optimistic concurrency. Mileage is kilometres, uses a dedicated operation, never decreases, and equal mileage is a no-op. `in_use` is synchronized only by active assignment. Vehicles in `maintenance`, `out_of_service`, or `archived` cannot receive assignments. Controlled maintenance creation may increase mileage but does not change Vehicle status.

Named lifecycle operations are `mark_maintenance` (`available -> maintenance`), `mark_available` (`maintenance|out_of_service -> available`), `mark_out_of_service` (`available|maintenance -> out_of_service`), `archive` (`available|maintenance|out_of_service -> archived`), and `reactivate` (`archived -> available`). All other transitions, including every manual transition to or from `in_use`, are rejected. A Shipment in `assigned`, `loading`, or `in_transit` blocks every lifecycle action; delivered/cancelled and delayed do not. Lifecycle changes no related entity. Hard delete is prohibited.

Each real mutation creates exactly one same-transaction activity with `vehicle_id` as the sole primary entity and the authenticated active Admin as actor: create uses `vehicle_created` with `{"status":"available"}`; ordinary edit uses `vehicle_updated` with an ordered `changed_fields` array containing only actually changed approved names; mileage increase uses `vehicle_updated` with `{"field":"mileage","from":n,"to":n,"unit":"km"}`; archive uses `vehicle_archived`; other lifecycle operations use `vehicle_status_changed`, both with `from_status`, `to_status`, and `operation`. Failed, unauthorized, duplicate, stale, invalid, blocked, and normalized no-op operations create no activity.

Required indexes: unique expression index on `lower(registration)`; unique partial index on `vin WHERE vin IS NOT NULL`; index on `status`.

### 3.5 `shipments`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `tracking_number` | `text NOT NULL`, check nonblank |
| `client_id` | `uuid NOT NULL`, FK to `clients.id ON DELETE RESTRICT` |
| `pickup_address` | `text NOT NULL`, check nonblank |
| `delivery_address` | `text NOT NULL`, check nonblank |
| `pickup_at` | `timestamptz NOT NULL` |
| `expected_delivery_at` | `timestamptz NOT NULL`, check `expected_delivery_at >= pickup_at` |
| `cargo_type` | `text NOT NULL`, check nonblank |
| `driver_id` | `uuid NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `vehicle_id` | `uuid NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `price` | `numeric(12,2) NOT NULL`, check `price >= 0` |
| `status` | `shipment_status NOT NULL DEFAULT 'pending'` |
| `delayed` | `boolean NOT NULL DEFAULT false` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database checks:

- Driver and vehicle are paired: both are null or both are non-null.
- `pending` requires both assignment fields null.
- `assigned`, `loading`, `in_transit`, and `delivered` require both assignment fields non-null.
- `cancelled` may retain an assignment or have none.
- `delayed=true` is permitted only for `in_transit`; all other statuses require `delayed=false`.
- Tracking number has `UNIQUE(tracking_number)` database enforcement.

Concurrency integrity: unique partial indexes on `driver_id` and `vehicle_id`, each filtered to `status IN ('assigned','loading','in_transit')`, prevent double assignment to active shipments.

Server-side rules: `tracking_number` is generated only inside the narrow pending-Shipment creation transaction in `SHP-YYYY-NNN` format. `YYYY` is the database UTC year; numbering resets yearly, uses a minimum three-digit suffix, continues naturally above 999, and retries allocation after a uniqueness collision. Allow only the finalized workflow `pending -> assigned -> loading -> in_transit -> delivered`, with `cancelled` as an alternative terminal state. Assignment requires an active client, active/available driver, active driver profile, and available vehicle. POD is required before approving delivery. Assignment/status approval is transactional; it synchronizes driver and vehicle state, releases both on delivery/cancellation, and creates activity/notification side effects in the same workflow where practical.

Derived values: total expenses are `SUM(expenses.amount)`; profit is `shipments.price - total expenses`. Neither is stored.

Required indexes: unique constraint/index on `tracking_number`; indexes on `client_id`, `status`, `pickup_at`, and `expected_delivery_at`; partial indexes on `driver_id WHERE driver_id IS NOT NULL` and `vehicle_id WHERE vehicle_id IS NOT NULL`; both active-assignment partial unique indexes. A unique index on `lower(tracking_number)` may replace `UNIQUE(tracking_number)` only if mixed-case tracking numbers are intentionally supported by the finalized tracking-number format.

### 3.6 `shipment_status_requests`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `shipment_id` | `uuid NOT NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `driver_id` | `uuid NOT NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `current_status` | `shipment_status NOT NULL` |
| `requested_status` | `shipment_status NOT NULL` |
| `request_state` | `status_request_state NOT NULL DEFAULT 'pending'` |
| `requested_at` | `timestamptz NOT NULL DEFAULT now()` |
| `resolved_at` | `timestamptz NULL` |
| `resolved_by_profile_id` | `uuid NULL`, FK to `profiles.id ON DELETE RESTRICT` |
| `rejection_reason` | `text NULL`, check null or nonblank |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database checks:

- `current_status <> requested_status`.
- Pending: `resolved_at`, resolver, and rejection reason are null.
- Approved: resolution time and resolver are non-null; rejection reason is null.
- Rejected: resolution time and resolver are non-null; rejection reason is optional.
- `resolved_at IS NULL OR resolved_at >= requested_at`.
- A partial unique index on `shipment_id WHERE request_state='pending'` permits only one unresolved request per shipment. Do not use uniqueness on `(shipment_id, driver_id)`.

Server-side rules: only the currently assigned Driver may request the next valid transition. Only Admin or Dispatcher may resolve a request. Approval locks and revalidates the request and shipment, verifies the recorded current status, validates the transition and POD when delivering, then atomically updates shipment/request/resource states and creates notifications/activity logs. A stale request cannot be approved. Resolved requests are immutable through normal workflows.

Required indexes: indexes on `shipment_id`, `driver_id`, `request_state`, and `requested_at`; unique partial pending-request index.

### 3.7 `maintenance_records`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `vehicle_id` | `uuid NOT NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `service_type` | `text NOT NULL`, check nonblank |
| `service_date` | `date NOT NULL` |
| `mileage_at_service` | `integer NOT NULL`, check `>= 0` |
| `workshop` | `text NULL`, check null or nonblank |
| `cost` | `numeric(12,2) NULL`, check null or `>= 0` |
| `notes` | `text NULL`, check null or nonblank |
| `next_service_date` | `date NULL`, check null or `> service_date` |
| `next_service_mileage` | `integer NULL`, check null or `> mileage_at_service` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Server-side rules: only Admin creates/edits records. Vehicle mileage never decreases; a larger service mileage may increase it in the same transaction. Historical maintenance does not set vehicle status to `maintenance`. Maintenance cost is not copied to expenses. Alerts derive from the latest relevant record and current date/mileage, using 14 days and 1,000 km as centralized V1 thresholds.

Required indexes: `(vehicle_id, service_date DESC)`; partial indexes on non-null `next_service_date` and `next_service_mileage`.

### 3.8 `documents`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `shipment_id` | `uuid NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `vehicle_id` | `uuid NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `driver_id` | `uuid NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `uploader_profile_id` | `uuid NOT NULL`, FK to `profiles.id ON DELETE RESTRICT` |
| `document_type` | `text NOT NULL`, check nonblank |
| `file_path` | `text NOT NULL`, check nonblank, `UNIQUE` |
| `file_name` | `text NOT NULL`, check nonblank |
| `lifecycle_status` | `document_lifecycle_status NOT NULL DEFAULT 'active'` |
| `uploaded_at` | `timestamptz NOT NULL DEFAULT now()` |
| `valid_from` | `date NULL` |
| `valid_until` | `date NULL` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database checks: exactly one owner via `num_nonnulls(shipment_id, vehicle_id, driver_id) = 1`; validity range is valid when both dates exist; `document_type <> 'proof_of_delivery' OR shipment_id IS NOT NULL`. `file_path` uniquely identifies the Supabase Storage object.

Derived expiry state, which is not stored:

- If `lifecycle_status='archived'`: `archived`.
- Else if `valid_until IS NULL`: `no_expiry`.
- Else if `valid_until < current_date`: `expired`.
- Else if `valid_until <= current_date + configured threshold`: `expiring`.
- Else: `valid`.

The configured V1 document-expiry threshold is an application constant of 30 days.

Server-side rules: enforce upload permissions and canonical types; coordinate Storage upload and metadata insertion, cleaning the object if insertion fails. Document upload may create an appropriate user notification. Expiring or expired document processing creates the appropriate notification for the relevant user where applicable. Document alerts and notifications remain separate concepts. An active, non-archived POD belonging to the shipment is required before delivery approval. Physical replacement creates a new row and archives the old one. Metadata is not normally hard-deleted. `uploaded_at` preserves original upload time; `updated_at` tracks permitted metadata corrections/archival.

Required indexes: unique index on `file_path`; partial owner timelines `(shipment_id, uploaded_at DESC)`, `(vehicle_id, uploaded_at DESC)`, and `(driver_id, uploaded_at DESC)` for non-null owners; indexes on `uploader_profile_id`, `lifecycle_status`, and non-null `valid_until`.

### 3.9 `expenses`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `shipment_id` | `uuid NOT NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `created_by_profile_id` | `uuid NOT NULL`, FK to `profiles.id ON DELETE RESTRICT` |
| `category` | `expense_category NOT NULL` |
| `amount` | `numeric(12,2) NOT NULL`, check `amount > 0` |
| `expense_date` | `date NOT NULL` |
| `description` | `text NULL`, check null or nonblank |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Only Admin and Dispatcher create/edit expenses. All important expense creation and update operations must create an `activity_logs` entry. Creator is immutable provenance; later editor identity is captured in activity logs. Maintenance cost is never automatically duplicated; a maintenance-category expense is manually recorded only when it belongs to the shipment. Records are retained.

Required indexes: `(shipment_id, expense_date DESC)`, `created_by_profile_id`, and `expense_date`.

### 3.10 `messages`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `sender_profile_id` | `uuid NOT NULL`, FK to `profiles.id ON DELETE RESTRICT` |
| `recipient_driver_id` | `uuid NOT NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `shipment_id` | `uuid NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `body` | `text NOT NULL`, check nonblank |
| `sent_at` | `timestamptz NOT NULL DEFAULT now()` |
| `read_at` | `timestamptz NULL`, check null or `>= sent_at` |

Messages have no `updated_at`. They are immutable after sending except for `read_at`, and unread is derived from `read_at IS NULL`.

Server-side/RLS rules: only Admin or Dispatcher sends; sender must equal the authenticated profile. Drivers cannot reply and can access only their own messages; they may update only `read_at`. A shipment-linked message must target that shipment's assigned driver. Inactive, archived, or deactivated drivers cannot receive new messages. Messages are retained and not normally deleted.

Required indexes: `(recipient_driver_id, sent_at DESC)`; unread partial variant with `read_at IS NULL`; partial shipment timeline for non-null `shipment_id`.

### 3.11 `notifications`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `recipient_profile_id` | `uuid NOT NULL`, FK to `profiles.id ON DELETE RESTRICT` |
| `notification_type` | `notification_type NOT NULL` |
| `title` | `text NOT NULL`, check nonblank |
| `message` | `text NOT NULL`, check nonblank |
| `shipment_id` | `uuid NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `vehicle_id` | `uuid NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `driver_id` | `uuid NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `document_id` | `uuid NULL`, FK to `documents.id ON DELETE RESTRICT` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `read_at` | `timestamptz NULL`, check null or `>= created_at` |

Database integrity: zero or one concrete related entity via `num_nonnulls(shipment_id, vehicle_id, driver_id, document_id) <= 1`. Generic/polymorphic entity references are prohibited.

Notifications are immutable except `read_at`; unread and header count derive from rows where `read_at IS NULL`. Trusted workflows ensure type/entity compatibility, supply expected references, avoid unnecessary duplicates, and separate notifications from alerts. Only the recipient marks a notification read; content cannot be user-edited.

Required indexes: `(recipient_profile_id, created_at DESC)` and its unread partial variant.

### 3.12 `alerts`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `alert_type` | `alert_type NOT NULL` |
| `severity` | `alert_severity NOT NULL` |
| `message` | `text NOT NULL`, check nonblank |
| `alert_state` | `alert_state NOT NULL DEFAULT 'active'` |
| `shipment_id` | `uuid NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `vehicle_id` | `uuid NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `driver_id` | `uuid NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `document_id` | `uuid NULL`, FK to `documents.id ON DELETE RESTRICT` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` |
| `resolved_at` | `timestamptz NULL` |
| `resolved_by_profile_id` | `uuid NULL`, FK to `profiles.id ON DELETE RESTRICT` |

Database checks: exactly one concrete related entity via `num_nonnulls(...) = 1`; resolution time is null or not earlier than creation. Active alerts require null resolution fields; resolved alerts require both. Generic references are prohibited.

Four partial unique indexes prevent duplicate active alerts by `(alert_type, entity_id)` separately for non-null shipment, vehicle, driver, and document references. A recurrence after resolution creates a new row; resolved alerts are not reactivated or normally modified.

Server/scheduled rules: calculate conditions using centralized thresholds—document expiry 30 days, maintenance date 14 days, maintenance mileage 1,000 km, stale location 10 minutes—and resolve according to alert type. V1 severity is fixed: `shipment_delayed` -> `warning`; `document_expiring` -> `warning`; `document_expired` -> `critical`; `maintenance_due_date` -> `warning`; `maintenance_due_mileage` -> `warning`; `stale_vehicle_location` -> `critical`. Severity is not configurable in V1. Alerts remain distinct from notifications.

Required indexes: `(alert_state, severity, created_at DESC)` and all four active-alert partial unique indexes.

### 3.13 `vehicle_locations`

Mutable current-state table designed for realtime subscriptions. Actual Supabase Realtime publication configuration belongs to `ARCHITECTURE.md` or implementation configuration.

| Column | Definition |
|---|---|
| `vehicle_id` | `uuid PRIMARY KEY`, FK to `vehicles.id ON DELETE CASCADE` |
| `shipment_id` | `uuid NOT NULL`, FK to `shipments.id ON DELETE CASCADE` |
| `latitude` | `double precision NOT NULL`, check between -90 and 90 |
| `longitude` | `double precision NOT NULL`, check between -180 and 180 |
| `speed` | `numeric(6,2) NULL`, check null or `>= 0` (km/h) |
| `heading` | `double precision NULL`, check null or `>= 0 AND < 360` |
| `route_progress` | `numeric(5,2) NULL`, check null or between 0 and 100 |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` |

Database integrity: one current row per vehicle and `UNIQUE(shipment_id)` provides one current row per shipment. Cascade deletion is acceptable only because this row has no independent historical value; normal workflows still archive operational parents.

Trusted simulator rules: a row may exist only while its referenced shipment is `in_transit`; `shipment_id` is therefore always present. The shipment's `vehicle_id` must equal `vehicle_locations.vehicle_id`. UPSERT by vehicle, refresh `updated_at` on every sample, reject arbitrary client writes, and delete the row when the shipment leaves `in_transit`. Stale detection uses `updated_at`; history remains in `tracking_history`.

Required indexes: primary key on `vehicle_id`; unique constraint/index on `shipment_id`.

### 3.14 `tracking_history`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `vehicle_id` | `uuid NOT NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `shipment_id` | `uuid NOT NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `latitude` | `double precision NOT NULL`, check between -90 and 90 |
| `longitude` | `double precision NOT NULL`, check between -180 and 180 |
| `speed` | `numeric(6,2) NULL`, check null or `>= 0` (km/h) |
| `heading` | `double precision NULL`, check null or `>= 0 AND < 360` |
| `route_progress` | `numeric(5,2) NULL`, check null or between 0 and 100 |
| `recorded_at` | `timestamptz NOT NULL DEFAULT now()` |

Rows are append-only, have no `updated_at`, and are retained indefinitely. Trusted simulator logic validates shipment/vehicle matching, uses trusted time, and samples at an architecture-defined interval rather than every animation frame. `route_progress` must be non-decreasing for snapshots within the same shipment in the normal V1 workflow; trusted simulator/server logic enforces this because it cannot be enforced by a row-local database `CHECK`. A final snapshot may reach 100. Removing current location never removes history.

Required indexes: `(shipment_id, recorded_at ASC)` for route history and `(vehicle_id, recorded_at DESC)` for recent vehicle history.

### 3.15 `activity_logs`

| Column | Definition |
|---|---|
| `id` | `uuid PRIMARY KEY` |
| `actor_profile_id` | `uuid NULL`, FK to `profiles.id ON DELETE RESTRICT`; null means system action |
| `action_type` | `activity_action_type NOT NULL` |
| `occurred_at` | `timestamptz NOT NULL DEFAULT now()` |
| `shipment_id` | `uuid NULL`, FK to `shipments.id ON DELETE RESTRICT` |
| `vehicle_id` | `uuid NULL`, FK to `vehicles.id ON DELETE RESTRICT` |
| `driver_id` | `uuid NULL`, FK to `drivers.id ON DELETE RESTRICT` |
| `client_id` | `uuid NULL`, FK to `clients.id ON DELETE RESTRICT` |
| `document_id` | `uuid NULL`, FK to `documents.id ON DELETE RESTRICT` |
| `status_request_id` | `uuid NULL`, FK to `shipment_status_requests.id ON DELETE RESTRICT` |
| `maintenance_record_id` | `uuid NULL`, FK to `maintenance_records.id ON DELETE RESTRICT` |
| `expense_id` | `uuid NULL`, FK to `expenses.id ON DELETE RESTRICT` |
| `metadata` | `jsonb NULL`, check null or `jsonb_typeof(metadata)='object'` |

Database integrity: exactly one primary related entity is mandatory using `num_nonnulls(shipment_id, vehicle_id, driver_id, client_id, document_id, status_request_id, maintenance_record_id, expense_id) = 1`.

Rows are immutable, append-only, have no `updated_at`, and are retained indefinitely. Only trusted workflows insert them. The session determines a user actor; system actions use null. Action and primary entity must match. Multi-entity operations select one primary entity and may place minimal structured context in metadata. Activity-log insertion should occur in the same transaction as the related business action where practical; this is a server-side transactional guideline, not a universal database constraint.

Every action type maps to exactly one existing primary related entity column:

| Action types | Required primary entity |
|---|---|
| `driver_created`, `driver_status_changed` | `driver_id` |
| `client_created`, `client_updated`, `client_archived`, `client_reactivated` | `client_id` |
| `vehicle_created`, `vehicle_updated`, `vehicle_status_changed`, `vehicle_archived` | `vehicle_id` |
| `shipment_created`, `shipment_updated`, `shipment_assigned`, `shipment_status_changed`, `shipment_delayed`, `shipment_cancelled` | `shipment_id` |
| `status_request_created`, `status_request_approved`, `status_request_rejected` | `status_request_id` |
| `document_uploaded`, `document_archived`, `document_restored` | `document_id` |
| `maintenance_record_created`, `maintenance_record_updated` | `maintenance_record_id` |
| `expense_created`, `expense_updated` | `expense_id` |
| `tracking_started`, `tracking_stopped` | `shipment_id` |
| `alert_created`, `alert_resolved` | The same single operational entity stored by the related alert: `shipment_id`, `vehicle_id`, `driver_id`, or `document_id` |

For alert activity, metadata may record the alert type and lifecycle details, but it never replaces the required primary entity relationship. `profile_created`, `profile_deactivated`, `profile_reactivated`, and `message_sent` are not V1 activity action types because the finalized `activity_logs` table has no valid primary-entity relationship for them. `tracking_snapshot_recorded` is not a V1 action type; individual tracking snapshots are not activity-log events.

Metadata may contain small change facts such as status transitions or old/new expense amounts. It must never contain passwords, tokens, private signed URLs, full objects, arbitrary API responses, unnecessary duplication, or sensitive personal data. Do not log trivial UI actions, read acknowledgements, or every tracking update.

Required indexes: `occurred_at DESC`; partial timelines `(actor_profile_id, occurred_at DESC)`, `(shipment_id, occurred_at DESC)`, `(vehicle_id, occurred_at DESC)`, and `(driver_id, occurred_at DESC)` for non-null values.

## 4. Mutability, retention, and derived data

| Classification | Tables / fields |
|---|---|
| Mutable operational | `profiles`, `drivers`, `clients`, `vehicles`, `shipments`, unresolved `shipment_status_requests`, `maintenance_records`, document metadata, `expenses`, notification `read_at`, unresolved `alerts` |
| Mutable current state | `vehicle_locations` |
| Immutable/append-only | `tracking_history`, `activity_logs` |
| Immutable with one acknowledgement field | `messages` except `read_at`; `notifications` except `read_at` |
| Immutable after resolution | resolved status requests and resolved alerts |
| Retained historical data | tracking history, activity logs, maintenance, expenses, documents, messages, resolved alerts, resolved status requests |

Do not store shipment expense totals/profit, unread booleans, document expiry state, client shipment history, or maintenance alert state. Calculate unread from `read_at IS NULL`, document state from lifecycle/date, client history from shipments, and finances from shipment price and expenses.

## 5. Atomic transactional workflows

### Shipment assignment

Lock/revalidate the pending shipment; validate active client, available active driver/profile, and available vehicle; set both assignments and shipment to `assigned`; set driver to `assigned` and vehicle to `in_use`; then create the shipment activity and assignment notification in the same transaction. Partial unique indexes are the final concurrency backstop.

The global relative lock order is Client, Driver Profile, Driver, Vehicle, Shipment. Creation locks/revalidates Client, generates the identifier, inserts the pending Shipment, and creates exactly one `shipment_created` activity with `{"status":"pending"}`. Assignment may first read `client_id` without locking solely to identify the lock target, then locks in the global order and finally revalidates the Shipment. It creates exactly one `shipment_assigned` activity with `{"driver_status":"assigned","vehicle_status":"in_use"}` and one notification for the Driver profile titled `New shipment assigned` with message `Shipment {tracking_number} has been assigned to you.` Creation and assignment are separate narrow functions in the same existing Shipment controlled-workflow category; the category inventory remains exactly eight.

### Status request approval or rejection

Lock the request and shipment; require a pending request and matching current shipment state; authorize Admin/Dispatcher; validate the next transition and active POD for delivery; atomically update shipment and resolution, synchronize/release resources, stop tracking when leaving `in_transit`, and create appropriate notifications/activity records. Rejection leaves shipment state unchanged and records the optional reason.

S2 extends the global relative lock order to Client, Driver Profile, Driver, Vehicle, Shipment, Shipment Status Request, Document, Vehicle Location, then Alert. A workflow omits irrelevant types but never reverses participating types. Tracking history, activity, and notification rows are append-only effects and are not locked before mutable business rows.

Only an active assigned Driver may create the exact next request in `assigned -> loading -> in_transit -> delivered`. Creation records one `status_request_created` activity with only `from_status` and `requested_status`, then sends one `status_approval_requested` notification to every active Admin and Dispatcher. Its title is `Shipment status request`; its message is `Shipment {tracking_number}: Driver requested {requested_status_label}.`

Approval records one `status_request_approved` request activity and one `shipment_status_changed` Shipment activity with operation `status_request_approved`, then sends one `status_approved` notification to the assigned Driver titled `Shipment status approved` with message `Shipment {tracking_number} is now {requested_status_label}.` Entering `in_transit` initializes the trusted simulation at latitude `45.2671`, longitude `19.8335`, heading `0`, speed `0`, and route progress `0`, inserts the identical first history snapshot, and records `tracking_started`. This seed is not geocoded or real GPS accuracy. Delivery requires an active Shipment-owned `proof_of_delivery`, forces `delayed=false`, releases Driver to `available` and Vehicle to `available`, performs tracking stop, and records `tracking_stopped`.

Rejection, including manual rejection of a stale pending request, changes only request resolution fields, records one `status_request_rejected` activity without the reason in metadata, and sends the requesting active Driver a `status_rejected` notification. The reason is optional, trimmed, limited to 500 characters, and empty input is null. If the original Driver Profile cannot validly receive a notification, rejection still succeeds without one. Stale requests cannot be approved; S2 performs no automatic stale rejection.

### Maintenance creation

Insert the record, increase—but never reduce—vehicle mileage when required, create the activity record, and refresh relevant alert evaluation in one controlled workflow.

### Vehicle master-data mutations and operational lifecycle

Vehicle creation, ordinary edit, mileage update, and lifecycle transition use separate narrow controlled functions. Each derives and verifies an active Admin, locks and re-reads trusted state where applicable, validates exact inputs, and atomically writes the Vehicle mutation and its activity. Ordinary edit and mileage use `updated_at` optimistic concurrency. Lifecycle locks the Vehicle before locking/checking blocking Shipment rows. Future maintenance locks Vehicle before its maintenance record. Future assignment locks Shipment, Client, Driver profile, Driver, then Vehicle and revalidates eligibility; no Vehicle-first workflow later acquires Driver/profile locks.

Operations Vehicle reads use narrow role-gated security-definer functions because Admin/Dispatcher require columns that must remain unavailable through the Driver C2 table grant. List/type reads require an active Admin or Dispatcher; edit-safe read requires an active Admin. These functions expose only operation-specific presentation fields and do not broaden Vehicle table grants or Driver RLS.

### Document upload

Authorize and upload the physical Storage object before metadata insertion. Insert metadata and activity, then refresh expiry alerts where applicable. If metadata creation fails, compensate by deleting the just-uploaded object. Replacement creates a new metadata/object row and archives the former document.

### Tracking start and stop

Tracking start validates that the shipment is `in_transit` and that its assigned vehicle matches, creates or UPSERTs `vehicle_locations`, inserts an initial `tracking_history` snapshot, and creates the `tracking_started` activity log.

Tracking stop inserts a final `tracking_history` snapshot using the final current coordinates, deletes the `vehicle_locations` row, resolves active `stale_vehicle_location` alerts for that vehicle, and creates the `tracking_stopped` activity log. If no current `vehicle_locations` row exists at stop time, the operation does not invent a final snapshot.

Storage upload plus database insert cannot be one PostgreSQL transaction; it uses the explicit compensating cleanup described above. Only the explicitly documented multi-step business workflows are transactional.

## 6. RLS and security plan

- Enable RLS on every `public` application table. Clients must not bypass controlled workflow functions for protected mutations.
- Admin has full operational access. Dispatcher has operational access but no account/role administration and no company-wide financial-report privilege. Driver access is restricted through the authenticated profile and its single `drivers.profile_id` relationship.
- Drivers may read only their shipments, assigned vehicle information needed for their work, permitted documents, their messages, and their notifications. They can create permitted status requests/documents and acknowledge only their own message/notification `read_at` fields.
- Restrict historical inserts to trusted server functions; deny normal updates/deletes on append-only rows and resolved records. Restrict tracking writes to the trusted simulator/service role.
- Controlled server-side or database functions may be used for transactional workflows.
- Supabase Storage policies must align object access with document ownership/role rules. Never expose service-role credentials or persist signed URLs.
- Full RLS policies are intentionally deferred.

## 7. Dependency-safe creation order

1. All enums.
2. `profiles`.
3. `drivers`.
4. `clients`.
5. `vehicles`.
6. `shipments`.
7. `shipment_status_requests`.
8. `maintenance_records`.
9. `documents`.
10. `expenses`.
11. `messages`.
12. `notifications`.
13. `alerts`.
14. `vehicle_locations`.
15. `tracking_history`.
16. `activity_logs`.
17. Required indexes.
18. Shared `updated_at` function and triggers.
19. Controlled helper/transactional functions.
20. RLS enablement, grants, and policies.

Apply the `updated_at` trigger to `profiles`, `drivers`, `clients`, `vehicles`, `shipments`, `shipment_status_requests`, `maintenance_records`, `documents`, and `expenses`. `vehicle_locations.updated_at` is refreshed by each trusted UPSERT. Do not add the trigger or column to immutable event tables.

## 8. Consolidated required index inventory

Primary keys and ordinary indexes backing declared `UNIQUE` constraints are implicit in addition to this inventory.

| Table | Required indexes |
|---|---|
| `profiles` | unique `lower(username)` |
| `drivers` | unique `profile_id`; `status` |
| `clients` | `status` |
| `vehicles` | unique `lower(registration)`; unique `vin WHERE vin IS NOT NULL`; `status` |
| `shipments` | unique `tracking_number`; `client_id`; `status`; `pickup_at`; `expected_delivery_at`; partial `driver_id`; partial `vehicle_id`; unique active `driver_id`; unique active `vehicle_id` |
| `shipment_status_requests` | `shipment_id`; `driver_id`; `request_state`; `requested_at`; unique pending `shipment_id` |
| `maintenance_records` | `(vehicle_id, service_date DESC)`; partial `next_service_date`; partial `next_service_mileage` |
| `documents` | unique `file_path`; three partial owner/upload timelines; `uploader_profile_id`; partial `valid_until`; `lifecycle_status` |
| `expenses` | `(shipment_id, expense_date DESC)`; `created_by_profile_id`; `expense_date` |
| `messages` | recipient/sent timeline; unread recipient/sent timeline; partial shipment/sent timeline |
| `notifications` | recipient/created timeline; unread recipient/created timeline |
| `alerts` | state/severity/created timeline; four active-alert partial unique indexes |
| `vehicle_locations` | primary key `vehicle_id`; unique `shipment_id` |
| `tracking_history` | shipment/recorded ascending; vehicle/recorded descending |
| `activity_logs` | occurred descending; partial actor, shipment, vehicle, and driver timelines |

Index predicates and sort directions must match the definitions in each table section.

### Optional / add when required by actual query patterns

These are intentionally not required for initial V1 migrations. Add them only after real query patterns and `EXPLAIN (ANALYZE, BUFFERS)` justify them:

- `profiles(role)` and `profiles(is_active)` for account-management lists.
- `clients(company_name)` for client search. Text search may ultimately require a pattern-appropriate index rather than a plain B-tree.
- Notification entity timeline indexes for `shipment_id`, `vehicle_id`, `driver_id`, or `document_id`.
- Alert entity-history indexes beyond the required active-alert uniqueness indexes.
- Activity timeline indexes for `client_id`, `document_id`, `status_request_id`, `maintenance_record_id`, or `expense_id`.

Do not create other speculative indexes merely to remove optional wording. Validate optional indexes against actual query shape and write frequency before adding them.
