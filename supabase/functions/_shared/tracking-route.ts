export type RouteCoordinates = readonly (readonly [number, number])[];

const START = [19.8335, 45.2671] as const;
const DESTINATION = [20.4489, 44.7866] as const;
const TOLERANCE = 0.00001;

function isCoordinate(value: unknown): value is [number, number] {
  return Array.isArray(value) && value.length === 2 &&
    typeof value[0] === "number" && Number.isFinite(value[0]) && value[0] >= -180 && value[0] <= 180 &&
    typeof value[1] === "number" && Number.isFinite(value[1]) && value[1] >= -90 && value[1] <= 90;
}

function matches(actual: readonly [number, number], expected: readonly [number, number]) {
  return Math.abs(actual[0] - expected[0]) <= TOLERANCE &&
    Math.abs(actual[1] - expected[1]) <= TOLERANCE;
}

export function parseTrackingRoute(value: unknown): RouteCoordinates {
  if (typeof value !== "object" || value === null) throw new Error("tracking_route_invalid");
  const feature = value as { type?: unknown; geometry?: { type?: unknown; coordinates?: unknown } };
  const coordinates = feature.geometry?.coordinates;
  if (feature.type !== "Feature" || feature.geometry?.type !== "LineString" ||
      !Array.isArray(coordinates) || coordinates.length < 2 || !coordinates.every(isCoordinate)) {
    throw new Error("tracking_route_invalid");
  }
  const first = coordinates[0];
  const last = coordinates[coordinates.length - 1];
  if (first === undefined || last === undefined || !matches(first, START) || !matches(last, DESTINATION)) {
    throw new Error("tracking_route_endpoints_invalid");
  }
  return coordinates;
}

export function isSchedulerAuthorized(request: Request, expectedSecret: string | undefined) {
  if (expectedSecret === undefined || expectedSecret.length === 0) return false;
  return request.headers.get("authorization") === `Bearer ${expectedSecret}`;
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
