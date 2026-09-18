# LogiFlow Agent Working Rules

These rules are mandatory for Codex and every coding agent working in this repository. Apply them before planning, implementation, review, validation, refactoring, migration work, or debugging that may affect approved behavior.

## 1. Read the Sources of Truth First

Before planning, implementation, review, validation, refactoring, migration work, or debugging that may affect approved behavior:

1. Read `PRD.md` for product scope, behavior, roles, and permissions.
2. Read `DATABASE.md` for schema, enums, relationships, constraints, retention, indexes, and transactional responsibilities.
3. Read `ARCHITECTURE.md` for runtime boundaries, security architecture, folder structure, and implementation patterns.
4. Read `DESIGN_SYSTEM.md` for visual, responsive, accessibility, Tailwind, and reusable-component rules.
5. Inspect the relevant existing routes, components, features, DAL functions, validation schemas, database types, tests, and migrations before proposing, reviewing, validating, or changing behavior or creating an abstraction.
6. Read any approved screenshots or visual references supplied for the task.

Do not rely on memory or general framework knowledge when repository documentation or existing code can answer the question.

<!-- BEGIN:nextjs-agent-rules -->
## This Is Not the Next.js You Know

This Next.js version has breaking changes; APIs, conventions, and file structure may differ from training data. Before planning, reviewing, validating, or modifying Next.js code or behavior, read the relevant installed guide under `node_modules/next/dist/docs/`. Follow its current API guidance and heed all deprecation notices. If the required installed documentation is missing, unreadable, incomplete for the task, or contradicts the repository's installed Next.js version, stop and report the issue. Do not guess framework behavior from memory when documentation consultation is required.
<!-- END:nextjs-agent-rules -->

## 2. Apply the Correct Authority

Use the following scoped authority. Do not let a lower authority override a higher authority within the higher authority's domain.

1. `PRD.md` governs functional product scope, behavior, roles, and permissions.
2. Approved screenshots govern visual composition and visual intent only.
3. `DESIGN_SYSTEM.md` governs reusable visual rules, responsive behavior, accessibility, components, and Tailwind tokens.
4. `DATABASE.md` governs tables, fields, enums, relationships, constraints, indexes, retention, derived data, transactional responsibilities, notifications, and alerts.
5. `ARCHITECTURE.md` governs application structure, runtime responsibilities, security boundaries, data flow, and technical patterns.
6. `AGENTS.md` governs agent workflow and implementation discipline; it does not create or override product, database, architecture, or design requirements.

Apply the more specific authoritative rule when two documents address different aspects of the same feature. In particular, follow `DATABASE.md` over `ARCHITECTURE.md` for database definitions and transactional responsibilities, as required by `ARCHITECTURE.md`. If authoritative requirements genuinely conflict, stop and report the exact passages and affected decision. Do not resolve a contradiction silently.

## 3. Control Scope

- Make the smallest safe change that fully satisfies the approved task.
- Limit edits to files and behavior necessary for the task.
- Bring all newly created or modified behavior into compliance with the authoritative documents.
- Do not expand a localized task into remediation of unrelated pre-existing violations. Report unrelated violations when they materially affect the task, but do not modify them without approval.
- Inspect existing code before creating a new abstraction, dependency, route, component, helper, type, schema, database function, or pattern.
- Reuse and extend established patterns when they satisfy the requirement.
- Preserve unrelated user changes and avoid opportunistic refactors, cleanup, renaming, reformatting, or dependency upgrades.
- Obtain explicit approval before expanding product scope, technical scope, or the set of modified files in a material way.
- Treat future ideas and non-goals in `PRD.md` as out of scope unless the task explicitly approves them.

## 4. Do Not Invent Requirements

Do not invent, infer from convention, or silently change:

- product behavior, workflows, requirements, or routes;
- roles, permissions, ownership rules, or visibility rules;
- statuses, state transitions, labels, enum values, or error semantics;
- fields, tables, relationships, indexes, constraints, database functions, or RLS policies;
- notification, alert, activity, retention, deletion, or derived-data behavior;
- visual styles, colors, tokens, spacing, breakpoints, components, navigation patterns, or responsive behavior;
- dependencies, infrastructure, external services, environment variables, or deployment topology.

Do not use a screenshot, mock, placeholder, seed object, TypeScript interface, or current UI omission as authority for new product or schema behavior.

## 5. Enforce Next.js and Data Boundaries

### Server Components

- Use Server Components by default for authenticated reads, layouts, dashboards, reports, lists, details, pagination, filtering, and initial snapshots.
- Keep operational reads in server-only DAL functions; do not query operational tables directly from pages or UI components.
- Pass Client Components only the minimum serializable, presentation-safe data they need.

### Client Components

- Add `"use client"` only for focused browser interaction such as local form state, overlays, responsive navigation, interactive table controls, upload progress, MapLibre, Realtime lifecycle, optimistic acknowledgements, or pending states.
- Keep client islands small. Do not move server reads, authorization decisions, secrets, unrestricted database clients, or business integrity rules into the browser.

### Server Actions

- Use Server Actions as the standard browser-mutation boundary.
- Treat every Server Action as a directly callable public endpoint.
- Validate input, consume and verify the refreshed server session, load and verify the active current profile, enforce role and permission, call an authorized DAL command or controlled database function, translate errors safely, and invalidate only affected data.
- Never trust a browser-supplied actor, role, ownership assertion, username mapping, driver identity, price calculation, or permission decision.

### Route Handlers

- Create a Route Handler only when a genuine HTTP endpoint is required by `ARCHITECTURE.md`, such as an integration-required auth endpoint, unsuitable document transfer, safe health endpoint, or authenticated machine callback.
- Do not create a Route Handler merely as an alternative to a Server Action.
- Authenticate and authorize every applicable Route Handler and validate its body, query, headers, and origin or bearer credential as appropriate.

### DAL and Database Functions

- Keep the DAL server-only. Make it the sole application module that queries operational tables.
- Use authenticated-user Supabase clients for ordinary reads so RLS remains active.
- Keep queries role-scoped, select explicit columns, use bounded pagination, and map rows to typed view models.
- Let Server Components call DAL reads; let Server Actions and Route Handlers call DAL commands.
- Use controlled PostgreSQL functions for the workflows that `ARCHITECTURE.md` and `DATABASE.md` explicitly assign to controlled database functions.
- The approved controlled-function inventory is:

  1. Shipment controlled workflows: separate narrow pending-Shipment creation and initial-assignment functions
  2. Status-request creation
  3. Status-request approval/rejection
  4. Tracking start
  5. Tracking stop
  6. Maintenance creation
  7. Driver operational-status transition
  8. Vehicle master-data mutations and operational lifecycle

- The inventory remains exactly eight categories. The existing Shipment controlled-workflow category contains separate narrow pending-Shipment creation and initial-assignment functions; adding the creation function does not create a ninth category and the operations must not be merged into a generic mutation RPC.

- Other workflows may still require atomic transactions without becoming named controlled PostgreSQL functions.
- Expense creation/update is one such workflow: it must atomically create or update the expense together with its required activity entry, but it is not part of the eight-item controlled-function inventory.
- Do not infer that every atomic workflow requires a PostgreSQL function.
- Follow the exact transaction boundary documented by `ARCHITECTURE.md` and `DATABASE.md`.
- Deny direct mutations that would bypass a controlled workflow. Do not add a new controlled-function category unless approved by `DATABASE.md` and `ARCHITECTURE.md`.

## 6. Protect Supabase Boundaries

### Auth and Authorization

- Use Supabase Auth through the documented SSR session flow. Root `proxy.ts` owns session refresh and propagates updated cookies.
- Make protected layouts, Server Components, Server Actions, and Route Handlers consume and verify the refreshed server session.
- Verify authentication, active profile state, role, and permission independently at every callable server boundary. Repeat the applicable authorization checks in DAL entry points, controlled database functions, RLS policies, and Storage policies.
- Do not make Server Actions duplicate the session-refresh responsibility assigned to root `proxy.ts`.
- Derive actor and recipient identity from the authenticated server session. Never authorize from hidden UI, client state, or browser-supplied identity fields.
- Return generic authentication failures where required to prevent username enumeration.

### RLS and Service Role

- Enable RLS on every public application table.
- Define and test explicit least-privilege policies for tables exposed through the Supabase Data API or Realtime.
- Ensure internal-only tables are not unintentionally accessible through public roles or grants, even though they remain covered by the public-table RLS requirement when located in `public`.
- Keep full RLS policy SQL in migrations and implementation work.
- Define explicit grants and function execution permissions. Revoke permissive defaults and expose the minimum required surface.
- Use invoker-context access by default. Give every security-definer function a fixed `search_path`, explicit authorization, and minimum grants.
- Create a service-role client only in an explicitly marked server-only module for the narrow trusted uses approved by `ARCHITECTURE.md`: Auth administration, scheduler or Edge Function work, and documented compensating Storage cleanup.
- Never expose service-role or scheduler secrets, internal Auth identifiers, unrestricted clients, or privileged results to the browser. Never use the service role as the default DAL client or to bypass RLS for convenience.

### Storage

- Keep document buckets private and align Storage policies with document ownership and role permissions.
- Store only the object path in `documents.file_path`; never store a public or signed URL.
- Authorize upload intent, constrain the server-issued path, and validate owner, type, file name, extension, MIME metadata, size, role, and ownership at the documented stages.
- Treat Storage transfer and PostgreSQL metadata insertion as a staged workflow. If completion or metadata insertion fails after upload, delete the exact newly uploaded object as compensation and record a safe structured failure.
- Authorize every signed download and keep its URL short-lived and out of logs and persistence.

### Realtime

- Use Supabase Realtime Postgres Changes only for `vehicle_locations` unless an approved architecture change says otherwise.
- Keep browser Realtime access read-only and RLS-scoped. Admin and Dispatcher may receive approved active-fleet rows; a Driver may receive only their authorized current assignment row.
- Preserve the initial snapshot, reconciliation, stale-state, reconnection, fallback-refresh, and unsubscribe behavior defined by `ARCHITECTURE.md`.

## 7. Enforce TypeScript and Validation

- Keep TypeScript strict. Do not use `any` or suppression comments to bypass an unresolved type problem.
- Avoid non-null assertions and unsafe type casts. Prefer narrowing, validation, generated types, and explicit guards.
- Permit a localized assertion only when validated data or a documented framework or database contract already guarantees the invariant. Keep it narrow and add a concise justification when the invariant is not obvious.
- Do not use assertions to silence genuine type errors. Do not refactor unrelated code solely to remove pre-existing assertions outside the task scope.
- Use generated database types as the database contract. Regenerate them after an approved schema migration; do not independently redefine tables or enums in application code.
- Use typed domain/view models and discriminated success/error contracts at server boundaries.
- Validate every untrusted boundary with Zod, including environment variables, forms, Server Action inputs, Route Handler bodies, query parameters, filters, upload intent, and upload completion data.
- Validate permissions and business rules in server-only domain/DAL logic, while retaining PostgreSQL constraints, RLS, locks, unique indexes, and controlled functions as the integrity and concurrency authority.
- Centralize canonical constants that mirror approved database enums, transitions, document types, categories, and thresholds. Do not scatter string literals or duplicate derived state.
- Trim and length-limit search input, use parameterized Supabase queries, and never construct SQL from browser input.

## 8. Follow the Design System and Tailwind Tokens

- Implement `DESIGN_SYSTEM.md` exactly for tokens, typography, spacing, radii, borders, focus, motion, accessibility, shells, breakpoints, and responsive behavior.
- Use semantic Tailwind tokens and the repository's consistent class-merging and typed-variant patterns.
- Do not use raw approved colors in reusable components, arbitrary values where a token exists, unapproved shadows, duplicated inline styles, random spacing, page-specific status styling, or a new visual language.
- Use the approved component variants, semantic status mappings, role-specific navigation, wordmark placement, loading/empty/error/success states, and WCAG AA behavior.
- Keep Driver-only mobile navigation and bottom-sheet patterns out of Admin and Dispatcher experiences.
- Use only approved iconography and visual assets. Do not redraw, abbreviate, crop, or replace the LogiFlow wordmark.

## 9. Reuse Components

- Search `components/`, relevant `features/`, and existing screens before creating a component.
- Compose new screens from the reusable inventory in `DESIGN_SYSTEM.md`.
- Extend a shared component through typed variants when the approved design requires a reusable difference.
- Create a new shared abstraction only when at least one existing primitive or composition cannot express the approved requirement cleanly.
- Do not create page-specific copies of buttons, fields, cards, tables, badges, overlays, feedback states, navigation, timelines, or upload controls.
- Keep feature-specific composition in feature areas and truly reusable primitives in shared component areas.

## 10. Preserve Folder and Dependency Boundaries

- Follow the project structure in `ARCHITECTURE.md`.
- Keep route composition and route boundaries in `app/`; reusable UI in `components/`; feature-specific schemas, view models, and composition in `features/`; shared security, DAL, domain, validation, Supabase clients, observability, constants, and environment handling in `lib/`.
- Keep generated database types in the documented generated-types location and shared Next.js/Edge runtime contracts in `shared/runtime/`.
- Prevent feature folders from creating their own authorization framework, Supabase client factory, DAL, error contract, or duplicated canonical constants.
- Keep server-only imports out of Client Components. Do not introduce a dependency cycle or import an application runtime module into migrations or Edge code when a runtime-safe shared contract is required.
- Add or upgrade dependencies only when the approved task requires it, the existing stack cannot satisfy it, and the change is explicitly in scope. Review package and lockfile changes together.

## 11. Make Database Migrations Safe

- Create a migration only for an approved database change that matches `DATABASE.md`.
- Do not add or rename a table, column, enum value, relationship, constraint, index, trigger, function, policy, or grant without authoritative approval.
- Follow the dependency-safe creation order and exact definitions in `DATABASE.md`.
- Preserve retained history. Use archive, inactive, cancelled, immutable, or resolved behavior as documented; do not hard-delete retained business rows in normal workflows.
- Preserve row-local constraints, concurrency backstops, explicit grants, RLS, Storage policies, Realtime publication rules, function permissions, fixed search paths, and correct trigger coverage.
- Do not add speculative indexes. Add optional indexes only from demonstrated query patterns and appropriate query-plan evidence.
- Plan a safe rollback or forward-remediation path before applying a migration. Identify irreversible data transformations explicitly.
- Validate migrations in an isolated environment before deployment and regenerate checked-in database types when the approved schema changes.
- Never edit an already-applied migration to change production history; add a corrective migration.

## 12. Preserve Transactional Workflows

- Execute every workflow listed as atomic in `DATABASE.md` and `ARCHITECTURE.md` through its controlled transaction boundary.
- Lock and revalidate current database state inside the transaction. Never trust a preceding UI read for availability, status, ownership, POD presence, or transition validity.
- Include every required row change, resource synchronization, activity entry, notification, alert effect, and tracking start/stop effect in the same transaction where documented.
- Translate concurrency and uniqueness failures into safe, specific business errors without exposing unauthorized records.
- Ensure transaction failure leaves no partial business state.
- Treat document Storage transfer as the documented exception and use exact-object compensation because Storage and PostgreSQL cannot share one transaction.
- Do not wrap unrelated multi-step CRUD in a transaction or invent transactional side effects beyond the documented workflows.

## 13. Handle Errors and Logging Safely

- Return the discriminated server error contract defined by `ARCHITECTURE.md`, including a safe category, message, applicable field errors, and correlation ID.
- Display expected validation and business-rule errors near the initiating control. Use safe forbidden, not-found, retry, and error-boundary experiences without revealing inaccessible records.
- Attach or propagate a correlation ID for requests, Server Actions, Route Handlers, Edge Functions, and scheduled runs.
- Log structured operation names, safe actor/profile and entity identifiers, duration, outcome, category, and correlation ID only when needed.
- Never log passwords, Auth tokens, cookies, service-role or scheduler keys, internal Auth email identifiers, signed URLs, unrestricted document paths, arbitrary request bodies, full database rows, secrets, or sensitive personal data.
- Keep infrastructure telemetry separate from immutable business `activity_logs`.
- Do not swallow failures. Translate expected failures, report unexpected failures through approved observability, and preserve safe diagnostics.

## 14. Use Proportionate Validation

Before changing files, determine the validation scope from:

1. the files being changed;
2. the behavior affected;
3. the repository scripts and test tooling that already exist;
4. explicit task requirements.

Run all existing validation commands that directly cover the changed behavior. Do not invent validation commands or tooling that the repository does not provide. Do not run unrelated test categories merely to satisfy a checklist.

### Documentation-Only Changes

- Run only available checks that apply to the edited documents, such as repository-provided Markdown lint, repository-provided link or path checks, document consistency review, and `git diff --check`.
- If no automated documentation check exists, perform a read-only content and path review and report that no dedicated documentation command exists.

### Localized UI Changes

- Run relevant component, unit, and accessibility tests when present.
- Run lint for affected code or the repository lint command.
- Run the TypeScript typecheck.

### Server, Workflow, Auth, DAL, or Authorization Changes

- Run relevant unit and integration tests.
- Run authorization or RLS tests when affected.
- Run lint and typecheck.
- Include transactional, failure, concurrency, and end-to-end coverage when the changed workflow requires it and the repository provides it.

### Database or Migration Changes

- Run migration or schema validation and relevant database or integration tests.
- Run RLS and grant checks when affected.
- Verify generated database types and run the affected application typecheck.

### Storage or Realtime Changes

- Run targeted permission and failure-path tests and relevant integration tests.
- Run typecheck.
- For Realtime, cover affected role visibility, read-only access, subscription, reconciliation, stale, reconnection, fallback, and cleanup behavior when supported by existing tests.
- For Storage, cover affected ownership, policy, upload validation, signed-download, compensation, abandoned-upload, and failure behavior when supported by existing tests.

A production build is required when the task changes any of the following:

- routing or route groups;
- layouts, rendering boundaries, or Server/Client Component boundaries;
- Next.js configuration;
- shared build or runtime configuration;
- framework integrations;
- environment-variable usage;
- module resolution or shared dependency boundaries;
- code whose correctness depends on production compilation;
- broad or cross-cutting application behavior.

For a localized application-code change that does not affect those areas:

- run lint;
- run TypeScript typecheck;
- run relevant targeted tests;
- run a production build only when the changed behavior is not adequately covered by those checks or when the user explicitly requires it.

Documentation-only changes do not require a production build unless the user explicitly requests one.

Database, migration, Storage, Realtime, Auth, or server-workflow changes must follow their own validation matrix and require a production build only when Next.js production compilation or runtime integration is affected.

### Validation Failures

- If a required validation command fails, do not claim completion.
- Determine whether the failure was caused by the current change or was pre-existing.
- Fix only failures caused by the current task and within its approved scope.
- Do not broaden the task to repair unrelated pre-existing failures.
- Report unrelated failures exactly and stop before claiming the task is complete.
- Never hide, suppress, or work around a failing validation without explicit approval.
- If a required command cannot run because of an external or environment blocker, report the exact command, blocker, and resulting risk; do not report the task as fully validated.

## 15. Edit Files Deliberately

- Read a file and inspect relevant call sites before editing it.
- Keep diffs narrow and preserve the file's established conventions and encoding.
- Do not overwrite or revert unrelated user changes.
- Do not perform broad formatting, generated-file edits, dependency changes, lockfile churn, or unrelated cleanup.
- Do not use destructive Git or filesystem commands unless the user explicitly requests the exact operation and the targets have been verified.
- Do not modify approved documents to make an implementation appear compliant. Report the mismatch instead.
- Review the final diff and working-tree status before reporting completion.

## 16. Work from Screenshots and Approved Visual References

- Use approved screenshots to reproduce composition, hierarchy, density, spacing intent, responsive intent, and visual fidelity.
- Use `DESIGN_SYSTEM.md` to translate screenshot intent into shared tokens, components, accessibility behavior, and responsive implementation.
- Reuse existing assets and components. Do not trace a screenshot into a monolithic component or detach one-off styling from the design system.
- Do not infer hidden interactions, alternate states, validation behavior, data fields, permissions, workflows, or schema from a screenshot.
- When a screenshot conflicts with product behavior, database rules, accessibility, or the reusable design system, stop and report the conflict before implementation.
- When no approved screenshot exists, follow `DESIGN_SYSTEM.md` and established page patterns. Do not invent a new visual language.

## 17. Report Every Task

Unless the user supplies a stricter output format, report after every task:

- every modified file;
- a concise summary of behavior or documentation changed;
- every validation command run and whether it passed or failed;
- required validation commands that could not run and the reason;
- unresolved issues, risks, contradictions, blockers, and required follow-up.

Do not claim a command ran, a test passed, or an issue was resolved without evidence.

For read-only review, audit, or validation tasks:

- report that modified files are `None`;
- list the files or authorities reviewed;
- report the checks performed;
- report exact findings or `PASS`, according to the requested response format.

Follow an explicit user-required response format when it does not conflict with safety or accuracy. If the user requests `PASS` only, return only `PASS` when valid. If the user requests `FAIL` plus exact issues, do not append the standard task report. The standard completion report applies only when the user has not supplied a stricter output format.

## 18. Stop When Requirements Are Unsafe or Unclear

Stop before implementation and request clarification when:

- authoritative requirements are missing, materially ambiguous, or contradictory;
- the task requires behavior, schema, status, field, table, permission, policy, workflow, dependency, or visual language that is not approved;
- the requested change is outside V1 scope or contradicts a documented non-goal;
- a migration cannot preserve data, security, integrity, or a safe remediation path;
- required screenshots or approved references are unavailable and the missing intent cannot be derived from `DESIGN_SYSTEM.md` or existing patterns;
- required installed Next.js documentation is missing, unreadable, incomplete for the task, or inconsistent with the installed Next.js version when the task requires consulting it;
- existing user changes overlap the task and cannot be preserved safely;
- the change requires materially broader files, external coordination, credentials, deployment authority, or destructive action than the user authorized.

State the exact blocker, the authoritative text involved, and the decision required. Do not fill the gap with an assumption.

## 19. Prohibited Behavior

Never:

- add unapproved product requirements or implement V1 non-goals;
- weaken authentication, authorization, RLS, grants, Storage policies, validation, constraints, or transactional guarantees for convenience;
- use service role in the browser or as a general RLS bypass;
- expose secrets, privileged clients, signed URLs, private paths, or sensitive records;
- query operational tables from UI components or place trusted business logic in Client Components;
- directly mutate tables to bypass controlled workflows;
- duplicate derived values that `DATABASE.md` requires calculating;
- hard-delete retained historical business data through normal workflows;
- invent schema, enums, statuses, transitions, permissions, notifications, alerts, activity, or visual rules;
- introduce one-off UI when an approved reusable component or pattern exists;
- suppress TypeScript, lint, validation, test, build, migration, RLS, Realtime, or Storage failures to make a task appear complete;
- modify unrelated files, approved requirements, or prior migrations to hide inconsistency;
- claim completion while relevant validation is failing or known critical runtime or security issues remain.

## 20. Definition of Done

An implementation task is done only when:

- the requested behavior matches `PRD.md`, `DATABASE.md`, `ARCHITECTURE.md`, `DESIGN_SYSTEM.md`, and any approved visual reference within their respective authority;
- the smallest safe change has been made and unrelated behavior and user changes remain intact;
- Server/Client, Server Action/Route Handler, DAL, database-function, folder, and dependency boundaries are preserved;
- authentication, authorization, RLS, Storage, Realtime, service-role, data-retention, and logging rules remain safe;
- input validation, strict types, database integrity, concurrency handling, transactions, compensation, error states, and failure paths are implemented as applicable;
- shared design tokens and reusable components are used, responsive behavior is correct, and applicable WCAG AA requirements are met;
- all existing validation commands selected by the section 14 scope rules pass, including lint, typecheck, tests, and the production build whenever their concrete triggers apply;
- the final diff contains no unrelated files, accidental generated changes, or known critical errors;
- the task report follows section 17 unless the user supplied a stricter response format.
