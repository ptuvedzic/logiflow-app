export type TrackingLocation = Readonly<{
  vehicleId: string;
  shipmentId: string;
  latitude: number;
  longitude: number;
  speed: number | null;
  heading: number | null;
  routeProgress: number | null;
  updatedAt: string;
}>;

export type TrackingConnectionState = "connecting" | "live" | "reconnecting" | "unavailable";
