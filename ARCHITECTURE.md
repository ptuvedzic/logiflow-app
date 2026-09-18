# LogiFlow V1 Application Architecture

**Status:** Production-ready V1 architecture  
**Product scope authority:** `PRD.md`  
**Database authority:** `DATABASE.md`  
**Secondary consistency reference:** `final-schema.md`

## 1. Purpose and architectural principles

This document defines the application architecture for LogiFlow V1, an internal logistics and fleet-management application for one transport company. It does not change the approved product scope or database schema. `DATABASE.md` is authoritative for tables, columns, enums, constraints, transactional responsibilities, notification behavior, and alert behavior. If this document and `DATABASE.md` differ, `DATABASE.md` wins and this document must be corrected.

The V1 architecture follows these rules:

- Next.js owns web rendering, browser interaction boundaries, session-aware orchestration, and presentation.
- Supabase owns authentication, PostgreSQL persistence, transactional database functions, private document storage, Realtime delivery, scheduled execution, and tracking Edge Functions.
- Server Components are the default rendering model. Client Components are deliberately small interactive islands.
- Browser input is untrusted. Authentication and authorization are repeated at every callable server boundary.
- Cross-row and concurrency-sensitive business workflows execute through controlled database functions.
- Historical business data is archived, cancelled, or retained according to `DATABASE.md`; normal application workflows do not hard-delete it.
- All timestamps are stored and scheduled in UTC. The UI converts timestamps to the user's display timezone.

Statements labeled **Architecture decision** resolve implementation choices that are not fixed by the PRD or database specification.

## 2. Technology stack and responsibilities

| Technology | V1 responsibility |
| --- | --- |
| Next.js 16 App Router | Routing, layouts, Server Components, Server Actions, Route Handlers, error boundaries, metadata, and deployment web runtime |
| React 19 | Server-rendered UI and focused client-side interaction |
| TypeScript in strict mode | Application types, generated database types, validated inputs, and typed result/error contracts |
| Tailwind CSS 4 | Responsive design system and role-specific application shells |
| Supabase Auth | Password authentication and secure cookie-backed sessions |
| Supabase PostgreSQL | Authoritative operational data, constraints, RLS, grants, controlled functions, transactions, and reporting queries |
| Supabase Storage | Private vehicle, driver, and shipment documents |
| Supabase Realtime | Postgres Changes subscriptions for `vehicle_locations` only |
| Supabase Edge Functions | Trusted tracking simulation and authenticated scheduled-job entry points |
| Supabase Cron (`pg_cron`) | Ten-second tracking invocation and periodic operational checks |
| `@supabase/ssr` and `@supabase/supabase-js` | Cookie-aware server/browser Supabase clients and server-only administrative clients |
| Zod | Runtime validation for form, action, endpoint, environment, and upload-intent inputs |
| MapLibre GL JS | Client-side map, route, markers, progress, and simulated-tracking display |

**Architecture decision:** The application uses one Next.js deployment and one Supabase project per environment. Local development, staging, and production never share a Supabase project.

**Architecture decision:** Map tiles and route geometry are supplied through environment-configured map endpoints. Map configuration is public; provider secrets are not embedded in the browser. V1 stores no additional route-geometry data in PostgreSQL.

## 3. Next.js application structure

The App Router is divided into public authentication routes and two protected experiences:

- `(auth)` contains the username/password login UI. There is no sign-up route.
- `(operations)` contains the shared Admin/Dispatcher desktop-first application shell.
- `(driver)` contains the mobile-first Driver shell.

The root `proxy.ts` is the standard Supabase SSR session-refresh boundary. It refreshes the Supabase session for incoming requests and propagates every refreshed cookie to both the request passed into Next.js and the response returned to the browser. Protected layouts and Server Components consume this refreshed server session. Every authorization decision uses the refreshed server session rather than a stale cookie value or client-side session state.

Protected layouts perform an early refreshed-session and role check for navigation and user experience. This layout check is not the security boundary: every Server Action, Route Handler, DAL function, controlled database function, RLS policy, and Storage policy independently enforces its own authorization.

Feature routes use loading, error, and not-found boundaries. List filters and pagination are represented in URL search parameters so pages remain linkable and Server Components can perform the corresponding queries. Mutations invalidate the smallest affected route or cache tag; operational pages that depend on session state are dynamically rendered.

### Rendering boundaries

Server Components perform:

- authenticated initial reads;
- dashboards, reports, detail views, and list composition;
- role-aware navigation data;
- server-side pagination and filtering;
- initial vehicle-location and unread-count snapshots;
- generation of short-lived document download links after authorization.

Client Components are limited to:

- form controls that require local state;
- dialog, drawer, tab, and responsive-navigation behavior;
- interactive data-table controls;
- upload selection, progress, and direct Storage transfer;
- MapLibre rendering and Realtime subscription lifecycle;
- optimistic read acknowledgements and mutation pending states.

Client Components receive only the minimum serializable data needed to render. Service-role credentials, internal Auth identifiers, raw authorization decisions, and unrestricted database clients never cross the server/client boundary.

## 4. Server and database boundaries

### 4.1 Server Actions

Server Actions are the standard browser-mutation boundary. They validate input, verify the current session, load the current `profiles` row, enforce the required permission, call a DAL command or controlled database function, translate errors, and invalidate affected data.

Each action is treated as a directly callable public endpoint. An action never trusts a role, actor ID, driver ID, username mapping, price calculation, or ownership assertion supplied by the browser.

### 4.2 Route Handlers

Route Handlers exist only when an HTTP endpoint is genuinely required:

- session-related HTTP endpoints required by the selected Supabase Auth integration;
- document upload or download transfer endpoints when direct Server Action handling is unsuitable;
- liveness/readiness health checks;
- authenticated machine-to-machine callbacks.

The normal login form calls the Supabase SSR authentication integration through its standard server mutation. The application does not create a custom login Route Handler merely because Route Handlers are available.

Health endpoints disclose dependency status, version, and correlation ID only. They do not disclose configuration, schema, user data, or credentials.

### 4.3 Data-access layer

The DAL is server-only and is the sole application module permitted to query operational tables. It contains:

- `requireSession`, `requireProfile`, and role/permission assertions;
- role-scoped query functions with explicit selected columns;
- commands that call controlled database functions;
- generated Supabase database types;
- mapping from database rows to presentation-oriented view models;
- typed pagination, filtering, sorting, and error translation.

Server Components call read functions; Server Actions and Route Handlers call command functions. UI components never contain raw table queries.

Read queries use the authenticated user's Supabase client so RLS remains active. The narrow exception is Operations Vehicle master-data reads: role-gated security-definer read functions independently verify the active Admin/Dispatcher actor and return operation-specific columns so the broader Operations projection does not widen Driver C2 table-column access. The service-role client is created only in explicitly marked server-only modules for Auth administration, trusted scheduler/Edge Function work, and narrowly defined compensating Storage cleanup. It is not the default DAL client.

### 4.4 Controlled database functions

The controlled PostgreSQL function inventory is:

- Shipment controlled workflows, containing separate narrow pending-creation and initial-assignment functions;
- shipment status-request creation;
- shipment status-request approval or rejection;
- tracking start;
- tracking stop;
- maintenance creation with mileage synchronization.
- Driver operational-status transition.
- Vehicle master-data mutations and operational lifecycle.

Functions validate the authenticated actor or accept only trusted service invocations, use fixed `search_path` handling, expose the minimum executable surface, and receive explicit grants. Direct table mutations that could bypass these workflows are denied.

Expense creation and expense update each execute as one transactional workflow that creates or updates the `expenses` row and creates the required `expense_created` or `expense_updated` activity-log entry atomically. This requirement does not add another named database function to the controlled-function inventory.

Storage object transfer and PostgreSQL metadata creation cannot share one transaction. Section 11 defines the required compensation workflow.

The inventory contains exactly eight categories. The Vehicle category uses separate narrow create, ordinary-edit, mileage, and lifecycle functions rather than a generic mutation RPC. Each derives `auth.uid()`, requires an active Admin, re-reads trusted state, uses a fixed minimal `search_path`, exposes minimum authenticated execution, and commits its mutation and one approved activity atomically. Dispatcher mutation calls are rejected independently. No service-role application path is used.

## 5. Authentication and Admin-created accounts

Supabase Auth stores credentials and sessions. `profiles.id` remains the matching `auth.users.id`; `profiles.username` remains the authoritative user-facing identifier. No email field is added to `profiles`.

### Username authentication mapping

**Architecture decision:** A single server-only utility converts a username to an internal Auth email identifier:

1. Normalize the username with the exact behavior used by the database uniqueness rule: trim surrounding whitespace, then apply PostgreSQL-compatible lowercase semantics used by `lower(username)`.
2. Reject blank or invalid normalized usernames before any Auth call.
3. Encode the normalized value into a deterministic email-local-part-safe representation.
4. Append the environment's fixed internal Auth domain.

The same utility is used for account creation, login, administrative credential operations, and server-only verification of a Driver's current password. For Driver self-service verification, the utility derives the identifier only from trusted session-derived application identity/profile data. The browser cannot supply or override the internal email identifier or domain. The internal identifier is never exposed in UI, HTML, React Server Component payloads, URLs, action results, logs, or normal application output.

Staging and production must configure different fixed internal Auth domains. Changing a domain after accounts exist requires an explicit credential migration and is not a routine deployment operation.

### Account creation

Only an active Admin can create Dispatcher and Driver accounts. The account workflow:

1. Revalidates the Admin session and permission.
2. Validates full name, username, initial password, and allowed role.
3. Confirms normalized `profiles.username` availability.
4. Derives the internal Auth identifier server-side.
5. Creates the Supabase Auth user with the server-only Admin API and marks the internal identifier confirmed. If Auth creation fails, the workflow stops and creates no database rows.
6. Creates the matching `profiles` row and, for a Driver account, the related `drivers` row inside one database transaction.
7. If that database transaction fails, rolls it back and deletes the newly created Auth user as compensation.

Account creation never logs passwords. The initial password is returned only through the immediate Admin interaction that supplied it; it is not stored in an application table.

### Login and session lifecycle

Login validates username/password input, derives the Auth identifier server-side, and calls Supabase password sign-in. Authentication failure always returns a generic invalid-credentials response to prevent username enumeration. Rate limiting applies per source and normalized username without logging the username itself in plaintext security telemetry.

The SSR integration reads and refreshes Supabase sessions through secure, HTTP-only cookies. Production cookies use `Secure`, `SameSite=Lax`, and the narrowest viable path/domain. A deactivated profile is denied even when its Auth session remains technically valid, and the server signs it out at the next request.

Only Admin can perform an administrative credential reset for another user, deactivate an account, or reactivate it. Administrative deactivation and reactivation change application lifecycle state only and do not delete, ban, disable, recreate, or enable the Supabase Auth user. V1 does not guarantee immediate destruction of the target's existing Supabase access or refresh tokens. Every protected layout, Server Component, Server Action, Route Handler, DAL command, controlled function, RLS policy, and Storage policy must continue to require the applicable active-profile state, so possession of a valid JWT alone never authorizes application access. Administrative password reset uses the supported Auth Admin password-update operation for future authentication and adds no custom session-revocation mechanism. Users cannot change roles. V1 has no public registration, public password reset, email verification workflow, email-based recovery, username recovery, or security questions.

### Driver self-service password change

`/driver/settings` contains exactly one V1 capability: an authenticated active Driver changing only their own Supabase Auth password. This self-service workflow is distinct from Admin administrative credential reset and grants no broader account-management authority.

The Server Action workflow:

1. Revalidates the authenticated session.
2. Requires an existing active application profile with role `driver` and the corresponding Driver integrity expected by the authenticated Driver boundary.
3. Validates Current password, New password, and Confirm new password, requiring the new password and confirmation to match.
4. Derives the internal Auth identifier exclusively from trusted session-derived identity/profile data.
5. Applies the dedicated password-change verification rate-limit boundary before credential verification.
6. Verifies the current password in a server-only isolated Supabase Auth context that neither replaces nor persists into the Driver's application session.
7. Requires the verified Supabase Auth user identity to match the authenticated session-derived user.
8. Changes only that authenticated user's password through the ordinary authenticated Supabase Auth client. The configured Supabase Auth password policy remains authoritative; the application does not define a competing password-strength policy.
9. Preserves the current authenticated application session after success, does not redirect to login, does not revoke other sessions, and returns only safe success/error data.

Current-password verification uses a dedicated limiter independent from the login limiter and does not consume login counters or rely solely on Supabase endpoint limits. Its independent password-change namespace limits incorrect current-password verifications to three per authenticated user per 15 minutes and ten per trusted network/source dimension per 15 minutes. Actor identity comes from the authenticated server-side context, network/source identity uses the established trusted server-side source derivation, and browser-supplied identity is never authoritative. Validation failures before credential verification and infrastructure failures do not increment either counter; an incorrect current password increments both. A successful complete password change clears only the user-specific password-change failure state and does not clear the shared source/network abuse counter. The response never reveals which threshold was reached and uses a safe generic rate-limit error.

This workflow does not use the Supabase Admin API or service role, broaden `profiles` or `drivers` mutation permissions, mutate Driver Profile or application data, or trust browser-supplied ownership. It never exposes Auth user objects, sessions, tokens, or internal identifiers and never persists or logs current passwords, new passwords, or application password hashes. It introduces no public or email-based password recovery, username recovery, security questions, sign-out-after-change behavior, or global session revocation. The existing Server Action security/error contract and Admin administrative credential-reset workflow remain unchanged.

## 6. Roles and permission architecture

| Capability | Admin | Dispatcher | Driver |
| --- | --- | --- | --- |
| Manage accounts, roles, and critical settings | Full | Denied | Denied |
| Change own Auth password | Not an Admin self-service workflow | Denied | Own account only after current-password verification |
| Manage drivers and vehicles | Full | Read operational data | Assigned-context read only |
| Manage clients | Full | Create/edit/archive/reactivate | Denied |
| Create/edit/cancel shipments | Full | Full operational access | Denied |
| Assign driver and vehicle | Full | Allowed | Denied |
| Request shipment status change | Denied as Driver workflow | Denied as Driver workflow | Assigned shipment; next transition only |
| Approve/reject status requests | Allowed | Allowed | Denied |
| Shipment-level expenses and profit | Full | Read/create/edit for individual shipments | Denied |
| Company-wide finance and reports | Full | Denied | Denied |
| Maintenance management | Full | Read | Assigned-vehicle read only |
| Document management | Full | Operational upload/read/archive | Permitted assigned-context upload/read |
| Send operational messages | Allowed | Allowed | Denied |
| Read/acknowledge Driver messages | Not recipient workflow | Not recipient workflow | Own messages only |
| Notifications and alerts | All relevant data | Operational data | Own relevant notifications only |
| Live tracking | All active shipments | All active shipments | Own assigned active shipment only |
| Activity history | Full | Relevant operational history | Own assignment history presented by the Driver UI |

Admin inherits every Dispatcher operational capability. Dispatcher access to finance is limited exactly as defined by the PRD. Driver access is derived through the authenticated profile's unique `drivers.profile_id` relationship and current/historical shipment assignment; a request cannot select a different Driver identity.

Authorization is enforced in six layers:

1. protected layout redirects for user experience;
2. permission checks inside server-only DAL entry points;
3. repeated checks in every Server Action and Route Handler;
4. controlled database-function validation and grants;
5. table RLS and Realtime row visibility;
6. Storage object policies and server-side document authorization.

## 7. Desktop and mobile experiences

### Admin and Dispatcher

The operations shell is desktop-first and tablet-capable. It uses a full desktop sidebar, a collapsed tablet sidebar, and a mobile drawer. Dense lists use server-side pagination/filtering and horizontally scrollable tables on narrow screens. Dashboard modules share a visual system but receive role-filtered data: company-wide financial KPIs are Admin-only.

Shipment, client, driver, vehicle, maintenance, document, expense, report, alert, notification, tracking, and activity screens stay within the PRD scope. The application does not invent large Driver detail workflows or CRM behavior.

### Driver

The Driver shell is mobile-first and remains usable on desktop. Its primary view centers the current assignment, route endpoints, assigned vehicle, shipment state, next permitted request, POD/documents, unread messages, and relevant notifications. Execution buttons meet touch-target requirements and display an explicit confirmation before a status request or document submission.

The Driver interface never exposes company-wide navigation, other drivers, unassigned shipments, commercial/financial data, account administration, or a message-reply control. All tracking screens label location data as simulated.

## 8. Validation and data-access strategy

Validation has three complementary layers:

- Zod schemas validate environment variables, forms, Server Action arguments, Route Handler bodies, query parameters, file intent, and completion payloads.
- Domain services validate role permissions and business rules that can be checked before the database call.
- PostgreSQL constraints, unique indexes, RLS, locks, and controlled functions remain authoritative for integrity and concurrency.

Canonical constants mirror database enums and approved text values, including `proof_of_delivery`, expense categories, status transitions, document thresholds, and alert thresholds. Generated database types are regenerated when approved schema migrations change the database; application code does not redefine the schema independently.

Derived values remain derived:

- unread state is `read_at IS NULL`;
- shipment expenses are summed from `expenses`;
- profit is shipment price minus summed expenses;
- document expiry state comes from lifecycle and validity dates;
- client history comes from shipments;
- `in_use` and active assignment behavior follow the database workflows.

List reads use bounded page sizes and indexed filters named in `DATABASE.md`. Search input is trimmed, length-limited, and passed through parameterized Supabase queries; SQL strings are never assembled from browser input.

## 9. Transactional workflow boundaries

The following operations are single controlled database transactions, matching `DATABASE.md`:

- pending-Shipment creation;
- shipment assignment;
- status-request approval or rejection;
- maintenance creation and permitted mileage increase;
- tracking start;
- tracking stop;
- individual overlap-safe simulation steps.

Each transaction revalidates current database state rather than trusting a preceding UI read. Activity logs and notifications required by a workflow are created inside the same transaction. A transaction failure exposes no partial business state.

Document upload is the defined exception: Storage transfer and metadata insertion use a staged workflow plus compensation because they cannot be one PostgreSQL transaction.

Normal CRUD mutations that affect one entity still run through authorized DAL commands and retain/archive records according to `DATABASE.md`. No application workflow bypasses database constraints to simplify UI behavior.

Client mutations use authenticated RLS-scoped table access plus non-callable, security-hardened database triggers. The Client row is the lifecycle serialization point: archive locks and revalidates that row before checking for nonterminal shipments and changing status, while future shipment creation must lock and revalidate the same row and require it to remain active before inserting. Client mutation triggers create exactly one approved activity row for each successful logical create, real business-field edit, archive, or reactivation; failed and no-op mutations create none. This trigger boundary does not add a callable PostgreSQL function category to the controlled-function inventory, and the Client-management phase does not implement shipment creation.

Operations Driver Master Data uses authenticated RLS-scoped reads and a narrow Admin-only phone update. Phone normalization and protected-column enforcement remain database-backed, while `updated_at` is the optimistic concurrency token and its existing database trigger remains authoritative. Driver operational-state changes use the seventh approved controlled-function category: **Driver operational-status transition**. The function accepts only the named `mark_off_duty`, `mark_available`, `archive`, and `reactivate` operations, derives and verifies an active Admin actor, locks the target profile before the Driver and blocking Shipment rows, enforces the approved transition matrix and active-profile rule, then changes only Driver status and creates exactly one `driver_status_changed` activity atomically. It never uses service role or changes profile, Shipment, Vehicle, notification, or alert state.

Future Shipment assignment must use the same profile-to-Driver serialization order and revalidate profile activity, `drivers.status = 'available'`, and absence of a Shipment in `assigned`, `loading`, or `in_transit`. Driver documents are not part of this eligibility contract.

Operations Vehicle Master Data uses three narrow role-gated read functions for list, distinct type options, and Admin edit-safe reads; existing Driver Vehicle grants and RLS remain unchanged. Vehicle lifecycle locks the Vehicle, revalidates it, then locks/checks blocking Shipments before changing status and recording activity. Mileage locks only the Vehicle and revalidates its optimistic version and current mileage. Future maintenance orders Vehicle before maintenance record. The global relative lock order is Client, Driver profile, Driver, Vehicle, Shipment, Shipment Status Request, Document, Vehicle Location, then Alert; workflows omit irrelevant rows without reversing this order. Tracking history, activity, and notification rows are append-only effects after mutable-row revalidation. The existing partial active-Vehicle Shipment index remains the assignment concurrency backstop.

## 10. Shipment assignment and status requests

### Assignment

The Admin or Dispatcher selects a pending shipment, available active Driver, and available vehicle. The controlled assignment function:

Creation and assignment are separate narrow callable functions inside the same existing Shipment controlled-workflow category; the controlled-function category inventory remains exactly eight. Assignment performs an initial non-locking Shipment read only to resolve `client_id`, then locks Client, Driver profile, Driver, Vehicle, and Shipment. The Shipment lock is last, after which the function revalidates existence, unchanged Client, pending status, and null assignments before any mutation.

1. Locks and revalidates the shipment.
2. Confirms the client is active.
3. Confirms the Driver, Driver profile, and vehicle satisfy the database availability rules.
4. Assigns Driver and vehicle and changes shipment status to `assigned`.
5. Synchronizes Driver and vehicle operational states.
6. Creates the shipment activity record and assignment notification.

The active-assignment partial unique indexes are the concurrency backstop. A uniqueness conflict is translated to a specific Driver- or vehicle-unavailable business error after querying the conflicting active shipment that the actor is authorized to view.

Tracking numbers are generated by server-side business logic in the format defined by `PRD.md`. Uniqueness is enforced by `DATABASE.md`.

### Driver status request

Only the assigned Driver can request the next transition in `assigned -> loading -> in_transit -> delivered`. The Driver cannot directly update `shipments.status`. Creation rejects an out-of-order transition and prevents a duplicate pending request using the database rules.

The official status remains unchanged while a request is pending. The request transaction creates the request, Dispatcher/Admin notification, and corresponding activity record defined by `DATABASE.md`.

### Approval or rejection

An Admin or Dispatcher resolution command locks both request and shipment and revalidates:

- the request is pending;
- recorded current status equals actual shipment status;
- the requested transition is the next allowed transition;
- the shipment still belongs to the requesting Driver;
- an active `proof_of_delivery` document exists before approving `delivered`.

Approval updates the shipment and request, synchronizes or releases Driver/vehicle state, starts tracking upon entering `in_transit`, stops tracking upon leaving it, and creates the database-defined notifications and activity records. Rejection resolves only the request, preserves shipment state, records the optional reason, and creates the rejection notification/activity. Resolved and stale requests cannot be resolved again.

S2 uses separate narrow creation, approval, and rejection functions in the existing Shipment controlled-workflow category. Stale pending requests cannot be approved but may be manually rejected by an active Admin or Dispatcher; no unrelated workflow automatically resolves them. Creation uses the existing `status_approval_requested` notification type, approval uses `status_approved`, and rejection uses `status_rejected`; the activity types remain the corresponding `status_request_*` values.

Entering `in_transit` atomically initializes current and historical tracking with the trusted simulation seed latitude `45.2671`, longitude `19.8335`, heading `0`, speed `0`, and route progress `0`. It is not derived from addresses and is never represented as real GPS accuracy. S2 implements no simulator movement, scheduling, or Realtime behavior. Delivery locks one deterministic active Shipment POD, releases the Driver and Vehicle to `available`, forces `delayed=false`, snapshots and removes current tracking when present, resolves the matching active stale-location alert, and preserves tracking history.

Cancellation is an Admin/Dispatcher workflow using the database-defined cancellation responsibilities. It releases active resources, stops tracking, and retains shipment history.

## 11. Proof of Delivery and document Storage

### Storage organization

**Architecture decision:** V1 uses one private bucket named by `SUPABASE_DOCUMENTS_BUCKET`. Objects use immutable, non-guessable paths:

```text
{owner-type}/{owner-uuid}/{document-uuid}/{sanitized-file-name}
```

`owner-type` is `shipment`, `vehicle`, or `driver`. The generated document UUID is also used for the intended metadata identity; paths are never overwritten. Replacement uploads create a new object/metadata row and archive the old document according to `DATABASE.md`.

**Architecture decision:** Bucket configuration enforces a 20 MiB V1 maximum and the allowlist `application/pdf`, `image/jpeg`, and `image/png`. The server verifies extension, declared MIME type, Storage-reported content type, and object size. File names are sanitized for display and path safety. The object path—not a public or signed URL—is stored in `documents.file_path`.

### Direct upload workflow

1. An authenticated Server Action validates owner, document type, file name, MIME type, size, role, and ownership context.
2. The server generates the immutable path and issues a short-lived, single-object upload authorization.
3. The browser uploads bytes directly to the private Supabase Storage bucket and cannot choose a different authorized path.
4. A completion Server Action revalidates the session, permission, declared metadata, and ownership and inspects the stored object's path, size, and MIME metadata.
5. One database metadata transaction atomically creates the document row, every notification required by `DATABASE.md` for that operation, every activity entry required by `DATABASE.md` for that operation, and alert side effects only when `DATABASE.md` explicitly requires them in the same workflow.
6. The Storage upload remains outside that database transaction. If validation or the metadata transaction fails after upload, the server deletes that exact newly uploaded object as compensation and records a structured operational failure.
7. Uncompleted upload authorizations expire. A scheduled cleanup removes abandoned authorized objects after 24 hours based on Storage object metadata without adding an application table.

**Architecture decision:** Download requests first authorize access to the `documents` row, then issue a signed URL valid for five minutes. Signed URLs are never persisted or logged.

### POD workflow

The assigned Driver can upload a POD only for their assigned shipment. The intent forces canonical `document_type = 'proof_of_delivery'`; user input cannot select a different owner or uploader identity. Successful completion creates an active shipment document and `document_uploaded` activity.

POD metadata completion does not change shipment status and does not approve delivery. The Driver separately requests `delivered`; the approval transaction independently verifies an active, non-archived POD belonging to the shipment.

## 12. Simulated vehicle tracking

Tracking exists only while `shipments.status = 'in_transit'`. The trusted simulator updates latitude, longitude, speed in km/h, heading in degrees, route progress as a percentage, and database-controlled `updated_at`. Browsers never submit tracking coordinates or progress.

Tracking start validates the shipment/vehicle relationship, upserts the initial `vehicle_locations` row, writes the initial `tracking_history` snapshot, and records `tracking_started`. Tracking stop writes a final history snapshot only when a current row exists, deletes `vehicle_locations`, resolves the active stale-location alert, and records `tracking_stopped`.

### Ten-second scheduler

Supabase Cron invokes one authenticated tracking Edge Function every 10 seconds. The Supabase project must run a PostgreSQL/`pg_cron` version that supports second-based schedules. Staging and production deployment verification must confirm that the exact 10-second expression is accepted, fires at the required cadence, authenticates successfully, and executes reliably under representative active-shipment load.

The Cron caller stores its invocation secret in Supabase Vault and sends it only to the Edge Function. The function rejects missing or invalid authentication before accessing data.

A dedicated external scheduler is permitted only as an operational fallback when the selected environment cannot reliably execute the required 10-second schedule. It invokes the same authenticated Edge Function with the same cadence and contract. It does not change Next.js, Edge Function, database, tracking, or Realtime architecture.

### Batching and overlap safety

**Architecture decision:** Each invocation processes at most 50 active `in_transit` shipments in a deterministic database order. The function delegates each shipment step to a controlled database function and isolates each call so one shipment failure does not roll back or stop the remaining batch.

The database step takes a transaction-scoped advisory lock derived from the shipment ID. When the lock is unavailable, that shipment is skipped for the current invocation. After acquiring it, the function locks/reloads the shipment and current location, revalidates `in_transit` and the assigned vehicle, and calculates progress from trusted database time and the previous persisted update. The update uses a compare-and-update condition against the previously read `updated_at`; a lost comparison is a benign concurrent skip. Route progress is clamped to `[0,100]` and can never decrease.

The calculation advances by elapsed trusted time, not by invocation count. Duplicate delivery, delayed execution, and overlapping invocations therefore cannot double-advance a shipment. A shipment failure produces a structured log with correlation ID, invocation ID, shipment ID, error category, and safe diagnostic fields; processing continues with the next shipment. Secrets, coordinates tied to personal identity, and unrestricted payloads are not logged.

An invocation reports processed, skipped, and failed counts. It returns a failure status only for invocation-wide authentication or infrastructure failure; individual shipment failures are reported in structured output and observability telemetry.

## 13. Realtime and tracking history

Only `vehicle_locations` is added to the `supabase_realtime` publication in V1. Postgres Changes is the chosen V1 mechanism because the table is a small mutable current-state table and the expected single-company fleet is bounded.

**Architecture decision:** The tracking Client Component uses the following recovery behavior:

1. receives an authorized initial snapshot from its Server Component;
2. subscribes to filtered `INSERT`, `UPDATE`, and `DELETE` events for the permitted vehicle or shipment;
3. updates the MapLibre marker and presentation state;
4. treats `DELETE` as tracking stopped;
5. on reconnect, refetches the authoritative current row before resubscribing;
6. falls back to a 30-second authorized refresh while Realtime is disconnected.

RLS controls which `vehicle_locations` rows a subscriber can receive. Admin and Dispatcher can view active fleet rows; a Driver can view only the current row for their assigned shipment/vehicle. Realtime is read-only to browser users.

### History cadence

The history cadence is fixed:

- one initial snapshot at tracking start;
- one snapshot every 60 seconds while the vehicle is moving;
- one final snapshot at tracking stop when a current location exists.

The 10-second simulator updates `vehicle_locations` but does not insert `tracking_history` every invocation. The controlled tracking step writes history only when at least 60 seconds have elapsed since the shipment's latest snapshot and movement has occurred. History uses trusted database time, remains append-only, and is retained indefinitely.

## 14. Alerts, notifications, messages, and activity

### Notifications

Notifications are in-app only and use the types and concrete relationships defined by `DATABASE.md`. Trusted transactions create them. Recipients can update only their own `read_at`; unread counts use `read_at IS NULL`. Server Components load the initial count and focused Client Components refresh it after acknowledgement or navigation invalidation.

### Messages

Admin and Dispatcher can send short one-way operational messages to eligible Drivers. Sender identity comes from the session. Shipment-linked messages target that shipment's assigned Driver. Drivers can read and set `read_at` on their messages but cannot create messages or replies. Message acknowledgements are not activity-log events.

### Alerts

Alerts represent actionable operational conditions and remain separate from notifications. The application uses the thresholds, fixed severity mapping, active-alert uniqueness, recurrence, and resolution behavior from `DATABASE.md`:

- document expiry warning: 30 days;
- maintenance date warning: 14 days;
- maintenance mileage warning: 1,000 km;
- stale vehicle location: 10 minutes.

Jobs and mutation workflows are idempotent: an existing matching active alert is retained, resolved conditions resolve it, and a later recurrence creates a new alert rather than reopening the old row.

### Activity logs

Only trusted transactional workflows create activity rows. Actor identity comes from the session; scheduled system activity uses a null actor. Exactly one primary related entity is supplied as required by `DATABASE.md`. Metadata is minimal and structured. The application never logs page views, searches, filters, read acknowledgements, every tracking update, secrets, signed URLs, credentials, full objects, or sensitive personal data.

## 15. Scheduled operational checks

Supabase Cron invokes authenticated Edge Functions or controlled database functions on these fixed schedules:

| Check | Schedule | Behavior |
| --- | --- | --- |
| Tracking simulation | Every 10 seconds | Process bounded overlap-safe active-shipment batches |
| Stale vehicle location | Every minute | Create/retain/resolve alerts using the 10-minute threshold |
| Document expiry | Daily at 02:00 UTC | Reconcile expiring and expired active documents and associated notifications |
| Maintenance date | Daily at 02:00 UTC | Reconcile due-date alerts using the 14-day threshold |
| Maintenance mileage | After mileage/maintenance mutations and daily at 02:00 UTC | Reconcile due-mileage alerts using the 1,000 km threshold |
| Abandoned Storage objects | Daily at 03:00 UTC | Delete incomplete direct uploads older than 24 hours |

Every scheduled endpoint authenticates the scheduler, generates or propagates a correlation ID, uses bounded batches, and records structured duration/result/failure telemetry. Reconciliation continues after an entity-level failure. The jobs rely only on existing tables, constraints, Storage metadata, and controlled functions; V1 adds no queue or job-state table.

## 16. Errors, authorization, observability, and security

### Error contract

Server mutations return a discriminated result containing success data or a safe error with `category`, `message`, `fieldErrors` when applicable, and `correlationId`.

| Category | Meaning |
| --- | --- |
| `authentication` | Missing, expired, disabled, or invalid session |
| `authorization` | Authenticated actor lacks the permission or row access |
| `validation` | Input, file, or query validation failed |
| `not_found` | Authorized lookup found no current entity |
| `conflict` | Concurrent change or unique/active-assignment collision |
| `business_rule` | Invalid workflow transition or required condition absent |
| `storage` | Upload, verification, signing, or compensation failure |
| `infrastructure` | Database, network, Realtime, scheduler, or unknown dependency failure |

Expected validation and business errors are displayed near the initiating control. Route error boundaries handle unexpected read/render failures. Authentication redirects to login; authorization produces a safe forbidden experience; not-found responses do not reveal whether an inaccessible record exists.

### Observability

Every request, action, Route Handler, Edge Function invocation, and scheduled run receives a correlation ID. Structured server logs contain operation name, actor profile ID only when safe, role, primary entity ID, duration, outcome, error category, and correlation ID. Production captures unhandled exceptions and performance telemetry through the configured observability provider.

Logs never contain passwords, Auth tokens, cookies, service-role keys, internal Auth email identifiers, signed URLs, complete document paths exposed to unauthorized contexts, arbitrary request bodies, or full database rows. Operational activity logs remain business audit records; infrastructure logs are not written into `activity_logs`.

### Database and API security

- Enable RLS on every application table exposed through the Supabase Data API or Realtime.
- Explicitly control table grants and function execution permissions by `anon`, `authenticated`, and service roles.
- Revoke default function execution and grant only the controlled functions required by each role.
- Keep internal-only database objects outside exposed schemas or revoke Data API access so they cannot be unintentionally queried.
- Complete RLS and Storage policy SQL remains implementation work and must be tested before deployment.
- Use invoker-context reads by default; security-definer functions use fixed search paths, explicit authorization, and minimum grants.
- Derive actor and recipient identity from the authenticated session, never browser fields.
- Keep service-role and scheduler secrets server-only and rotate them through the deployment secret manager and Supabase Vault.
- Apply rate limits to login, upload authorization/completion, status requests, message sending, and signed-download generation.
- Validate mutation origins through secure same-site cookies and the protections supplied by Next.js Server Actions; machine endpoints require explicit bearer authentication.
- Set security headers for content type, framing, referrer policy, and a Content Security Policy covering only the application, Supabase, and configured map resources.

## 17. Suggested project folder structure

```text
proxy.ts                     # Supabase SSR refresh and cookie propagation boundary
app/
  (auth)/login/
  (operations)/
    layout.tsx
    dashboard/
    shipments/
    drivers/
    vehicles/
    clients/
    maintenance/
    documents/
    expenses/
    reports/
    tracking/
    messages/
    notifications/
    alerts/
    activity/
    settings/
  (driver)/
    layout.tsx
    dashboard/
    shipments/
    vehicle/
    messages/
    documents/
    profile/
    settings/
  api/
    auth/
      route.ts               # Only when required by the selected Supabase SSR integration
    documents/
      route.ts               # HTTP transfers used only when Server Actions are unsuitable
    health/
      route.ts
    callbacks/
      route.ts               # Authenticated machine-to-machine callbacks
  error.tsx
  global-error.tsx
  layout.tsx
components/
  ui/
  operations/
  driver/
  maps/
features/
  auth/
  accounts/
  shipments/
  drivers/
  vehicles/
  clients/
  maintenance/
  documents/
  expenses/
  tracking/
  messaging/
  notifications/
  alerts/
  activity/
  reports/
lib/
  actions/                # Thin server mutation entry points
  auth/                   # Session, permissions, username-to-Auth mapping
  dal/                    # Role-scoped queries and commands
  domain/                 # Workflow orchestration and error contracts
  validation/             # Zod schemas
  supabase/               # Browser, server, admin, and middleware/proxy clients
  observability/
  constants/
  env.ts
types/
  database.generated.ts
  domain.ts
shared/
  runtime/
    constants.ts             # Runtime-safe constants shared by Next.js and Edge Functions
    types.ts                 # Runtime-safe contracts shared by Next.js and Edge Functions
supabase/
  functions/
    simulate-tracking/
    reconcile-operational-alerts/
    cleanup-document-uploads/
  migrations/             # Schema implementation remains governed by DATABASE.md
tests/
  unit/
  integration/
  e2e/
```

Feature folders contain feature-specific schemas, view models, and UI composition. Shared security, DAL, Supabase clients, and error contracts remain in `lib` to prevent feature-specific authorization drift.

## 18. Environment variables and deployment boundaries

| Variable | Exposure | Purpose |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | Browser and server | Environment-specific Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Browser and server | Public client key used with RLS |
| `SUPABASE_SERVICE_ROLE_KEY` | Server only | Auth administration and narrowly trusted operations |
| `AUTH_INTERNAL_DOMAIN` | Server only | Fixed environment-specific username mapping domain |
| `SUPABASE_DOCUMENTS_BUCKET` | Server and authorized upload UI | Private bucket name |
| `NEXT_PUBLIC_MAP_STYLE_URL` | Browser | MapLibre style endpoint |
| `NEXT_PUBLIC_APP_URL` | Browser and server | Canonical deployment URL |
| `SCHEDULER_SHARED_SECRET` | Edge Functions/Cron only | Authenticates scheduled invocations |
| `OBSERVABILITY_DSN` | Server only | Server/Edge Function error telemetry |
| `NEXT_PUBLIC_OBSERVABILITY_DSN` | Browser | Sanitized browser error telemetry configuration |
| `CORRELATION_ID_HEADER` | Server and Edge Functions | Fixed inbound/outbound correlation header name |

Environment variables are validated at process/function startup. Only variables prefixed `NEXT_PUBLIC_` enter browser bundles. Secrets live in the hosting platform's secret manager or Supabase Vault and are never committed.

The Next.js runtime handles user-facing requests and never runs background tracking loops. Supabase Edge Functions handle scheduled workloads close to PostgreSQL. Database migrations, grants, RLS policies, Storage policies, Realtime publication configuration, Cron definitions, Vault secrets, Edge Function deployments, and Auth settings are versioned deployment infrastructure even though this document does not contain their full SQL.

Production deployment gates require:

- successful schema/grant/RLS/Storage-policy deployment against the environment;
- verification that public registration and public password recovery are disabled;
- confirmation that internal-only objects are not exposed through the Data API;
- acceptance and reliable execution of the 10-second `pg_cron` expression;
- authenticated Edge Function smoke tests;
- direct upload, compensation, and signed-download tests;
- Realtime visibility tests for all three roles;
- rollback instructions for the Next.js and Edge Function releases.

## 19. Testing and acceptance strategy

### Unit tests

- Username normalization and deterministic Auth mapping match database case-insensitive uniqueness behavior.
- Permission matrix and role assertions cover every capability.
- Zod schemas reject malformed forms, filters, uploads, and environment configuration.
- Transition helpers permit only the approved next statuses.
- Error translation maps database and Storage failures without leaking internals.
- Tracking calculation uses elapsed time, clamps progress, and never decreases it.

### Database and integration tests

- Concurrent assignment attempts cannot double-assign a Driver or vehicle.
- Status requests reject incorrect Driver, duplicate/stale requests, and invalid transitions.
- Delivery approval fails without active POD and succeeds after separately completed POD metadata.
- Approval/cancellation synchronizes resources, notifications, activity, and tracking atomically.
- Direct uploads are authorized to one exact object; failed metadata creation deletes that object.
- RLS and grants enforce Admin, Dispatcher, and Driver visibility and mutation boundaries.
- Internal objects and privileged functions are inaccessible through public Data API roles.
- Overlapping simulator calls skip or serialize the same shipment and never double-advance progress.
- A failed simulated shipment does not prevent other batch items from completing.
- History appears at start, at 60-second moving intervals, and at stop—not every 10 seconds.
- Alert reconciliation is idempotent and uses the authoritative thresholds and severity mapping.

### End-to-end tests

- Admin creates, resets, deactivates, and reactivates Dispatcher and Driver accounts; no public sign-up exists.
- Each role sees only its intended shell, navigation, data, actions, and finance scope.
- Dispatcher assigns a shipment; Driver requests each status; Dispatcher approves/rejects correctly.
- Driver uploads POD directly and cannot complete delivery through upload alone.
- Driver reads and acknowledges messages but has no reply path.
- Tracking is visibly labeled simulated, updates through Realtime, reconnects correctly, and stops on delivery.
- Desktop operations tables and the mobile Driver workflow meet responsive and keyboard/touch accessibility requirements.

### Operational verification

- Staging and production accept and reliably execute the 10-second Cron schedule.
- Scheduler authentication failures, overlap skips, batch counts, and per-shipment failures are observable by correlation ID.
- Health checks report safe dependency state.
- Secrets and internal Auth identifiers do not appear in browser bundles, responses, logs, or activity metadata.
- Backup, migration, and deployment rollback procedures are exercised before production launch.

## 20. Implementation order

1. **Platform foundations:** Install pinned dependencies, enable strict TypeScript, add environment validation, generated database types, Supabase clients, error contracts, correlation IDs, and baseline testing.
2. **Database security and functions:** Implement the approved schema from `DATABASE.md`, indexes, controlled functions, grants, RLS, Storage policies, and Realtime publication without schema additions.
3. **Authentication and accounts:** Add SSR sessions, centralized username mapping, login, Admin provisioning, reset, deactivation/reactivation, and permission assertions.
4. **Role shells:** Build protected operations and Driver layouts, responsive navigation, shared design primitives, and route-level error/loading states.
5. **Master data:** Implement authorized clients, drivers, vehicles, maintenance, and archival workflows.
6. **Shipment core:** Implement shipment lists/details, generation, creation/editing/cancellation, transactional assignment, status requests, approval/rejection, expenses, and derived profit.
7. **Documents and POD:** Configure the private bucket, direct upload authorization/completion, compensation, downloads, document management, and POD delivery gate.
8. **Operational communication:** Implement one-way messages, notifications/unread counts, alerts, activity timelines, and role-scoped dashboards.
9. **Tracking:** Deploy tracking start/stop functions, overlap-safe simulator, 10-second Cron, 60-second history cadence, MapLibre UI, and `vehicle_locations` Realtime subscriptions.
10. **Reports and scheduled checks:** Complete authorized reports, expiry/maintenance/stale reconciliation, and abandoned-upload cleanup.
11. **Production hardening:** Run authorization, concurrency, responsive, accessibility, performance, observability, scheduler, backup, and deployment-gate verification in staging before production promotion.

## 21. Explicit V1 boundaries

This architecture does not introduce multi-company or SaaS tenancy, public registration, user-selected Auth email addresses, Driver replies, email notifications, push notifications, SMS, real GPS hardware, route optimization, customer portals, new application tables or fields, queues, full SQL migrations, or complete RLS policy SQL. These concepts do not influence V1 implementation boundaries.
