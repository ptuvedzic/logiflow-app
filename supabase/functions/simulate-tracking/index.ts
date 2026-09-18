declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};

function isSchedulerAuthorized(request: Request, expectedSecret: string | undefined) {
  return expectedSecret !== undefined && expectedSecret.length > 0 && request.headers.get("authorization") === `Bearer ${expectedSecret}`;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } });
}

async function rpc(name: string, body: Record<string, unknown> = {}) {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST", headers: { apikey: key, authorization: `Bearer ${key}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error("tracking_rpc_failed");
  return response.json() as Promise<unknown>;
}

export async function handleSimulateTracking(request: Request): Promise<Response> {
  const correlationId = request.headers.get("x-correlation-id") ?? crypto.randomUUID();
  const invocationId = crypto.randomUUID();
  if (!isSchedulerAuthorized(request, Deno.env.get("SCHEDULER_SHARED_SECRET"))) {
    return jsonResponse({ error: "Authentication required.", correlationId }, 401);
  }
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed.", correlationId }, 405);

  try {
    const routeResponse = await fetch(Deno.env.get("TRACKING_ROUTE_GEOJSON_URL") ?? "", {
      headers: { accept: "application/geo+json, application/json" },
    });
    if (!routeResponse.ok) throw new Error("tracking_route_unavailable");
    const shared = await import("../_shared/tracking-route" + ".ts") as typeof import("../_shared/tracking-route");
    const coordinates = shared.parseTrackingRoute(await routeResponse.json());
    const listData = await rpc("list_tracking_simulation_shipments");
    if (!Array.isArray(listData)) throw new Error("tracking_batch_unavailable");

    const counts = { processed: 0, skipped: 0, heartbeat: 0, failed: 0 };
    for (const row of listData) {
      if (typeof row !== "object" || row === null || !("shipment_id" in row) || typeof row.shipment_id !== "string") {
        counts.failed += 1; continue;
      }
      let stepData: unknown;
      try { stepData = await rpc("simulate_tracking_step", {
        target_shipment_id: row.shipment_id,
        route_coordinates: coordinates,
      }); } catch { stepData = null; }
      if (!Array.isArray(stepData) || typeof stepData[0] !== "object" || stepData[0] === null ||
          !("step_result" in stepData[0]) || typeof stepData[0].step_result !== "string") {
        counts.failed += 1;
        console.error(JSON.stringify({ operation: "simulate_tracking_step", correlationId, invocationId,
          shipmentId: row.shipment_id, outcome: "failed", category: "infrastructure" }));
        continue;
      }
      const result = stepData[0].step_result;
      if (result === "advanced") counts.processed += 1;
      else if (result === "heartbeat") counts.heartbeat += 1;
      else counts.skipped += 1;
    }
    console.log(JSON.stringify({ operation: "simulate_tracking", correlationId, invocationId,
      outcome: "success", ...counts }));
    return jsonResponse({ correlationId, invocationId, ...counts });
  } catch {
    console.error(JSON.stringify({ operation: "simulate_tracking", correlationId, invocationId,
      outcome: "failed", category: "infrastructure" }));
    return jsonResponse({ error: "Tracking simulation unavailable.", correlationId }, 503);
  }
}

Deno.serve(handleSimulateTracking);
