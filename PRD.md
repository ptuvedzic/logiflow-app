# LogiFlow Product Requirements Document (PRD)

**Version:** 1.0  
**Status:** Approved  
**Product Type:** Internal logistics and fleet management web application  
**Primary Stack:** Next.js, TypeScript, Tailwind CSS, Supabase  
**Primary Users:** Admin, Dispatcher, Driver  

## 1. Product Overview

LogiFlow is an internal logistics and fleet management application built for a single transport company.

The system centralizes the company's operational workflow around shipments, drivers, vehicles, clients, maintenance, documents, expenses, reports, notifications, and simulated real-time vehicle tracking.

LogiFlow is not a public SaaS product in V1. All users belong to the same company, and all operational data exists within one company environment.

The product should feel like a realistic internal enterprise tool rather than a generic CRUD dashboard.

## 2. Product Goals

1. Allow administrators to manage company users, drivers, vehicles, clients, maintenance, documents, and reporting.
2. Allow dispatchers to create and manage shipments, assign available drivers and vehicles, monitor delivery progress, approve driver status-change requests, and send short operational messages to drivers.
3. Allow drivers to view their assignments, request shipment status changes, view assigned vehicle information, read dispatcher messages, and upload shipment documents such as Proof of Delivery.
4. Prevent invalid operational states, such as assigning one driver or one vehicle to multiple active shipments.
5. Provide a realistic simulated live-tracking experience for active shipments.
6. Preserve important operational history instead of permanently deleting records.
7. Provide realistic reports, activity logs, alerts, notifications, and financial summaries.
8. Deliver a polished, portfolio-ready application that demonstrates full-stack engineering skills and realistic business logic.

## 3. Non-Goals / Out of Scope for V1

The following features must not be implemented in V1 unless explicitly added later:

- Real GPS hardware integration
- Automatic route optimization
- SMS notifications
- Email notifications
- Advanced invoicing
- Accounting integration
- Multi-company / multi-tenant SaaS architecture
- Native mobile application
- Customer portal
- AI features
- Real payment processing
- Two-way driver/dispatcher chat
- Full CRM functionality
- Real telematics hardware integration

These may be listed as future improvements but must not unnecessarily influence the V1 architecture.

## 4. User Roles

### 4.1 Admin

The Admin has full access to the system.

The Admin can:

- Access the admin dashboard
- Create Dispatcher accounts
- Create Driver accounts
- Assign usernames and passwords
- Manage users
- Create, edit, archive, and view drivers
- Create, edit, archive, and view vehicles
- Create, edit, archive, and view clients
- Create, edit, cancel, and view shipments
- Assign drivers and vehicles to shipments
- View and manage maintenance
- View and manage documents
- View and manage expenses
- View reports
- View notifications and alerts
- View activity history
- Manage application settings
- Access all operational data

The Admin may perform any action available to a Dispatcher.

### 4.2 Dispatcher

The Dispatcher manages day-to-day logistics operations.

The Dispatcher can:

- Access the dispatcher dashboard
- Create shipments
- Edit shipment operational data
- Assign available drivers
- Assign available vehicles
- View all shipments
- Search and filter shipments
- View drivers
- View vehicles
- View clients
- Manage client records
- Monitor active shipments
- View simulated live tracking
- Receive driver status-change requests
- Approve or reject driver status-change requests
- Send one-way operational messages to drivers
- View alerts
- View operational notifications
- View relevant shipment activity history

The Dispatcher cannot:

- Create or manage user accounts
- Access critical administrative settings
- Change user roles
- Access unrestricted administrative controls

Dispatchers may access shipment-level financial data only. They may view shipment price, shipment expenses, add shipment expenses, edit shipment expenses, view total shipment expenses, and view calculated shipment profit for individual shipments. Supported expense categories are Fuel, Toll, Driver, Maintenance, and Other. Dispatchers may not access company-wide financial reports, total company revenue or profit, financial settings, or unrelated company financial information. Admins retain full financial and reporting access.

### 4.3 Driver

The Driver has a simplified role-specific experience.

The Driver can access:

- Dashboard
- Profile
- My Shipments
- Assigned Vehicle
- Messages
- Documents
- Settings
- Logout

The Driver can:

- View only shipments assigned to them
- View their current assignment
- View pickup and delivery information
- View the assigned vehicle
- Request shipment status changes
- Read messages sent by Dispatchers
- Mark messages as read
- Upload permitted shipment documents
- Upload Proof of Delivery
- View approved shipment status changes
- Change their own password from Driver Settings

The Driver cannot:

- View other drivers
- View all company shipments
- Assign vehicles
- Assign drivers
- Change shipment commercial data
- View company-wide financial data
- Approve their own status-change requests
- Manage other users
- Access administrative areas

## 5. Authentication and User Provisioning

LogiFlow has no public registration page.

All Dispatcher and Driver accounts are created by an Admin.

When creating an account, the Admin provides:

- Full name
- Username
- Initial password
- Role

Admins may create accounts, assign roles, perform administrative credential resets, and deactivate accounts. Dispatchers and Drivers log in using username and password. An authenticated active Driver may separately change only their own password through the Driver Settings self-service workflow defined below. There is no public sign-up and no email-based password reset in V1. Users cannot change their own role.

For V1, `profiles.is_active` is the application account-lifecycle authority. Administrative deactivation and reactivation do not delete, ban, disable, recreate, or enable the Supabase Auth user and do not guarantee immediate destruction of existing Supabase access or refresh tokens. Every protected application boundary must require an existing active profile in addition to a valid authenticated session, so an inactive account cannot access LogiFlow even while an issued token remains cryptographically valid. Administrative password reset replaces the Supabase Auth password for future authentication and adds no custom session-revocation mechanism.

The application may use Supabase Auth internally while presenting a username/password login interface to users. The technical implementation of username-based authentication with Supabase Auth will be defined later in the architecture document.

All protected routes must verify both:

1. Authenticated session
2. User role / authorization

UI hiding alone is not sufficient authorization.

### 5.1 Driver Settings

The canonical Driver Settings route is `/driver/settings`.

Driver Settings contains exactly one V1 self-service capability: **Change Password**. The UI requires:

- Current password
- New password
- Confirm new password

The capability is available only to an authenticated user whose application profile exists, is active, has role `driver`, and satisfies the corresponding Driver account-integrity requirements. Identity and ownership come from the authenticated server-side session; browser-supplied profile IDs, Driver IDs, role information, Auth user IDs, and internal Auth identifiers are never authoritative.

The current password must be successfully verified before the credential changes. The new password and confirmation must match, and the new password must satisfy the configured Supabase Auth password policy. Supabase Auth remains the credential authority. A successful password change preserves the Driver's current authenticated session, does not redirect to login, and does not revoke other sessions as part of V1 Driver Settings.

Driver Settings does not allow the Driver to change username, full name, the internal Auth email/identifier, role, account activation state, Driver status, phone, profile data, vehicle or shipment data, notification preferences, theme, language, locale, or timezone. The Driver Profile remains read-only.

Admin retains authority over account provisioning, username assignment, role management, activation/deactivation, and administrative credential reset. Driver self-service password change is not the same workflow as Admin administrative credential reset: the former permits an authenticated active Driver to change only their own password after current-password verification, while the latter is an account-administration capability. Driver self-service password change grants no broader account-management authority.

V1 Driver Settings does not introduce public registration, public or email-based password recovery, username recovery, or security questions.

## 6. Core Application Modules

LogiFlow V1 includes:

1. Authentication
2. Admin / Dispatcher Dashboard
3. Driver Dashboard
4. Shipments
5. Drivers
6. Vehicles
7. Clients
8. Maintenance
9. Documents
10. Expenses
11. Reports
12. Live Tracking
13. Messages
14. Notifications
15. Alerts
16. Activity History
17. Settings

## 7. Shipments

### 7.1 Purpose

Shipments are the central operational entity in LogiFlow.

A shipment represents a transport job from one location to another and connects the client, driver, vehicle, delivery schedule, cargo information, financial data, documents, status workflow, tracking, and operational history.

### 7.2 Shipment Data

A shipment should contain at minimum:

- Internal ID
- Tracking number
- Client
- Pickup address
- Delivery address
- Pickup date and time
- Expected delivery date and time
- Cargo type
- Assigned driver
- Assigned vehicle
- Price
- Status
- Delayed flag
- Created at
- Updated at

The V1 form should remain intentionally focused and should not add unnecessary fields.

### 7.3 Tracking Number

Tracking numbers are generated automatically.

Example:

`SHP-2026-203`

Tracking numbers must be unique.

### 7.4 Shipment Statuses

Valid statuses:

- Pending
- Assigned
- Loading
- In Transit
- Delivered
- Cancelled

Normal workflow:

`Pending -> Assigned -> Loading -> In Transit -> Delivered`

`Cancelled` is an alternative terminal state.

### 7.5 Delayed Shipments

`Delayed` is not a shipment status.

A shipment may remain `In Transit` while also having:

`delayed = true`

Delayed shipments should generate an alert.

### 7.6 Driver and Vehicle Assignment Rules

A driver cannot be assigned to more than one active shipment at the same time.

A vehicle cannot be assigned to more than one active shipment at the same time.

An active shipment is any shipment that has not reached:

- Delivered
- Cancelled

If an unavailable driver is selected, reject the operation with a clear error.

Example:

`Driver Marko Jovanovic is currently assigned to shipment SHP-2026-203.`

If an unavailable vehicle is selected, reject the operation.

Example:

`Vehicle BG123AB is currently assigned to an active shipment.`

These rules must be enforced by application logic and, where practical, database constraints or transactional server-side validation.

## 8. Driver Shipment Status Workflow

### 8.1 Purpose

Drivers do not directly change the official shipment status.

Instead, they request a status change.

A Dispatcher must approve or reject the request.

This approval flow is a core V1 business rule.

### 8.2 Driver Actions

Depending on the current shipment state, the Driver may request the next valid transition.

Example sequence:

`Assigned -> Loading`

Driver action:

`Start Loading`

Then:

`Loading -> In Transit`

Driver action:

`Start Trip`

Then:

`In Transit -> Delivered`

Driver action:

`Complete Delivery`

Only the next valid transition from the current shipment state may be requested. Invalid or out-of-order status-change requests must be rejected with a clear business-rule error.

### 8.3 Status Change Request

When the Driver requests a change, the official shipment status remains unchanged.

A status-change request contains:

- Shipment
- Driver
- Current status
- Requested status
- Request timestamp
- Request status
- Approved/rejected by
- Approval/rejection timestamp
- Optional rejection reason

Request status values:

- Pending
- Approved
- Rejected

### 8.4 Dispatcher Approval

The Dispatcher receives an in-app notification.

Example:

`Marko Jovanovic requested a status change for SHP-2026-203: Assigned -> Loading`

The Dispatcher can:

- Approve
- Reject

If approved:

- Shipment status changes
- Request becomes Approved
- Activity history is updated
- Driver receives a notification
- Relevant side effects are triggered

If rejected:

- Shipment status remains unchanged
- Request becomes Rejected
- Driver receives a notification
- Optional rejection reason may be displayed

### 8.5 Delivery Completion

Required V1 behavior:

Proof of Delivery is required before a Dispatcher can approve `Delivered`.

## 9. Live Tracking

### 9.1 Purpose

V1 uses simulated live vehicle tracking.

The purpose is to demonstrate realistic real-time fleet tracking architecture without requiring physical GPS devices.

In portfolio/demo contexts, the UI must make clear that the tracking data is simulated.

### 9.2 Tracking Activation

Tracking is active only when:

`shipment.status = In Transit`

### 9.3 Simulated Tracking Data

The simulator may update:

- Latitude
- Longitude
- Speed
- Heading
- Route progress
- Last updated time

The frontend should receive updates in near real time while a shipment is `In Transit`. The UI must clearly indicate that the tracking data is simulated. Supabase Realtime may be used.

### 9.4 Live Map UI

The map should display:

- Vehicle marker
- Current location
- Route
- Pickup point
- Destination
- Progress
- Speed
- ETA
- Last updated time

### 9.5 Tracking Completion

When a shipment becomes `Delivered`, the simulator must stop updating that shipment's location.

## 10. Drivers

### 10.1 Driver Record

V1 may include:

- ID
- Full name
- Phone
- Status
- Assigned/current vehicle when relevant
- Active shipment when relevant
- User account relationship
- Created at
- Updated at
- Archived/inactive state

A large dedicated Driver Details page is not required in V1 unless later approved.

The Driver Dashboard is the main driver-facing experience.

### 10.2 Driver Status

Defined V1 driver statuses:

- Available
- Assigned
- Off Duty
- Inactive
- Archived

### 10.3 Operations Driver Master Data

Driver account creation remains exclusively part of Admin account provisioning, and account activation/deactivation remains exclusively part of account lifecycle management. Operations Driver Master Data never creates or deletes an Auth user, profile, or Driver row and never edits full name, username, password, role, or `profiles.is_active`.

An active Admin may edit only the Driver-owned `phone` field. Phone is optional, trimmed, normalized from an empty string to null, limited to 32 characters after trimming, not unique, and accepts ordinary local or international formatting. An inactive account is read-only in Driver Master Data. Phone edits are allowed during an active Shipment, use `drivers.updated_at` for optimistic concurrency, and do not create activity.

An active Dispatcher may list and read Drivers but cannot mutate them. Drivers have no Operations Driver Master Data access, and their existing self-service remains unchanged.

Admin operational changes use named actions rather than a generic status editor. The only allowed transitions are `available -> off_duty`, `off_duty -> available`, `available -> archived`, `off_duty -> archived`, and `archived -> available`. `assigned` is controlled only by Shipment workflows, while `inactive` is controlled only by account lifecycle. Every operational transition requires an active related Driver profile and is blocked while the Driver has a Shipment in `assigned`, `loading`, or `in_transit`. Delivered and cancelled Shipments do not block. Archive retains the account and all history, does not deactivate the profile, and makes the Driver unavailable for future assignment. No Driver is hard-deleted.

Each successful operational transition creates exactly one `driver_status_changed` activity with the Driver as its primary entity and minimal old status, new status, and operation metadata. Failed or no-op transitions create no activity. Driver Master Data creates no notification or alert and introduces no document/license assignment prerequisite.

## 11. Vehicles

### 11.1 Vehicle Record

Vehicle data may include:

- ID
- Make
- Model
- Registration
- Vehicle type
- VIN
- Mileage
- Fuel type
- First registration date
- Status
- Created at
- Updated at

### 11.2 Vehicle Statuses

Supported statuses:

- Available
- In Use
- Maintenance
- Out of Service
- Archived

`In Use` should normally be derived from an active shipment assignment rather than manually maintained independently.

### 11.3 Vehicle Master Data Management

Active Admin users may list, create, edit, update mileage, and perform the approved named Vehicle lifecycle actions. Active Dispatchers have read-only list access. Drivers have no Operations Vehicle access; their existing assigned-current-Vehicle access remains separate and unchanged. Inactive, missing-profile, and unauthenticated callers are denied. Vehicle hard delete is prohibited.

Creation requires registration, make, model, and vehicle type; VIN, mileage, fuel type, and first registration date are optional. Omitted mileage defaults to `0`, nonzero initial mileage is allowed, and initial status is always `available` rather than user-selectable. Ordinary editing is limited to registration, make, model, vehicle type, VIN, fuel type, and first registration date. Mileage uses a separate Admin operation with `updated_at` optimistic concurrency, is measured in kilometres, never decreases, and treats an equal value as a no-op.

Registration is trimmed, required, limited to 32 characters, preserves casing, and remains unique case-insensitively. VIN is trimmed, converts empty input to null, is limited to 64 characters when present, preserves casing, and remains unique case-sensitively when present. Neither field uses a country-specific or 17-character format rule.

`in_use` is controlled only by Shipment assignment/release. Admin lifecycle actions are limited to `mark_maintenance` (`available -> maintenance`), `mark_available` (`maintenance|out_of_service -> available`), `mark_out_of_service` (`available|maintenance -> out_of_service`), `archive` (`available|maintenance|out_of_service -> archived`), and `reactivate` (`archived -> available`). A Shipment in `assigned`, `loading`, or `in_transit` blocks every lifecycle action; delivered/cancelled Shipments and the delayed condition do not. Ordinary editing and mileage updates remain allowed while occupied. Maintenance records do not automatically change Vehicle status or independently block assignment.

The Operations list route is `/operations/vehicles`, with registration, make/model, type, mileage in km, status, and actions. It searches registration/model, filters status and existing free-text Vehicle types, uses ten-row server pagination, and orders by case-insensitive registration then Vehicle ID. Create and edit routes are `/operations/vehicles/new` and `/operations/vehicles/[vehicleId]/edit`; both are Admin-only. Lifecycle uses named actions, never a generic status selector.

### 11.4 Vehicle Details

Vehicle Details should provide:

- Overview
- Maintenance
- Documents
- History

The overview may display:

- Vehicle identity
- Registration
- Status
- Current driver
- Active shipment
- Mileage
- Fuel information if available
- Current tracking information when relevant
- Maintenance summary
- Document summary

## 12. Vehicle Maintenance

### 12.1 Maintenance Record

An Admin can create a maintenance record containing:

- Vehicle
- Service type
- Service date
- Mileage at service
- Workshop
- Cost
- Notes
- Next service date
- Next service mileage

### 12.2 Maintenance Alerts

Create alerts when:

- Next service date is approaching
- Next service mileage is approaching
- Maintenance is overdue

Alert thresholds are fixed defaults in V1 and should be centralized so they can be made configurable in a future version. Defaults are:

- Maintenance date warning: 14 days before due date
- Maintenance mileage warning: 1,000 km before due mileage

## 13. Documents

### 13.1 Vehicle Documents

Examples:

- Registration
- Insurance
- Technical inspection
- Road tax
- Tachograph calibration

### 13.2 Shipment Documents

Examples:

- CMR
- Invoice
- Delivery note
- Proof of Delivery
- Photos

### 13.3 Driver Documents

Examples:

- Driving license
- Professional license
- Certificates

### 13.4 Document Metadata

A document may contain:

- ID
- Entity type
- Entity ID
- Document type
- File path / storage reference
- File name
- Uploaded by
- Uploaded at
- Valid from
- Valid until
- Status

Document status should be tracked alongside validity dates so that documents can be surfaced in the appropriate workflow states and alerts.

### 13.5 Document Expiry Alerts

Create alerts for documents that are:

- Expiring soon
- Expired

Alert thresholds are fixed defaults in V1 and should be centralized so they can be made configurable in a future version. The default document expiry warning is 30 days before expiration.

## 14. Clients

### 14.1 Client Data

Fields:

- Company name
- Contact person
- Phone
- Email
- Address
- Notes
- Active/archived status
- Created at
- Updated at

Clients use exactly two lifecycle states: `active` and `archived`. An archived Client remains readable for historical purposes and cannot be selected for a new Shipment.

Client archival is blocked while any related Shipment is `pending`, `assigned`, `loading`, or `in_transit`. Related `delivered` and `cancelled` Shipments do not block archival. `Delayed` is not a Shipment status and does not independently affect Client archive eligibility. Archival never deletes or changes a Shipment, Driver or Vehicle assignment, or the historical `shipments.client_id` relationship.

### 14.2 Client Shipment History

Client details should display shipment history, including:

- Tracking number
- Route
- Status
- Date
- Price

LogiFlow is not a CRM in V1.

## 15. Expenses and Finance

### 15.1 Shipment Expenses

Supported categories:

- Fuel
- Toll
- Driver
- Maintenance
- Other

Expense fields may include:

- Shipment
- Category
- Amount
- Description
- Date
- Created by

### 15.2 Financial Calculations

`Revenue = Shipment Price`

`Expenses = Sum of Shipment Expenses`

`Profit = Revenue - Expenses`

These should be derived rather than manually duplicated where practical.

## 16. Reports

### 16.1 Financial Reports

- Revenue
- Expenses
- Profit

### 16.2 Shipment Reports

- Completed shipments
- Shipments by status
- Shipment count over time

### 16.3 Fleet Reports

- Vehicle utilization
- Maintenance summary

### 16.4 Driver Reports

- Driver activity
- Completed shipments by driver

### 16.5 Client Reports

- Top clients
- Revenue by client
- Shipment count by client

## 17. Messages

V1 messaging is one-way:

`Dispatcher -> Driver`

It is not a chat system.

A message may contain:

- Sender
- Driver recipient
- Optional shipment reference
- Message body
- Sent at
- Read at
- Read status

The Driver can read and mark messages as read but cannot reply in V1.

## 18. Notifications

V1 notification examples:

- New shipment assigned
- Status approval requested
- Status approved
- Status rejected
- Shipment delayed
- Vehicle maintenance due
- Vehicle document expiring
- Driver document expiring
- New dispatcher message
- Shipment delivered

The header notification icon should display an unread count where appropriate.

V1 supports in-app notifications only.

## 19. Alerts

Alerts represent operational conditions that require attention.

Examples:

- Shipment delayed
- Vehicle maintenance overdue
- Vehicle location stale
- Driver license expiring
- Vehicle insurance expiring
- Technical inspection expiring

Alerts are distinct from ordinary notifications. Fixed V1 alert defaults should be centralized and include the following defaults:

- Document expiry warning: 30 days before expiration
- Maintenance date warning: 14 days before due date
- Maintenance mileage warning: 1,000 km before due mileage
- Stale vehicle location: 10 minutes without an update

## 20. Activity History

Important system and user actions should be recorded. Activity and audit history are retained indefinitely in V1.

Shipment events may include:

- Shipment created
- Driver assigned
- Vehicle assigned
- Status change requested
- Status change approved
- Status change rejected
- Trip started
- Proof of Delivery uploaded
- Shipment delivered
- Shipment cancelled

Vehicle events may include:

- Vehicle created
- Vehicle assigned
- Driver assigned
- Maintenance completed
- Document uploaded
- Mileage updated
- Vehicle archived

Activity records should include:

- Actor where applicable
- Entity
- Action
- Timestamp
- Relevant metadata

## 21. Search and Filtering

V1 does not require global search.

Each major list page should provide local search and relevant filters.

Examples:

Shipments:
- Search by tracking number
- Search by client
- Search by vehicle
- Filter by status
- Filter by driver

Drivers:
- Search by name
- Filter by status

Vehicles:
- Search by registration/model
- Filter by status/type

Clients:
- Search by company/contact

## 22. Archive and Delete Rules

Important historical business data should not be permanently deleted through normal application workflows.

Use archive/inactive/cancelled states.

Examples:

- Vehicle -> Archived
- Driver -> Inactive or Archived
- Client -> Archived
- Shipment -> Cancelled

Historical relationships must remain readable.

Every successful Client create, real business-field edit, archive, or reactivation creates exactly one corresponding Client activity record. Failed and no-op Client mutations create no activity record.

## 23. Dashboard Requirements

### 23.1 Admin / Dispatcher Dashboard

May contain:

- Active Shipments
- Active Vehicles
- Active Drivers
- Monthly Revenue
- Live Map
- Recent Activity
- Alerts
- Recent Shipments

Admin and Dispatcher may share the same visual dashboard with role-based differences.

### 23.2 Driver Dashboard

Should focus on the current job and may contain:

- Current assignment
- Pickup location
- Destination
- Progress
- ETA
- Driving time
- Break information
- Current shipment status
- Next permitted status action
- Today's schedule
- Recent activity
- Dispatcher messages
- Assigned vehicle
- Relevant documents

The Driver Dashboard must work well on desktop and mobile, with mobile receiving high priority.

## 24. Responsive Strategy

### 24.1 Admin / Dispatcher

Primary targets:

- Desktop
- Tablet

Mobile must remain usable but is not the primary operating environment.

Expected behavior:

- Full sidebar on desktop
- Collapsed/alternative sidebar on tablet
- Drawer navigation on narrow mobile layouts
- KPI cards reflow responsively
- Multi-column sections stack where necessary
- Large tables should use horizontal scrolling and remain usable on smaller screens
- Content must not unexpectedly overflow the viewport

### 24.2 Driver

Primary targets:

- Mobile
- Desktop

Buttons used during shipment execution should be large, clear, and easy to tap.

## 25. Demo / Seed Data

The V1 demo seed data should be predefined, realistic, and aligned with the target dataset below:

Target dataset:

- 1 Admin
- 2-3 Dispatchers
- Approximately 15 Drivers
- Approximately 12 Vehicles
- Approximately 10 Clients
- Approximately 30-50 Shipments
- Maintenance records
- Documents
- Expenses
- Messages
- Notifications
- Alerts
- Activity logs

Data should represent multiple shipment statuses and realistic operational conditions.

## 26. UI / UX Requirements

The existing approved design references are the visual source of truth.

The application should follow the project's Design System document for:

- Typography
- Colors
- Spacing
- Borders
- Radius
- Shadows
- Cards
- Tables
- Buttons
- Inputs
- Status badges
- Sidebar
- Header
- Responsive behavior

Codex must not redesign approved screens unless explicitly instructed.

Screenshots define visual intent.

The PRD defines functional intent.

The Design System defines styling rules.

The Database document defines data structure.

The Architecture document defines implementation patterns.

## 27. Loading, Empty, and Error States

All data-driven modules must support:

- Loading state
- Empty state
- Error state
- Success feedback where applicable

Business-rule errors must clearly explain why an operation was rejected.

## 28. Validation Requirements

All create/edit forms must validate user input.

Validation should exist at appropriate layers:

- Client-side form validation
- Server-side validation
- Database constraints where appropriate

Invalid relational states must not be accepted even if the UI is bypassed.

Examples:

- Duplicate tracking number must be rejected
- Invalid shipment transition must be rejected
- Busy driver assignment must be rejected
- Busy vehicle assignment must be rejected
- Unauthorized role action must be rejected

## 29. Security and Authorization

Authorization must be enforced beyond the UI.

Requirements:

- Protected authenticated routes
- Role-based permissions
- Supabase Row Level Security where appropriate
- Drivers must not access other drivers' private operational data
- Drivers must only access their own assignments and permitted documents/messages
- Admin-only actions must be protected server-side
- Sensitive credentials must not be exposed to the client

## 30. Core User Flow

1. Admin creates user accounts.
2. Admin creates or manages drivers, vehicles, and clients.
3. Dispatcher creates a shipment.
4. Dispatcher selects a client.
5. Dispatcher selects an available driver.
6. Dispatcher selects an available vehicle.
7. Shipment becomes `Assigned`.
8. Driver sees the new assignment.
9. Driver requests `Loading`.
10. Dispatcher approves.
11. Shipment becomes `Loading`.
12. Driver requests `In Transit`.
13. Dispatcher approves.
14. Shipment becomes `In Transit`.
15. Simulated live tracking starts.
16. Driver reaches the destination.
17. Driver uploads Proof of Delivery.
18. Driver requests `Delivered`.
19. Dispatcher approves.
20. Shipment becomes `Delivered`.
21. Live tracking stops.
22. Driver becomes available.
23. Vehicle becomes available.
24. Activity history is updated.
25. Reports and financial summaries reflect the completed shipment.

This workflow is the primary backbone of LogiFlow V1.

## 31. Definition of Done for V1

LogiFlow V1 is portfolio-ready when:

- Authentication works
- Admin can provision users
- Roles and permissions work correctly
- Protected routes are enforced
- Drivers can only access permitted data
- Shipments can be created and edited
- Clients can be managed
- Drivers can be managed
- Vehicles can be managed
- Driver and vehicle double-assignment is prevented
- Driver shipment status requests work
- Dispatcher approval/rejection works
- Shipment activity history works
- Simulated live tracking works for In Transit shipments
- Vehicle maintenance can be recorded
- Maintenance alerts work
- Vehicle, shipment, and driver documents can be stored
- Document expiry alerts work
- Shipment expenses can be recorded
- Revenue, expenses, and profit can be calculated
- Reports display realistic data
- Dispatcher can send one-way messages to Drivers
- Notifications work
- Alerts work
- Archive/cancel rules preserve history
- Admin/Dispatcher UI works well on desktop/tablet
- Driver UI works well on mobile and desktop
- Approved design references are implemented with high visual fidelity
- Loading, empty, and error states exist
- Type checking passes
- Linting passes
- No known critical runtime errors remain
- Demo seed data is available
- The application can be deployed and demonstrated as a complete portfolio project

## 32. Future Improvements

Potential future versions may include:

- Real GPS integrations
- Real telematics providers
- Automatic route optimization
- Customer portal
- Two-way chat
- Email notifications
- SMS notifications
- Advanced invoice generation
- Accounting integrations
- Multi-company SaaS architecture
- Native driver application
- Advanced analytics
- Predictive maintenance
- Route performance analysis
- External API integrations

These features are not part of V1.

## 33. Document Hierarchy

During implementation, use this hierarchy:

1. `PRD.md` — functional product requirements
2. `DESIGN_SYSTEM.md` — visual and responsive rules
3. `DATABASE.md` — schema, relationships, constraints, and policies
4. `ARCHITECTURE.md` — code organization and technical patterns
5. `AGENTS.md` — Codex implementation rules
6. Approved screenshots — visual source of truth

If requirements conflict, identify the conflict before implementation rather than silently resolving it through assumptions.

## 34. Open Decisions for Later Planning

The following remain implementation-level decisions to be finalized in the database and architecture documents:

- Exact database schema
- Exact Row Level Security policies
- Exact Supabase Auth implementation approach for username-based login
- Exact technical enforcement of Proof of Delivery before Delivered approval
- Exact map provider and routing provider
- Exact live-tracking simulation mechanism
- Exact report visualizations

These items should be resolved in the relevant technical documentation and must not change the V1 product scope or requirements.
