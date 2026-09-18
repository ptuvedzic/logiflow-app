import { getAuthorizedTrackingLocations } from "@/lib/dal/tracking";

export async function GET() {
  const correlationId = crypto.randomUUID();
  const result = await getAuthorizedTrackingLocations();
  if (result.ok) return Response.json({ locations: result.data, correlationId }, { headers: { "cache-control": "no-store" } });
  const status = result.error.category === "unauthenticated" ? 401 : result.error.category === "infrastructure" ? 503 : 403;
  return Response.json({ error: result.error.message, correlationId }, { status, headers: { "cache-control": "no-store" } });
}
