import { Activity, BellRing, Map, Package, Plus, Truck, UserRound } from "lucide-react";
import Link from "next/link";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { ErrorState } from "@/components/ui/error-state";
import { KpiCard } from "@/components/ui/kpi-card";
import { PageHeader } from "@/components/ui/page-header";
import { StatusBadge } from "@/components/ui/status-badge";
import { activityListQuerySchema } from "@/features/activity/activity-schema";
import { alertListQuerySchema } from "@/features/alerts/alert-schema";
import { listActivity } from "@/lib/dal/activity";
import { listAlerts } from "@/lib/dal/alerts";
import { getOperationsDashboardSnapshot } from "@/lib/dal/dashboard";

const formatter = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Belgrade" });
const actionClassName = "inline-flex min-h-11 items-center justify-center gap-2 rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10";
const primaryActionClassName = "inline-flex min-h-11 items-center justify-center gap-2 rounded-control bg-primary px-4 text-label text-on-primary hover:bg-primary-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10";
const sectionLinkClassName = "shrink-0 text-label text-primary hover:underline focus-visible:rounded-control focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft";

function RetryLink() {
  return <Link className={actionClassName} href="/operations/dashboard">Try again</Link>;
}

function handleReadBoundaryFailure(category: "unauthenticated" | "missing_profile" | "inactive_profile" | "forbidden"): never {
  if (category === "unauthenticated") handleAuthBoundaryFailure({ category, message: "Authentication required." });
  if (category === "missing_profile") handleAuthBoundaryFailure({ category, message: "Account profile unavailable." });
  if (category === "inactive_profile") handleAuthBoundaryFailure({ category, message: "Account is inactive." });
  handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
}

export default async function OperationsDashboardPage() {
  const [snapshotResult, alertsResult, activityResult] = await Promise.all([
    getOperationsDashboardSnapshot(),
    listAlerts(alertListQuerySchema.parse({ state: "active", page: 1 }), 5),
    listActivity(activityListQuerySchema.parse({ page: 1 }), 5),
  ]);

  if (!snapshotResult.ok && snapshotResult.error.category !== "infrastructure") handleAuthBoundaryFailure(snapshotResult.error);
  if (!alertsResult.ok && alertsResult.error.category !== "infrastructure") handleReadBoundaryFailure(alertsResult.error.category);
  if (!activityResult.ok && activityResult.error.category !== "infrastructure") handleReadBoundaryFailure(activityResult.error.category);

  const snapshot = snapshotResult.ok ? snapshotResult.data : null;

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader
        title="Dashboard"
        description="Monitor the current state of logistics operations."
        actions={<div className="flex w-full flex-wrap gap-2 md:w-auto md:justify-end">
          <Link className={primaryActionClassName} href="/operations/shipments/new"><Plus aria-hidden="true" size={18} />New Shipment</Link>
          <Link className={actionClassName} href="/operations/shipments"><Package aria-hidden="true" size={18} />Shipments</Link>
          <Link className={actionClassName} href="/operations/tracking"><Map aria-hidden="true" size={18} />Tracking</Link>
          <Link className={actionClassName} href="/operations/alerts"><BellRing aria-hidden="true" size={18} />Alerts</Link>
        </div>}
      />

      {snapshot?.kpis.ok ? (
        <section aria-label="Current operational KPIs" className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
          <KpiCard label="Active Shipments" value={snapshot.kpis.data.activeShipments} supportingText="Assigned, loading, or in transit." href="/operations/shipments" icon={Package} tone="primary" />
          <KpiCard label="In-use Vehicles" value={snapshot.kpis.data.inUseVehicles} supportingText="Vehicles currently assigned to active work." href="/operations/vehicles" icon={Truck} tone="info" />
          <KpiCard label="Assigned Drivers" value={snapshot.kpis.data.assignedDrivers} supportingText="Drivers currently assigned to active work." href="/operations/drivers" icon={UserRound} tone="success" />
          <KpiCard label="Active Alerts" value={snapshot.kpis.data.activeAlerts} supportingText="Operational conditions requiring attention." href="/operations/alerts" icon={BellRing} tone="warning" />
        </section>
      ) : <ErrorState title="KPI overview unavailable" description="Current operational counts could not be loaded. No values have been assumed." retryAction={<RetryLink />} />}

      <div className="grid min-w-0 gap-4 xl:grid-cols-[2fr_1fr]">
        {snapshot?.pendingStatusRequests.ok ? (
          <Card header={<div className="flex items-start justify-between gap-4"><div><h2 className="text-h2 text-foreground">Pending Status Requests</h2><p className="mt-1 text-small text-secondary">Oldest requests awaiting review</p></div><Link className={sectionLinkClassName} href="/operations/shipments">View all</Link></div>}>
            {snapshot.pendingStatusRequests.data.length === 0 ? <p className="py-4 text-small text-secondary">No pending status requests.</p> : (
              <ul className="flex min-w-0 flex-col divide-y divide-border-subtle">
                {snapshot.pendingStatusRequests.data.map((request) => <li className="flex min-w-0 flex-col gap-2 py-3 first:pt-0 last:pb-0 md:flex-row md:items-center md:justify-between" key={request.id}>
                  <div className="min-w-0"><p className="break-words font-medium text-foreground">{request.trackingNumber}</p><p className="mt-1 break-words text-small text-secondary">{request.driverName} · <time dateTime={request.requestedAt}>{formatter.format(new Date(request.requestedAt))}</time></p></div>
                  <div className="flex shrink-0 flex-wrap items-center gap-2" aria-label={`Status change from ${request.currentStatus} to ${request.requestedStatus}`}><StatusBadge domain="shipment" status={request.currentStatus} /><span aria-hidden="true" className="text-secondary">→</span><StatusBadge domain="shipment" status={request.requestedStatus} /></div>
                </li>)}
              </ul>
            )}
          </Card>
        ) : <ErrorState title="Pending requests unavailable" description="Pending status requests could not be loaded." retryAction={<RetryLink />} />}

        {alertsResult.ok ? (
          <Card header={<div className="flex items-start justify-between gap-4"><div><h2 className="text-h2 text-foreground">Active Alerts</h2><p className="mt-1 text-small text-secondary">{alertsResult.data.totalCount} require attention</p></div><Link className={sectionLinkClassName} href="/operations/alerts">View all</Link></div>}>
            {alertsResult.data.alerts.length === 0 ? <p className="py-4 text-small text-secondary">No active alerts.</p> : (
              <ul className="flex min-w-0 flex-col divide-y divide-border-subtle">
                {alertsResult.data.alerts.map((alert) => <li className="flex min-w-0 items-start justify-between gap-3 py-3 first:pt-0 last:pb-0" key={alert.id}>
                  <div className="min-w-0"><p className="break-words font-medium text-foreground">{alert.message}</p><p className="mt-1 break-words text-small text-secondary">{alert.entityLabel} · <time dateTime={alert.createdAt}>{formatter.format(new Date(alert.createdAt))}</time></p></div><StatusBadge domain="alert_severity" status={alert.severity} />
                </li>)}
              </ul>
            )}
          </Card>
        ) : <ErrorState title="Alerts unavailable" description="Active alerts could not be loaded." retryAction={<RetryLink />} />}
      </div>

      {activityResult.ok ? (
        <Card header={<div className="flex items-start justify-between gap-4"><div><h2 className="text-h2 text-foreground">Recent Activity</h2><p className="mt-1 text-small text-secondary">Latest authorized operational events</p></div><Link className={sectionLinkClassName} href="/operations/activity">View all</Link></div>}>
          {activityResult.data.activities.length === 0 ? <p className="py-4 text-small text-secondary">No activity recorded.</p> : (
            <ul className="flex min-w-0 flex-col divide-y divide-border-subtle">
              {activityResult.data.activities.map((activity) => <li className="flex min-w-0 gap-3 py-3 first:pt-0 last:pb-0" key={activity.id}>
                <Activity aria-hidden="true" className="mt-0.5 shrink-0 text-primary-icon" size={18} strokeWidth={1.75} /><div className="min-w-0"><p className="break-words font-medium text-foreground">{activity.actionLabel}</p><p className="mt-1 break-words text-small text-secondary">{activity.actorLabel} · {activity.entityLabel} · <time dateTime={activity.occurredAt}>{formatter.format(new Date(activity.occurredAt))}</time></p></div>
              </li>)}
            </ul>
          )}
        </Card>
      ) : <ErrorState title="Activity unavailable" description="Recent authorized activity could not be loaded." retryAction={<RetryLink />} />}
    </div>
  );
}
