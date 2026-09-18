import type { TrackingConnectionState } from "@/features/tracking/tracking-types";

const labels: Record<TrackingConnectionState, string> = {
  connecting: "Connecting",
  live: "Live simulated data",
  reconnecting: "Reconnecting — refreshing every 30 seconds",
  unavailable: "Tracking unavailable",
};

export function TrackingStatus({ state }: Readonly<{ state: TrackingConnectionState }>) {
  return (
    <p className="text-small text-secondary" role="status" aria-live="polite">
      {labels[state]}
    </p>
  );
}
