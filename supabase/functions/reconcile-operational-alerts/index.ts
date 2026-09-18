declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};

declare global {
  interface ImportMeta { readonly main: boolean }
}

function isSchedulerAuthorized(request: Request, expectedSecret: string | undefined) {
  return expectedSecret !== undefined && expectedSecret.length > 0 && request.headers.get("authorization") === `Bearer ${expectedSecret}`;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } });
}

type RpcRow = Record<string, unknown>;

async function callRpc(url: string, key: string, functionName: string, body: Record<string, unknown>) {
  return fetch(`${url}/rest/v1/rpc/${functionName}`, {
    method: "POST",
    headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

function firstRow(value: unknown): RpcRow | null {
  return Array.isArray(value) && typeof value[0] === "object" && value[0] !== null
    ? value[0] as RpcRow
    : null;
}

async function reconcileStaleLocations(url: string, key: string) {
  const response = await callRpc(url, key, "reconcile_stale_vehicle_locations", {});
  if (!response.ok) throw new Error("alert_reconciliation_unavailable");
  const row = firstRow(await response.json());
  if (row === null || typeof row.created_count !== "number" || typeof row.resolved_count !== "number") {
    throw new Error("alert_reconciliation_unavailable");
  }
  return { created: row.created_count, resolved: row.resolved_count };
}

async function reconcileMaintenance(url: string, key: string) {
  let cursor: string | null = null;
  let processed = 0;
  let created = 0;
  let resolved = 0;
  let updated = 0;
  let skipped = 0;
  let failed = 0;

  do {
    const listResponse = await callRpc(url, key, "list_maintenance_alert_vehicle_ids", { after_vehicle_id: cursor });
    if (!listResponse.ok) throw new Error("alert_reconciliation_unavailable");
    const listData = await listResponse.json() as unknown;
    if (!Array.isArray(listData) || listData.some((row) => typeof row !== "object" || row === null || typeof (row as RpcRow).vehicle_id !== "string")) {
      throw new Error("alert_reconciliation_unavailable");
    }
    const vehicleIds = listData.map((row) => (row as RpcRow).vehicle_id as string);
    for (const vehicleId of vehicleIds) {
      try {
        const reconcileResponse = await callRpc(url, key, "reconcile_vehicle_maintenance_alerts", {
          target_vehicle_id: vehicleId,
          lifecycle_actor_profile_id: null,
        });
        if (!reconcileResponse.ok) throw new Error("vehicle_reconciliation_failed");
        const row = firstRow(await reconcileResponse.json());
        if (row === null || typeof row.created_count !== "number" || typeof row.resolved_count !== "number" || typeof row.updated_count !== "number") {
          throw new Error("vehicle_reconciliation_failed");
        }
        created += row.created_count;
        resolved += row.resolved_count;
        updated += row.updated_count;
        if (row.created_count === 0 && row.resolved_count === 0 && row.updated_count === 0) skipped += 1;
      } catch {
        failed += 1;
      }
      processed += 1;
    }
    cursor = vehicleIds.at(-1) ?? null;
    if (vehicleIds.length < 50) break;
  } while (cursor !== null);

  return { processed, skipped, created, resolved, updated, failed };
}

async function reconcileDocuments(url: string, key: string) {
  let cursor: string | null = null;
  let processed = 0; let created = 0; let resolved = 0; let updated = 0; let skipped = 0; let failed = 0;
  do {
    const listResponse = await callRpc(url, key, "list_document_alert_ids", { after_document_id: cursor });
    if (!listResponse.ok) throw new Error("alert_reconciliation_unavailable");
    const listData = await listResponse.json() as unknown;
    if (!Array.isArray(listData) || listData.some((row) => typeof row !== "object" || row === null || typeof (row as RpcRow).document_id !== "string")) throw new Error("alert_reconciliation_unavailable");
    const documentIds = listData.map((row) => (row as RpcRow).document_id as string);
    for (const documentId of documentIds) {
      try {
        const response = await callRpc(url, key, "reconcile_document_expiry_alerts", { target_document_id: documentId, lifecycle_actor_profile_id: null });
        if (!response.ok) throw new Error("document_reconciliation_failed");
        const row = firstRow(await response.json());
        if (row === null || typeof row.created_count !== "number" || typeof row.resolved_count !== "number" || typeof row.updated_count !== "number") throw new Error("document_reconciliation_failed");
        created += row.created_count; resolved += row.resolved_count; updated += row.updated_count;
        if (row.created_count === 0 && row.resolved_count === 0 && row.updated_count === 0) skipped += 1;
      } catch { failed += 1; }
      processed += 1;
    }
    cursor = documentIds.at(-1) ?? null;
    if (documentIds.length < 50) break;
  } while (cursor !== null);
  return { processed, skipped, created, resolved, updated, failed };
}

async function cleanupDocumentUploads(url: string, key: string) {
  let cursor: string | null = null; let processed = 0; let deleted = 0; let failed = 0;
  do {
    const listResponse = await callRpc(url, key, "list_abandoned_document_objects", { after_object_name: cursor });
    if (!listResponse.ok) throw new Error("document_cleanup_unavailable");
    const listData = await listResponse.json() as unknown;
    if (!Array.isArray(listData) || listData.some((row) => typeof row !== "object" || row === null || typeof (row as RpcRow).object_name !== "string")) throw new Error("document_cleanup_unavailable");
    const names = listData.map((row) => (row as RpcRow).object_name as string);
    for (const name of names) {
      try {
        const response = await fetch(`${url}/storage/v1/object/documents/${name.split("/").map(encodeURIComponent).join("/")}`, { method: "DELETE", headers: { apikey: key, authorization: `Bearer ${key}` } });
        if (!response.ok) throw new Error("document_cleanup_failed");
        deleted += 1;
      } catch { failed += 1; }
      processed += 1;
    }
    cursor = names.at(-1) ?? null;
    if (names.length < 50) break;
  } while (cursor !== null);
  return { processed, deleted, failed };
}

export async function handleReconcileOperationalAlerts(request: Request): Promise<Response> {
  const correlationId = request.headers.get("x-correlation-id") ?? crypto.randomUUID();
  if (!isSchedulerAuthorized(request, Deno.env.get("SCHEDULER_SHARED_SECRET"))) {
    return jsonResponse({ error: "Authentication required.", correlationId }, 401);
  }
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed.", correlationId }, 405);
  try {
    let requestBody: unknown;
    try {
      requestBody = await request.json() as unknown;
    } catch {
      return jsonResponse({ error: "Invalid reconciliation job.", correlationId }, 400);
    }
    if (typeof requestBody !== "object" || requestBody === null || !("job" in requestBody)) {
      return jsonResponse({ error: "Invalid reconciliation job.", correlationId }, 400);
    }
    const job = (requestBody as RpcRow).job;
    if (job !== "stale_vehicle_locations" && job !== "maintenance" && job !== "documents" && job !== "document_upload_cleanup") {
      return jsonResponse({ error: "Invalid reconciliation job.", correlationId }, 400);
    }
    const url = Deno.env.get("SUPABASE_URL") ?? "";
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const result = job === "maintenance" ? await reconcileMaintenance(url, key)
      : job === "documents" ? await reconcileDocuments(url, key)
      : job === "document_upload_cleanup" ? await cleanupDocumentUploads(url, key)
      : await reconcileStaleLocations(url, key);
    return jsonResponse({ correlationId, ...result });
  } catch {
    return jsonResponse({ error: "Alert reconciliation unavailable.", correlationId }, 503);
  }
}

if (import.meta.main) Deno.serve(handleReconcileOperationalAlerts);
