declare const Deno: { env: { set(name: string, value: string): void }; test(name: string, callback: () => void | Promise<void>): void };

async function handleReconcileOperationalAlerts(request: Request) {
  const loadedModule = await import("./index" + ".ts") as typeof import("./index");
  return loadedModule.handleReconcileOperationalAlerts(request);
}

function assert(value: boolean) { if (!value) throw new Error("assertion_failed"); }
function json(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status, headers: { "content-type": "application/json" } }); }
function request(body: unknown, secret = "expected") { return new Request("http://local", { method: "POST", headers: { authorization: `Bearer ${secret}`, "content-type": "application/json", "x-correlation-id": "test-correlation" }, body: JSON.stringify(body) }); }
function configure() { Deno.env.set("SCHEDULER_SHARED_SECRET", "expected"); Deno.env.set("SUPABASE_URL", "http://supabase.local"); Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "service-key"); }

Deno.test("authentication and job validation precede RPC access", async () => {
  configure(); let calls = 0; const originalFetch = globalThis.fetch;
  globalThis.fetch = (() => { calls += 1; return Promise.resolve(json([])); }) as typeof fetch;
  try {
    assert((await handleReconcileOperationalAlerts(request({ job: "maintenance" }, "wrong"))).status === 401);
    assert((await handleReconcileOperationalAlerts(new Request("http://local", { method: "GET", headers: { authorization: "Bearer expected" } }))).status === 405);
    assert((await handleReconcileOperationalAlerts(request({ job: "unknown" }))).status === 400);
    assert(calls === 0);
  } finally { globalThis.fetch = originalFetch; }
});

Deno.test("stale-location dispatch preserves counters", async () => {
  configure(); const originalFetch = globalThis.fetch;
  globalThis.fetch = (() => Promise.resolve(json([{ created_count: 2, resolved_count: 1 }]))) as typeof fetch;
  try {
    const response = await handleReconcileOperationalAlerts(request({ job: "stale_vehicle_locations" })); const body = await response.json();
    assert(response.status === 200 && body.correlationId === "test-correlation" && body.created === 2 && body.resolved === 1);
  } finally { globalThis.fetch = originalFetch; }
});

Deno.test("maintenance dispatch paginates and isolates vehicle failures", async () => {
  configure();
  const ids = Array.from({ length: 51 }, (_, index) => `00000000-0000-0000-0000-${String(index + 1).padStart(12, "0")}`);
  const originalFetch = globalThis.fetch; let listCalls = 0;
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith("list_maintenance_alert_vehicle_ids")) {
      const payload = JSON.parse(String(init?.body)) as { after_vehicle_id: string | null };
      const start = payload.after_vehicle_id === null ? 0 : 50; listCalls += 1;
      return Promise.resolve(json(ids.slice(start, start + 50).map((vehicle_id) => ({ vehicle_id }))));
    }
    const payload = JSON.parse(String(init?.body)) as { target_vehicle_id: string };
    if (payload.target_vehicle_id === ids[10]) return Promise.resolve(json({ error: "safe" }, 500));
    return Promise.resolve(json([{ created_count: 1, resolved_count: 0, updated_count: 0 }]));
  }) as typeof fetch;
  try {
    const response = await handleReconcileOperationalAlerts(request({ job: "maintenance" })); const body = await response.json();
    assert(response.status === 200 && listCalls === 2 && body.processed === 51 && body.skipped === 0 && body.created === 50 && body.failed === 1);
  } finally { globalThis.fetch = originalFetch; }
});

Deno.test("list failure is safely translated", async () => {
  configure(); const originalFetch = globalThis.fetch;
  globalThis.fetch = (() => Promise.resolve(json({ details: "secret" }, 500))) as typeof fetch;
  try {
    const response = await handleReconcileOperationalAlerts(request({ job: "maintenance" })); const body = await response.json();
    assert(response.status === 503 && body.error === "Alert reconciliation unavailable." && !JSON.stringify(body).includes("secret"));
  } finally { globalThis.fetch = originalFetch; }
});

Deno.test("documents dispatch paginates and isolates failures", async () => {
  configure(); const ids = Array.from({ length: 51 }, (_, index) => `10000000-0000-0000-0000-${String(index + 1).padStart(12, "0")}`);
  const originalFetch = globalThis.fetch; let listCalls = 0;
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith("list_document_alert_ids")) { const body = JSON.parse(String(init?.body)) as { after_document_id: string | null }; listCalls += 1; return Promise.resolve(json(ids.slice(body.after_document_id === null ? 0 : 50, body.after_document_id === null ? 50 : 100).map((document_id) => ({ document_id })))); }
    const body = JSON.parse(String(init?.body)) as { target_document_id: string };
    return Promise.resolve(body.target_document_id === ids[3] ? json({}, 500) : json([{ created_count: 1, resolved_count: 0, updated_count: 0 }]));
  }) as typeof fetch;
  try { const response = await handleReconcileOperationalAlerts(request({ job: "documents" })); const body = await response.json(); assert(response.status === 200 && listCalls === 2 && body.processed === 51 && body.created === 50 && body.failed === 1); }
  finally { globalThis.fetch = originalFetch; }
});

Deno.test("document cleanup deletes exact encoded objects with failure isolation", async () => {
  configure(); const originalFetch = globalThis.fetch; let listed = false;
  globalThis.fetch = ((input: string | URL | Request) => { const url = String(input); if (url.endsWith("list_abandoned_document_objects")) { if (listed) return Promise.resolve(json([])); listed = true; return Promise.resolve(json([{ object_name: "shipment/a/file one.pdf" }, { object_name: "driver/b/fail.pdf" }])); } return Promise.resolve(url.includes("fail.pdf") ? json({}, 500) : json({})); }) as typeof fetch;
  try { const response = await handleReconcileOperationalAlerts(request({ job: "document_upload_cleanup" })); const body = await response.json(); assert(response.status === 200 && body.processed === 2 && body.deleted === 1 && body.failed === 1); }
  finally { globalThis.fetch = originalFetch; }
});
