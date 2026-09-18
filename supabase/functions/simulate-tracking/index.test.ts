declare const Deno: { test(name: string, callback: () => void | Promise<void>): void };
export {};

function assert(value: boolean) { if (!value) throw new Error("assertion_failed"); }

Deno.test("accepts the approved route endpoints", async () => {
  const { parseTrackingRoute } = await import("../_shared/tracking-route" + ".ts") as typeof import("../_shared/tracking-route");
  const route = parseTrackingRoute({ type: "Feature", geometry: { type: "LineString", coordinates: [[19.8335, 45.2671], [20.4489, 44.7866]] } });
  assert(route.length === 2);
});

Deno.test("rejects a route with different endpoints", async () => {
  const { parseTrackingRoute } = await import("../_shared/tracking-route" + ".ts") as typeof import("../_shared/tracking-route");
  let rejected = false;
  try { parseTrackingRoute({ type: "Feature", geometry: { type: "LineString", coordinates: [[0, 0], [1, 1]] } }); } catch { rejected = true; }
  assert(rejected);
});
