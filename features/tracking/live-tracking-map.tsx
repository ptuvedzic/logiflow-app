"use client";

import { useEffect, useRef, useState } from "react";
import { createRoot, type Root } from "react-dom/client";
import { Truck } from "lucide-react";
import * as maplibregl from "maplibre-gl";
import type { Map as MapLibreMap, Marker } from "maplibre-gl";

import { Card } from "@/components/ui/card";
import { TrackingStatus } from "@/features/tracking/tracking-status";
import type { TrackingConnectionState, TrackingLocation } from "@/features/tracking/tracking-types";
import { createClient } from "@/lib/supabase/client";

type Props = Readonly<{
  initialLocations: readonly TrackingLocation[];
  mapStyleUrl: string;
  routeUrl: string;
  vehicleFilter?: string;
}>;

function mapRow(row: Record<string, unknown>): TrackingLocation | null {
  if (typeof row.vehicle_id !== "string" || typeof row.shipment_id !== "string" ||
      typeof row.latitude !== "number" || typeof row.longitude !== "number" || typeof row.updated_at !== "string") return null;
  return { vehicleId: row.vehicle_id, shipmentId: row.shipment_id, latitude: row.latitude,
    longitude: row.longitude, speed: typeof row.speed === "number" ? row.speed : null,
    heading: typeof row.heading === "number" ? row.heading : null,
    routeProgress: typeof row.route_progress === "number" ? row.route_progress : null, updatedAt: row.updated_at };
}

export function LiveTrackingMap({ initialLocations, mapStyleUrl, routeUrl, vehicleFilter }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const markersRef = useRef<Map<string, { marker: Marker; root: Root }>>(new Map());
  const [locations, setLocations] = useState<readonly TrackingLocation[]>(initialLocations);
  const [connection, setConnection] = useState<TrackingConnectionState>("connecting");
  const [mapError, setMapError] = useState(false);
  const [staleVehicleIds, setStaleVehicleIds] = useState<ReadonlySet<string>>(new Set());

  useEffect(() => {
    if (containerRef.current === null) return;
    const map = new maplibregl.Map({ container: containerRef.current, style: mapStyleUrl,
      center: [19.8335, 45.2671], zoom: 8 });
    map.addControl(new maplibregl.NavigationControl(), "top-right");
    map.addControl(new maplibregl.GeolocateControl({ trackUserLocation: false }), "top-right");
    map.on("load", async () => {
      try {
        const response = await fetch(routeUrl, { headers: { accept: "application/geo+json, application/json" } });
        if (!response.ok) throw new Error("route unavailable");
        const route = await response.json() as GeoJSON.Feature<GeoJSON.LineString>;
        map.addSource("simulation-route", { type: "geojson", data: route });
        map.addLayer({ id: "simulation-route", type: "line", source: "simulation-route",
          paint: { "line-color": "#3B82F6", "line-width": 4 } });
        new maplibregl.Marker({ color: "#22C55E" }).setLngLat([19.8335, 45.2671]).addTo(map);
        new maplibregl.Marker({ color: "#FF6209" }).setLngLat([20.4489, 44.7866]).addTo(map);
      } catch { setMapError(true); }
    });
    map.on("error", () => setMapError(true));
    mapRef.current = map;
    const markers = markersRef.current;
    return () => { markers.forEach(({ marker, root }) => { root.unmount(); marker.remove(); }); markers.clear(); map.remove(); mapRef.current = null; };
  }, [mapStyleUrl, routeUrl]);

  useEffect(() => {
    const map = mapRef.current;
    if (map === null) return;
    const ids = new Set(locations.map((location) => location.vehicleId));
    markersRef.current.forEach(({ marker, root }, id) => { if (!ids.has(id)) { root.unmount(); marker.remove(); markersRef.current.delete(id); } });
    for (const location of locations) {
      let markerEntry = markersRef.current.get(location.vehicleId);
      if (markerEntry === undefined) {
        const element = document.createElement("div");
        element.className = "flex h-8 w-8 items-center justify-center rounded-full border-2 border-white bg-info text-white";
        element.setAttribute("aria-label", "Simulated vehicle location");
        const root = createRoot(element);
        root.render(<Truck aria-hidden="true" size={16} strokeWidth={1.75} />);
        const newMarker = new maplibregl.Marker({ element })
          .setLngLat([location.longitude, location.latitude])
          .setRotation(location.heading ?? 0)
          .addTo(map);
        markerEntry = { marker: newMarker, root };
        markersRef.current.set(location.vehicleId, markerEntry);
      }
      markerEntry.marker.setLngLat([location.longitude, location.latitude]).setRotation(location.heading ?? 0);
    }
  }, [locations]);

  useEffect(() => {
    const refreshStale = () => {
      const now = Date.now();
      setStaleVehicleIds(new Set(locations.filter((location) => now - Date.parse(location.updatedAt) >= 600_000).map((location) => location.vehicleId)));
    };
    const initialTimer = setTimeout(refreshStale, 0);
    const interval = setInterval(refreshStale, 30_000);
    return () => { clearTimeout(initialTimer); clearInterval(interval); };
  }, [locations]);

  useEffect(() => {
    const client = createClient();
    let fallback: ReturnType<typeof setInterval> | null = null;
    let cancelled = false;
    const refresh = async () => {
      try {
        const response = await fetch("/api/tracking/refresh", { cache: "no-store" });
        if (!response.ok) throw new Error("refresh failed");
        const body = await response.json() as { locations?: TrackingLocation[] };
        if (!cancelled && Array.isArray(body.locations)) setLocations(body.locations);
      } catch { if (!cancelled) setConnection("unavailable"); }
    };
    const startFallback = () => {
      setConnection("reconnecting");
      if (fallback === null) fallback = setInterval(refresh, 30_000);
    };
    const channel = client.channel(`tracking:${vehicleFilter ?? "operations"}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "vehicle_locations",
        ...(vehicleFilter === undefined ? {} : { filter: `vehicle_id=eq.${vehicleFilter}` }) }, (payload) => {
        if (payload.eventType === "DELETE") {
          const oldRow = mapRow(payload.old);
          if (oldRow !== null) setLocations((current) => current.filter((row) => row.vehicleId !== oldRow.vehicleId));
          return;
        }
        const row = mapRow(payload.new);
        if (row !== null) setLocations((current) => [...current.filter((item) => item.vehicleId !== row.vehicleId), row]);
      }).subscribe(async (status) => {
        if (status === "SUBSCRIBED") {
          await refresh();
          if (fallback !== null) { clearInterval(fallback); fallback = null; }
          if (!cancelled) setConnection("live");
        } else if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") startFallback();
      });
    return () => { cancelled = true; if (fallback !== null) clearInterval(fallback); void client.removeChannel(channel); };
  }, [vehicleFilter]);

  const selected = locations[0];
  const stale = selected !== undefined && staleVehicleIds.has(selected.vehicleId);
  return (
    <Card header={<div className="flex flex-wrap items-center justify-between gap-2"><div><h2 className="text-h3 text-foreground">Live tracking</h2><p className="text-small text-secondary">Simulated tracking</p></div><TrackingStatus state={mapError ? "unavailable" : connection} /></div>}>
      <div ref={containerRef} className="min-h-[280px] w-full overflow-hidden rounded-card border border-border" aria-label="Simulated vehicle tracking map" />
      {locations.length === 0 ? <p className="mt-4 text-small text-secondary">No active route.</p> : null}
      {selected !== undefined ? <dl className="mt-4 grid gap-3 sm:grid-cols-4">
        <div><dt className="text-small text-secondary">Progress</dt><dd className="text-body-medium">{selected.routeProgress?.toFixed(2) ?? "—"}%</dd></div>
        <div><dt className="text-small text-secondary">Speed</dt><dd className="text-body-medium">{selected.speed?.toFixed(2) ?? "—"} km/h</dd></div>
        <div><dt className="text-small text-secondary">Heading</dt><dd className="text-body-medium">{selected.heading?.toFixed(0) ?? "—"}°</dd></div>
        <div><dt className="text-small text-secondary">Last update</dt><dd className={stale ? "text-body-medium text-danger" : "text-body-medium"}>{stale ? "Stale · " : ""}{new Date(selected.updatedAt).toLocaleTimeString()}</dd></div>
      </dl> : null}
    </Card>
  );
}
