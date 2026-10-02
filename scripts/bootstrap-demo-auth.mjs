import { randomBytes } from "node:crypto";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

import { createClient } from "@supabase/supabase-js";

const VERIFY_ONLY = process.argv.includes("--verify-only");
const BUCKET = "documents";
const DEMO_PREFIX = "LogiFlow SD1";
const LOCAL_DATABASE_CONTAINER = "supabase_db_logiflow-app";

function loadLocalEnvironment() {
  let source;
  try {
    source = readFileSync(new URL("../.env.local", import.meta.url), "utf8");
  } catch {
    return;
  }

  for (const line of source.split(/\r?\n/u)) {
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#")) continue;
    const separator = trimmed.indexOf("=");
    if (separator < 1) continue;
    const key = trimmed.slice(0, separator).trim();
    let value = trimmed.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

loadLocalEnvironment();

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const authDomain = process.env.AUTH_INTERNAL_DOMAIN;
const demoPassword = process.env.LOGIFLOW_DEMO_PASSWORD;

function requireLocalEnvironment() {
  const missing = [
    ["NEXT_PUBLIC_SUPABASE_URL", url],
    ["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", publishableKey],
    ["SUPABASE_SERVICE_ROLE_KEY", serviceRoleKey],
    ["AUTH_INTERNAL_DOMAIN", authDomain],
    ["LOGIFLOW_DEMO_PASSWORD", demoPassword],
  ].filter(([, value]) => !value).map(([name]) => name);

  if (missing.length > 0) {
    throw new Error(`Missing required local demo environment values: ${missing.join(", ")}.`);
  }

  const parsed = new URL(url);
  const localHost = parsed.hostname === "127.0.0.1" || parsed.hostname === "localhost" || parsed.hostname === "[::1]";
  if (parsed.protocol !== "http:" || !localHost || parsed.port !== "54321") {
    throw new Error("Refusing demo bootstrap: NEXT_PUBLIC_SUPABASE_URL is not the repository local Supabase API on port 54321.");
  }
  if (process.env.RATE_LIMIT_ENVIRONMENT !== "development") {
    throw new Error("Refusing demo bootstrap: RATE_LIMIT_ENVIRONMENT must be development.");
  }
  if (!authDomain.endsWith(".local")) {
    throw new Error("Refusing demo bootstrap: AUTH_INTERNAL_DOMAIN must be an explicit .local development domain.");
  }
  if (process.env.SUPABASE_DOCUMENTS_BUCKET !== BUCKET) {
    throw new Error(`Refusing demo bootstrap: SUPABASE_DOCUMENTS_BUCKET must be ${BUCKET}.`);
  }
  if (demoPassword.length < 12 || demoPassword.length > 72 || /\s/u.test(demoPassword)) {
    throw new Error("LOGIFLOW_DEMO_PASSWORD must be 12-72 characters with no whitespace.");
  }
}

requireLocalEnvironment();

const CLIENTS = {
  danube: "40000000-0000-4000-8000-000000000001",
  adriatic: "40000000-0000-4000-8000-000000000002",
};

const VEHICLES = {
  assigned: "30000000-0000-4000-8000-000000000001",
  loading: "30000000-0000-4000-8000-000000000002",
  transit: "30000000-0000-4000-8000-000000000003",
  available: "30000000-0000-4000-8000-000000000004",
  maintenance: "30000000-0000-4000-8000-000000000005",
  outOfService: "30000000-0000-4000-8000-000000000006",
  archived: "30000000-0000-4000-8000-000000000007",
};

const DRIVERS = {
  assigned: "20000000-0000-4000-8000-000000000001",
  loading: "20000000-0000-4000-8000-000000000002",
  transit: "20000000-0000-4000-8000-000000000003",
  available: "20000000-0000-4000-8000-000000000004",
  offDuty: "20000000-0000-4000-8000-000000000005",
  inactive: "20000000-0000-4000-8000-000000000006",
  archived: "20000000-0000-4000-8000-000000000007",
};

const USERS = [
  { id: "10000000-0000-4000-8000-000000000001", fullName: "Ana Petrovic", username: "demo.admin", role: "admin", active: true },
  { id: "10000000-0000-4000-8000-000000000002", fullName: "Milan Stojanovic", username: "demo.admin.inactive", role: "admin", active: false },
  { id: "10000000-0000-4000-8000-000000000003", fullName: "Jelena Nikolic", username: "demo.dispatcher", role: "dispatcher", active: true },
  { id: "10000000-0000-4000-8000-000000000101", fullName: "Marko Jovanovic", username: "demo.driver.assigned", role: "driver", active: true, driverId: DRIVERS.assigned, phone: "+381 64 555 0101" },
  { id: "10000000-0000-4000-8000-000000000102", fullName: "Ivana Markovic", username: "demo.driver.loading", role: "driver", active: true, driverId: DRIVERS.loading, phone: "+381 64 555 0102" },
  { id: "10000000-0000-4000-8000-000000000103", fullName: "Nikola Ilic", username: "demo.driver.transit", role: "driver", active: true, driverId: DRIVERS.transit, phone: "+381 64 555 0103" },
  { id: "10000000-0000-4000-8000-000000000104", fullName: "Sara Milosevic", username: "demo.driver.available", role: "driver", active: true, driverId: DRIVERS.available, phone: "+381 64 555 0104" },
  { id: "10000000-0000-4000-8000-000000000105", fullName: "Stefan Pavlovic", username: "demo.driver.offduty", role: "driver", active: true, driverId: DRIVERS.offDuty, phone: "+381 64 555 0105" },
  { id: "10000000-0000-4000-8000-000000000106", fullName: "Tamara Simic", username: "demo.driver.inactive", role: "driver", active: false, driverId: DRIVERS.inactive, phone: "+381 64 555 0106" },
  { id: "10000000-0000-4000-8000-000000000107", fullName: "Vuk Radic", username: "demo.driver.archived", role: "driver", active: true, driverId: DRIVERS.archived, phone: "+381 64 555 0107" },
];

const userByName = Object.fromEntries(USERS.map((user) => [user.username, user]));
const admin = createClient(url, serviceRoleKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });

function createBrowserStyleClient() {
  return createClient(url, publishableKey, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
}

async function rpc(client, functionName, args = undefined) {
  const { data, error } = await client.rpc(functionName, args);
  if (error) throw new Error(`${functionName}: ${error.message}`);
  return data;
}

function runLocalSql(sql) {
  const result = spawnSync("docker", [
    "exec", LOCAL_DATABASE_CONTAINER, "psql", "-v", "ON_ERROR_STOP=1",
    "-At", "-U", "postgres", "-d", "postgres", "-c", sql,
  ], { encoding: "utf8", windowsHide: true });
  if (result.error || result.status !== 0) {
    throw new Error(`Local SQL fixture step failed (${result.error?.message ?? result.stderr.trim() ?? "unknown error"}).`);
  }
  return result.stdout.trim();
}

function tableRows(table, columns = "*") {
  if (!/^[a-z_]+$/u.test(table) || !/^[a-z0-9_,*]+$/u.test(columns)) {
    throw new Error("Unsafe local verification query.");
  }
  const json = runLocalSql(`select coalesce(json_agg(row_to_json(rows)), '[]'::json) from (select ${columns} from public.${table}) rows;`);
  return JSON.parse(json);
}

function belgradeDate() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Belgrade",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function shiftDate(value, days) {
  const date = new Date(`${value}T12:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function currentMonthDate(referenceDate, daysBack) {
  const day = Number(referenceDate.slice(8, 10));
  return shiftDate(referenceDate, -Math.min(daysBack, day - 1));
}

function previousMonthDate(referenceDate, day = 15) {
  const date = new Date(`${referenceDate}T12:00:00.000Z`);
  date.setUTCDate(1);
  date.setUTCMonth(date.getUTCMonth() - 1);
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  date.setUTCDate(Math.min(day, lastDay));
  return date.toISOString().slice(0, 10);
}

function atUtc(date, hour, minute = 0) {
  return `${date}T${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}:00.000Z`;
}

function buildPdf(label) {
  const safeLabel = label.replace(/[()\\]/gu, " ");
  const stream = `BT /F1 18 Tf 72 720 Td (${safeLabel}) Tj ET`;
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    `<< /Length ${Buffer.byteLength(stream, "ascii")} >>\nstream\n${stream}\nendstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];
  let output = "%PDF-1.4\n";
  const offsets = [0];
  for (let index = 0; index < objects.length; index += 1) {
    offsets.push(Buffer.byteLength(output, "ascii"));
    output += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`;
  }
  const xrefOffset = Buffer.byteLength(output, "ascii");
  output += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  output += offsets.slice(1).map((offset) => `${String(offset).padStart(10, "0")} 00000 n \n`).join("");
  output += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`;
  return Buffer.from(output, "ascii");
}

async function internalEmail(username) {
  const localPart = await rpc(admin, "auth_username_local_part", { username });
  if (typeof localPart !== "string" || localPart === "") throw new Error(`Unable to map demo username ${username}.`);
  return `${localPart}@${authDomain}`;
}

async function signIn(user) {
  const client = createBrowserStyleClient();
  const email = await internalEmail(user.username);
  const { data, error } = await client.auth.signInWithPassword({ email, password: demoPassword });
  if (error || !data.session || data.user?.id !== user.id) {
    throw new Error(`${user.username}: demo Auth sign-in failed${error ? ` (${error.message})` : ""}.`);
  }
  return client;
}

async function provisionUser(user) {
  const email = await internalEmail(user.username);
  const temporaryPassword = `${randomBytes(36).toString("base64url")}Aa1!`;
  const { data, error } = await admin.auth.admin.createUser({
    id: user.id,
    email,
    password: temporaryPassword,
    email_confirm: true,
  });
  if (error || data.user?.id !== user.id) throw new Error(`${user.username}: Admin Auth provisioning failed${error ? ` (${error.message})` : ""}.`);

  const verifier = createBrowserStyleClient();
  const signedIn = await verifier.auth.signInWithPassword({ email, password: temporaryPassword });
  if (signedIn.error || signedIn.data.user?.id !== user.id) throw new Error(`${user.username}: temporary credential verification failed.`);
  const updated = await verifier.auth.updateUser({ password: demoPassword });
  if (updated.error) throw new Error(`${user.username}: initial password assignment failed (${updated.error.message}).`);
  await verifier.auth.signOut({ scope: "local" });

  if (user.role === "admin") {
    runLocalSql(`insert into public.profiles (id, full_name, username, role, is_active) values ('${user.id}', '${user.fullName}', '${user.username}', 'admin', ${user.active});`);
    return;
  }

  await rpc(admin, "provision_account_profile", {
    auth_user_id: user.id,
    full_name: user.fullName,
    username: user.username,
    provisioned_role: user.role,
    driver_id: user.driverId ?? null,
  });
}

async function assertCleanResetState() {
  const state = JSON.parse(runLocalSql(`select json_build_object(
    'clients', (select count(*) from public.clients where id = any(array['${Object.values(CLIENTS).join("','")}']::uuid[])),
    'vehicles', (select count(*) from public.vehicles where id = any(array['${Object.values(VEHICLES).join("','")}']::uuid[])),
    'dependent_rows', (
      (select count(*) from public.profiles) + (select count(*) from public.drivers) +
      (select count(*) from public.shipments) + (select count(*) from public.shipment_status_requests) +
      (select count(*) from public.maintenance_records) + (select count(*) from public.documents) +
      (select count(*) from public.expenses) + (select count(*) from public.messages) +
      (select count(*) from public.notifications) + (select count(*) from public.alerts) +
      (select count(*) from public.vehicle_locations) + (select count(*) from public.tracking_history) +
      (select count(*) from public.activity_logs) + (select count(*) from storage.objects)
    )
  );`));
  if (Number(state.clients) !== Object.keys(CLIENTS).length || Number(state.vehicles) !== Object.keys(VEHICLES).length) {
    throw new Error("The SD1 seed foundation is missing. Run `npx supabase db reset --local` first.");
  }
  if (Number(state.dependent_rows) !== 0) {
    throw new Error("Refusing to merge demo fixtures into existing operational or Storage data. Reset the local database first.");
  }

  const { data: authUsers, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (error) throw new Error(`Unable to inspect local Auth state (${error.message}).`);
  const demoIds = new Set(USERS.map((user) => user.id));
  if (authUsers.users.some((user) => demoIds.has(user.id))) {
    throw new Error("Demo Auth identities already exist. Reset the local database before running the bootstrap again.");
  }
}

async function createShipment(operationsClient, referenceDate, input) {
  const pickupDate = input.historical ? previousMonthDate(referenceDate, input.day ?? 15) : currentMonthDate(referenceDate, input.daysBack ?? 0);
  const deliveryDate = shiftDate(pickupDate, input.deliveryDays ?? 1);
  const rows = await rpc(operationsClient, "create_pending_shipment", {
    input_client_id: input.clientId,
    input_pickup_address: input.pickupAddress,
    input_delivery_address: input.deliveryAddress,
    input_pickup_at: atUtc(pickupDate, input.pickupHour ?? 8),
    input_expected_delivery_at: atUtc(deliveryDate, input.deliveryHour ?? 17),
    input_cargo_type: input.cargoType,
    input_price: input.price,
  });
  const shipment = rows[0];
  if (!shipment) throw new Error("create_pending_shipment returned no row.");
  return { ...shipment, pickupDate, historical: Boolean(input.historical) };
}

async function assignShipment(operationsClient, shipment, driverId, vehicleId) {
  await rpc(operationsClient, "assign_pending_shipment", {
    target_shipment_id: shipment.id,
    target_driver_id: driverId,
    target_vehicle_id: vehicleId,
  });
}

function pendingRequestFor(shipmentId) {
  const requestId = runLocalSql(`select id from public.shipment_status_requests where shipment_id='${shipmentId}' and request_state='pending';`);
  if (!requestId) throw new Error(`Pending request unavailable for shipment ${shipmentId}.`);
  return requestId;
}

async function approveTransition(driverClient, operationsClient, shipmentId, status) {
  await rpc(driverClient, "create_shipment_status_request", { requested_status: status });
  const requestId = pendingRequestFor(shipmentId);
  await rpc(operationsClient, "approve_shipment_status_request", { target_request_id: requestId });
}

async function rejectTransition(driverClient, operationsClient, shipmentId, status, reason) {
  await rpc(driverClient, "create_shipment_status_request", { requested_status: status });
  const requestId = pendingRequestFor(shipmentId);
  await rpc(operationsClient, "reject_shipment_status_request", {
    target_request_id: requestId,
    input_rejection_reason: reason,
  });
}

async function uploadDocument(actorClient, input) {
  await rpc(actorClient, "authorize_document_upload_intent", {
    owner_kind: input.ownerKind,
    target_owner_id: input.ownerId,
    input_document_type: input.documentType,
  });
  const path = `${input.ownerKind}/${input.ownerId}/${input.documentId}/${input.fileName}`;
  const { error: uploadError } = await actorClient.storage.from(BUCKET).upload(
    path,
    buildPdf(`${DEMO_PREFIX}: ${input.label}`),
    { contentType: "application/pdf", upsert: false },
  );
  if (uploadError) throw new Error(`${input.fileName}: Storage upload failed (${uploadError.message}).`);
  await rpc(actorClient, "complete_document_upload", {
    target_document_id: input.documentId,
    owner_kind: input.ownerKind,
    target_owner_id: input.ownerId,
    input_document_type: input.documentType,
    input_file_path: path,
    input_file_name: input.fileName,
    input_valid_from: input.validFrom ?? undefined,
    input_valid_until: input.validUntil ?? undefined,
  });
  return path;
}

async function deliverShipment({ operationsClient, driverClient, shipment, driverId, vehicleId, documentId }) {
  await assignShipment(operationsClient, shipment, driverId, vehicleId);
  await approveTransition(driverClient, operationsClient, shipment.id, "loading");
  await approveTransition(driverClient, operationsClient, shipment.id, "in_transit");
  await uploadDocument(driverClient, {
    ownerKind: "shipment",
    ownerId: shipment.id,
    documentId,
    documentType: "proof_of_delivery",
    fileName: `${shipment.tracking_number.toLowerCase()}-pod.pdf`,
    label: `${shipment.tracking_number} proof of delivery`,
  });
  await approveTransition(driverClient, operationsClient, shipment.id, "delivered");
}

async function backdateHistoricalShipment(shipment, referenceDate) {
  const resolvedDate = previousMonthDate(referenceDate, 18);
  const requests = JSON.parse(runLocalSql(`select coalesce(json_agg(row_to_json(rows)), '[]'::json) from (select id from public.shipment_status_requests where shipment_id='${shipment.id}' order by requested_at) rows;`));
  for (let index = 0; index < requests.length; index += 1) {
    const requestedAt = atUtc(resolvedDate, 8 + index * 2);
    const resolvedAt = atUtc(resolvedDate, 9 + index * 2);
    runLocalSql(`update public.shipment_status_requests set requested_at='${requestedAt}', resolved_at='${resolvedAt}' where id='${requests[index].id}'; update public.activity_logs set occurred_at='${resolvedAt}' where status_request_id='${requests[index].id}';`);
  }
  const shipmentTime = atUtc(shipment.pickupDate, 7);
  runLocalSql(`update public.activity_logs set occurred_at='${shipmentTime}' where shipment_id='${shipment.id}'; update public.shipments set created_at='${shipmentTime}' where id='${shipment.id}'; update public.documents set uploaded_at='${atUtc(resolvedDate, 12)}' where shipment_id='${shipment.id}'; update public.tracking_history set recorded_at='${atUtc(resolvedDate, 11)}' where shipment_id='${shipment.id}';`);
}

async function setDriverOperation(operationsClient, driverId, operation) {
  await rpc(operationsClient, "change_driver_operational_status", {
    target_driver_id: driverId,
    requested_operation: operation,
  });
}

async function bootstrap() {
  await assertCleanResetState();
  for (const user of USERS) await provisionUser(user);

  const operationsClient = await signIn(userByName["demo.dispatcher"]);
  const adminClient = await signIn(userByName["demo.admin"]);

  for (const user of USERS.filter((entry) => entry.role === "driver")) {
    const { error } = await adminClient.from("drivers").update({ phone: user.phone }).eq("id", user.driverId);
    if (error) throw new Error(`${user.username}: phone fixture failed (${error.message}).`);
  }

  const driverClients = Object.fromEntries(await Promise.all(
    USERS.filter((user) => user.role === "driver").map(async (user) => [user.driverId, await signIn(user)]),
  ));
  const referenceDate = belgradeDate();

  const shipmentInputs = [
    { key: "pending", clientId: CLIENTS.danube, pickupAddress: "Belgrade distribution centre", deliveryAddress: "Novi Sad retail hub", cargoType: "Chilled produce", price: 980.00, daysBack: 0 },
    { key: "assigned", clientId: CLIENTS.adriatic, pickupAddress: "Novi Sad industrial zone", deliveryAddress: "Subotica assembly plant", cargoType: "Machine components", price: 1420.00, daysBack: 1 },
    { key: "loading", clientId: CLIENTS.danube, pickupAddress: "Belgrade cold store", deliveryAddress: "Kragujevac warehouse", cargoType: "Dairy products", price: 1185.50, daysBack: 0 },
    { key: "transit", clientId: CLIENTS.adriatic, pickupAddress: "Novi Sad freight terminal", deliveryAddress: "Nis production facility", cargoType: "Industrial fasteners", price: 2360.75, daysBack: 1, deliveryDays: 2 },
    { key: "deliveredZero", clientId: CLIENTS.danube, pickupAddress: "Belgrade produce market", deliveryAddress: "Pancevo supermarket depot", cargoType: "Fresh vegetables", price: 1250.00, daysBack: 1 },
    { key: "deliveredExpenses", clientId: CLIENTS.adriatic, pickupAddress: "Novi Sad factory", deliveryAddress: "Cacak service centre", cargoType: "Hydraulic assemblies", price: 2400.00, daysBack: 1 },
    { key: "deliveredSecondClient", clientId: CLIENTS.danube, pickupAddress: "Zemun cold store", deliveryAddress: "Smederevo distribution hub", cargoType: "Packaged foods", price: 1800.00, daysBack: 0 },
    { key: "cancelled", clientId: CLIENTS.adriatic, pickupAddress: "Novi Sad industrial zone", deliveryAddress: "Uzice parts depot", cargoType: "Steel fittings", price: 1525.00, daysBack: 0 },
    { key: "historicalDelivered", clientId: CLIENTS.adriatic, pickupAddress: "Novi Sad factory", deliveryAddress: "Belgrade service centre", cargoType: "Replacement tooling", price: 950.00, historical: true, day: 14 },
    { key: "historicalCancelled", clientId: CLIENTS.danube, pickupAddress: "Belgrade distribution centre", deliveryAddress: "Valjevo retail hub", cargoType: "Seasonal produce", price: 875.00, historical: true, day: 9 },
  ];
  const shipments = {};
  for (const input of shipmentInputs) shipments[input.key] = await createShipment(operationsClient, referenceDate, input);

  await assignShipment(operationsClient, shipments.assigned, DRIVERS.assigned, VEHICLES.assigned);
  await rejectTransition(driverClients[DRIVERS.assigned], operationsClient, shipments.assigned.id, "loading", "Pickup bay is not yet ready.");

  await assignShipment(operationsClient, shipments.loading, DRIVERS.loading, VEHICLES.loading);
  await approveTransition(driverClients[DRIVERS.loading], operationsClient, shipments.loading.id, "loading");

  await assignShipment(operationsClient, shipments.transit, DRIVERS.transit, VEHICLES.transit);
  await approveTransition(driverClients[DRIVERS.transit], operationsClient, shipments.transit.id, "loading");
  await approveTransition(driverClients[DRIVERS.transit], operationsClient, shipments.transit.id, "in_transit");
  const transitUpdatedAt = runLocalSql(`select updated_at from public.shipments where id='${shipments.transit.id}';`);
  if (!transitUpdatedAt) throw new Error("Unable to read in-transit fixture.");
  await rpc(operationsClient, "set_shipment_delayed", {
    target_shipment_id: shipments.transit.id,
    target_delayed: true,
    expected_updated_at: transitUpdatedAt,
  });

  await deliverShipment({ operationsClient, driverClient: driverClients[DRIVERS.available], shipment: shipments.deliveredZero, driverId: DRIVERS.available, vehicleId: VEHICLES.available, documentId: "50000000-0000-4000-8000-000000000001" });
  await deliverShipment({ operationsClient, driverClient: driverClients[DRIVERS.offDuty], shipment: shipments.deliveredExpenses, driverId: DRIVERS.offDuty, vehicleId: VEHICLES.available, documentId: "50000000-0000-4000-8000-000000000002" });
  await deliverShipment({ operationsClient, driverClient: driverClients[DRIVERS.inactive], shipment: shipments.deliveredSecondClient, driverId: DRIVERS.inactive, vehicleId: VEHICLES.available, documentId: "50000000-0000-4000-8000-000000000003" });

  await assignShipment(operationsClient, shipments.cancelled, DRIVERS.archived, VEHICLES.available);
  await rpc(operationsClient, "cancel_shipment", { target_shipment_id: shipments.cancelled.id });

  await deliverShipment({ operationsClient, driverClient: driverClients[DRIVERS.available], shipment: shipments.historicalDelivered, driverId: DRIVERS.available, vehicleId: VEHICLES.available, documentId: "50000000-0000-4000-8000-000000000004" });
  await backdateHistoricalShipment(shipments.historicalDelivered, referenceDate);

  await assignShipment(operationsClient, shipments.historicalCancelled, DRIVERS.available, VEHICLES.available);
  await rpc(operationsClient, "cancel_shipment", { target_shipment_id: shipments.historicalCancelled.id });
  const historicalCancelledTime = atUtc(previousMonthDate(referenceDate, 10), 14);
  runLocalSql(`update public.activity_logs set occurred_at='${historicalCancelledTime}' where shipment_id='${shipments.historicalCancelled.id}'; update public.shipments set created_at='${historicalCancelledTime}' where id='${shipments.historicalCancelled.id}';`);

  const expenseDate = currentMonthDate(referenceDate, 0);
  const expenseFixtures = [
    ["fuel", 321.45, "Fuel receipt for the Belgrade-Cacak route."],
    ["toll", 48.60, "Motorway tolls"],
    ["driver", 175.25, "Driver allowance"],
    ["maintenance", 89.90, "Emergency lamp replacement"],
    ["other", 22.15, "   "],
  ];
  for (const [category, amount, description] of expenseFixtures) {
    await rpc(operationsClient, "create_shipment_expense", {
      target_shipment_id: shipments.deliveredExpenses.id,
      input_category: category,
      input_amount: amount,
      input_expense_date: expenseDate,
      input_description: description,
    });
  }

  await rpc(adminClient, "create_maintenance_record", {
    target_vehicle_id: VEHICLES.maintenance,
    input_service_type: "Preventive service and inspection",
    input_service_date: currentMonthDate(referenceDate, 1),
    input_mileage_at_service: 140900,
    input_workshop: "Dunav Fleet Service",
    input_cost: 842.75,
    input_notes: "Oil, filters, and safety inspection completed.",
    input_next_service_date: shiftDate(referenceDate, 7),
    input_next_service_mileage: 150000,
  });
  await rpc(adminClient, "create_maintenance_record", {
    target_vehicle_id: VEHICLES.available,
    input_service_type: "Brake system inspection",
    input_service_date: currentMonthDate(referenceDate, 1),
    input_mileage_at_service: 97550,
    input_workshop: "Beograd Commercial Vehicles",
    input_cost: 315.40,
    input_notes: "Pads remain serviceable; recheck at the next mileage threshold.",
    input_next_service_date: shiftDate(referenceDate, 180),
    input_next_service_mileage: 98300,
  });
  await rpc(adminClient, "create_maintenance_record", {
    target_vehicle_id: VEHICLES.outOfService,
    input_service_type: "Transmission diagnostic",
    input_service_date: previousMonthDate(referenceDate, 12),
    input_mileage_at_service: 288100,
    input_workshop: "Central Truck Diagnostics",
    input_cost: 1290.00,
    input_notes: "Historical diagnostic; repair decision pending.",
  });

  await setDriverOperation(adminClient, DRIVERS.offDuty, "mark_off_duty");
  await rpc(admin, "set_managed_account_active_state", { target_username: "demo.driver.inactive", requested_active: false });
  await setDriverOperation(adminClient, DRIVERS.archived, "archive");

  await uploadDocument(adminClient, {
    ownerKind: "vehicle", ownerId: VEHICLES.available,
    documentId: "50000000-0000-4000-8000-000000000101",
    documentType: "registration", fileName: "bg-404-registration.pdf",
    label: "BG-404-LF registration (non-expiring demo metadata)",
    validFrom: shiftDate(referenceDate, -365),
  });
  await uploadDocument(adminClient, {
    ownerKind: "vehicle", ownerId: VEHICLES.maintenance,
    documentId: "50000000-0000-4000-8000-000000000102",
    documentType: "insurance", fileName: "ni-505-insurance.pdf",
    label: "NI-505-LF insurance expiring soon",
    validFrom: shiftDate(referenceDate, -355), validUntil: shiftDate(referenceDate, 10),
  });
  await uploadDocument(adminClient, {
    ownerKind: "driver", ownerId: DRIVERS.offDuty,
    documentId: "50000000-0000-4000-8000-000000000103",
    documentType: "driving_license", fileName: "stefan-pavlovic-license.pdf",
    label: "Expired driving licence example",
    validFrom: shiftDate(referenceDate, -367), validUntil: shiftDate(referenceDate, -2),
  });

  const readMessage = await rpc(operationsClient, "send_driver_message", {
    target_driver_id: DRIVERS.available,
    target_shipment_id: null,
    input_body: "Please confirm tomorrow's availability with Dispatch.",
  });
  await rpc(driverClients[DRIVERS.available], "acknowledge_driver_message", { message_id: readMessage[0].message_id });
  await rpc(driverClients[DRIVERS.available], "acknowledge_notification", { notification_id: readMessage[0].notification_id });
  await rpc(operationsClient, "send_driver_message", {
    target_driver_id: DRIVERS.transit,
    target_shipment_id: shipments.transit.id,
    input_body: "Delay noted. Continue safely and send the next checkpoint update.",
  });

  console.log(`${DEMO_PREFIX} bootstrap completed with seed reference date ${referenceDate} (Europe/Belgrade).`);
}

function assert(condition, message) {
  if (!condition) throw new Error(`Verification failed: ${message}`);
}

function groupCount(rows, field) {
  return rows.reduce((counts, row) => ({ ...counts, [row[field]]: (counts[row[field]] ?? 0) + 1 }), {});
}

async function verify() {
  const referenceDate = belgradeDate();
  const adminClient = await signIn(userByName["demo.admin"]);
  const dispatcherClient = await signIn(userByName["demo.dispatcher"]);
  const driverClient = await signIn(userByName["demo.driver.transit"]);
  const inactiveClient = await signIn(userByName["demo.admin.inactive"]);

  const { data: inactiveProfile, error: inactiveProfileError } = await inactiveClient.from("profiles").select("is_active").eq("id", userByName["demo.admin.inactive"].id).single();
  assert(!inactiveProfileError && inactiveProfile?.is_active === false, "inactive Auth identity must resolve only to an inactive profile");

  const profiles = tableRows("profiles", "id,role,is_active");
  const drivers = tableRows("drivers", "id,status,profile_id");
  const clients = tableRows("clients", "id,status");
  const vehicles = tableRows("vehicles", "id,status");
  const shipments = tableRows("shipments", "id,status,delayed,driver_id,vehicle_id,price,pickup_at");
  const requests = tableRows("shipment_status_requests", "id,shipment_id,current_status,requested_status,request_state,resolved_at");
  const expenses = tableRows("expenses", "shipment_id,category,amount,description");
  const maintenance = tableRows("maintenance_records", "vehicle_id,service_date,cost,next_service_date,next_service_mileage");
  const documents = tableRows("documents", "id,shipment_id,vehicle_id,driver_id,file_path,valid_until,lifecycle_status");
  const alerts = tableRows("alerts", "alert_type,alert_state,shipment_id,vehicle_id,document_id");
  const messages = tableRows("messages", "recipient_driver_id,read_at,shipment_id");
  const notifications = tableRows("notifications", "recipient_profile_id,read_at,notification_type");
  const locations = tableRows("vehicle_locations", "vehicle_id,shipment_id");
  const tracking = tableRows("tracking_history", "vehicle_id,shipment_id");
  const activities = tableRows("activity_logs", "action_type,shipment_id,status_request_id,document_id,maintenance_record_id,expense_id");

  assert(profiles.length === 10, "expected 10 profiles (2 Admin, 1 Dispatcher, 7 Drivers)");
  assert(groupCount(profiles, "role").admin === 2 && groupCount(profiles, "role").dispatcher === 1 && groupCount(profiles, "role").driver === 7, "profile role inventory mismatch");
  assert(profiles.filter((profile) => !profile.is_active).length === 2, "expected inactive Admin and inactive Driver profiles");
  assert(drivers.length === 7, "expected seven coherent Driver status fixtures");
  assert(JSON.stringify(groupCount(drivers, "status")) === JSON.stringify({ assigned: 3, available: 1, off_duty: 1, inactive: 1, archived: 1 }), "Driver status inventory mismatch");
  assert(clients.length === 2 && clients.every((client) => client.status === "active"), "Client inventory mismatch");
  assert(vehicles.length === 7, "expected seven coherent Vehicle state fixtures");
  const vehicleCounts = groupCount(vehicles, "status");
  assert(vehicleCounts.in_use === 3 && vehicleCounts.available === 1 && vehicleCounts.maintenance === 1 && vehicleCounts.out_of_service === 1 && vehicleCounts.archived === 1, "Vehicle status inventory mismatch");
  assert(shipments.length === 10, "expected ten curated Shipments");
  const shipmentCounts = groupCount(shipments, "status");
  assert(shipmentCounts.pending === 1 && shipmentCounts.assigned === 1 && shipmentCounts.loading === 1 && shipmentCounts.in_transit === 1 && shipmentCounts.delivered === 4 && shipmentCounts.cancelled === 2, "Shipment status inventory mismatch");
  assert(shipments.filter((shipment) => shipment.delayed).length === 1 && shipments.find((shipment) => shipment.delayed)?.status === "in_transit", "delayed must be a boolean condition on one in-transit Shipment");

  const active = shipments.filter((shipment) => ["assigned", "loading", "in_transit"].includes(shipment.status));
  for (const shipment of active) {
    assert(drivers.find((driver) => driver.id === shipment.driver_id)?.status === "assigned", "active Shipment Driver must be assigned");
    assert(vehicles.find((vehicle) => vehicle.id === shipment.vehicle_id)?.status === "in_use", "active Shipment Vehicle must be in use");
  }
  assert(new Set(active.map((shipment) => shipment.driver_id)).size === active.length, "active Driver assignments must be unique");
  assert(new Set(active.map((shipment) => shipment.vehicle_id)).size === active.length, "active Vehicle assignments must be unique");
  assert(requests.some((request) => request.request_state === "rejected"), "expected a coherent rejected status request");
  assert(requests.filter((request) => request.request_state === "approved").every((request) => request.resolved_at), "approved requests must be resolved");
  assert(activities.length > 0 && activities.every((activity) => [activity.shipment_id, activity.status_request_id, activity.document_id, activity.maintenance_record_id, activity.expense_id].filter(Boolean).length <= 1), "activity history must retain one primary entity");

  assert(expenses.length === 5, "expected five curated expenses");
  assert(new Set(expenses.map((expense) => expense.category)).size === 5, "all approved expense categories must be represented");
  assert(expenses.some((expense) => expense.description === null), "blank optional expense description must normalize to null");
  const expenseShipmentId = expenses[0].shipment_id;
  assert(expenses.every((expense) => expense.shipment_id === expenseShipmentId), "multiple expenses must belong to one delivered scenario");
  const deliveredWithoutExpenses = shipments.filter((shipment) => shipment.status === "delivered").some((shipment) => !expenses.some((expense) => expense.shipment_id === shipment.id));
  assert(deliveredWithoutExpenses, "at least one delivered Shipment must have zero expenses");
  const financialRows = await rpc(dispatcherClient, "get_operations_shipment_financial_detail", { target_shipment_id: expenseShipmentId });
  assert(Number(financialRows[0]?.total_expenses) === 657.35 && Number(financialRows[0]?.profit) === 1742.65, "F1 derived financial summary mismatch");

  const reportFrom = `${referenceDate.slice(0, 8)}01`;
  const report = await rpc(adminClient, "get_admin_reports", { report_from: reportFrom, report_to: referenceDate });
  assert(Number(report.financial.completed_shipments) === 3, "R1 must contain three current-period completions");
  assert(Number(report.financial.revenue) === 5450 && Number(report.financial.total_expenses) === 657.35 && Number(report.financial.profit) === 4792.65, "R1 financial reconciliation mismatch");
  assert(Number(report.shipments.scheduled_shipments) >= 8, "R1 pickup cohort must be populated");
  assert(report.clients.length === 2 && report.drivers.completions.length === 3, "R1 Client and Driver sections must be populated");
  assert(Number(report.fleet.maintenance.records) >= 2 && Number(report.fleet.maintenance.recorded_cost) === 1158.15, "R1 maintenance summary mismatch");

  assert(maintenance.length === 3, "expected three maintenance records");
  assert(documents.length === 7 && documents.every((document) => document.lifecycle_status === "active"), "expected four POD and three active representative documents");
  assert(alerts.some((alert) => alert.alert_type === "shipment_delayed" && alert.alert_state === "active"), "delayed Shipment alert missing");
  assert(alerts.some((alert) => alert.alert_type === "document_expiring" && alert.alert_state === "active"), "expiring document alert missing");
  assert(alerts.some((alert) => alert.alert_type === "document_expired" && alert.alert_state === "active"), "expired document alert missing");
  assert(alerts.some((alert) => alert.alert_type === "maintenance_due_date" && alert.alert_state === "active"), "maintenance date alert missing");
  assert(alerts.some((alert) => alert.alert_type === "maintenance_due_mileage" && alert.alert_state === "active"), "maintenance mileage alert missing");
  assert(messages.length === 2 && messages.some((message) => message.read_at) && messages.some((message) => !message.read_at), "message read/unread states mismatch");
  assert(notifications.some((notification) => notification.read_at) && notifications.some((notification) => !notification.read_at), "notification read/unread states mismatch");
  assert(locations.length === 1 && tracking.length >= 1, "tracking must retain one current in-transit location and minimal workflow history");

  const { data: storedObjects, error: storageError } = await admin.storage.from(BUCKET).list("", { limit: 100, search: "" });
  assert(!storageError && storedObjects !== null, "private document bucket must be readable by the local service client");
  const sampleDocument = documents[0];
  const { data: signed, error: signedError } = await admin.storage.from(BUCKET).createSignedUrl(sampleDocument.file_path, 60);
  assert(!signedError && Boolean(signed?.signedUrl), "seeded document must have a real downloadable Storage object");

  const dispatcherReport = await dispatcherClient.rpc("get_admin_reports", { report_from: reportFrom, report_to: referenceDate });
  assert(Boolean(dispatcherReport.error), "Dispatcher must remain denied Admin Reports");
  const driverFinance = await driverClient.rpc("get_operations_shipment_financial_detail", { target_shipment_id: expenseShipmentId });
  assert(Boolean(driverFinance.error), "Driver must remain denied Shipment financial detail");

  const summary = {
    seedReferenceDate: referenceDate,
    counts: {
      profiles: profiles.length, drivers: drivers.length, clients: clients.length,
      vehicles: vehicles.length, shipments: shipments.length, expenses: expenses.length,
      maintenanceRecords: maintenance.length, documents: documents.length,
      messages: messages.length, notifications: notifications.length,
      alerts: alerts.length, activityLogs: activities.length,
      currentVehicleLocations: locations.length, trackingHistory: tracking.length,
    },
    shipmentStatuses: shipmentCounts,
    driverStatuses: groupCount(drivers, "status"),
    vehicleStatuses: vehicleCounts,
    currentMonthFinancials: report.financial,
    accessBoundaries: { dispatcherAdminReportsDenied: true, driverFinancialsDenied: true, inactiveProfileDeniedByApplicationContract: true },
  };
  console.log(`${DEMO_PREFIX} verification passed.\n${JSON.stringify(summary, null, 2)}`);
}

async function main() {
  if (!VERIFY_ONLY) await bootstrap();
  await verify();
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
