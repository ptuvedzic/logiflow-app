import { Building2, CalendarDays, CircleDollarSign, Gauge, HandCoins, PackageCheck, ReceiptText, Truck, UserRound, Wrench } from "lucide-react";

import { EmptyState } from "@/components/ui/empty-state";
import { KpiCard } from "@/components/ui/kpi-card";
import { StatusBadge } from "@/components/ui/status-badge";
import { Table, TableBody, TableCaption, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import type { AdminReportSnapshot } from "@/features/reports/report-schema";

const currency = new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR" });
const number = new Intl.NumberFormat("en-GB");
const date = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeZone: "Europe/Belgrade" });

function formatDate(value: string) {
  return date.format(new Date(`${value}T12:00:00Z`));
}

function SectionHeading({ title, description }: Readonly<{ title: string; description: string }>) {
  return <div><h2 className="text-h2 text-foreground">{title}</h2><p className="mt-1 text-small text-secondary">{description}</p></div>;
}

export function FinancialReports({ data }: Readonly<{ data: AdminReportSnapshot["financial"] }>) {
  return <section aria-labelledby="financial-reports-heading" className="flex flex-col gap-4">
    <div id="financial-reports-heading"><SectionHeading title="Financial" description="Completed-delivery financial performance for the selected period." /></div>
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <KpiCard label="Completed Shipments" value={number.format(data.completed_shipments)} supportingText="Authoritative Delivered approvals in the period." icon={PackageCheck} tone="primary" />
      <KpiCard label="Revenue" value={currency.format(data.revenue)} supportingText="Stored prices for qualifying delivered Shipments." icon={CircleDollarSign} tone="analytics" />
      <KpiCard label="Expenses" value={currency.format(data.total_expenses)} supportingText="All retained expenses attached to qualifying Shipments." icon={ReceiptText} tone="warning" />
      <KpiCard label="Profit" value={currency.format(data.profit)} supportingText="Revenue minus authoritative retained expenses." icon={HandCoins} tone="success" />
    </div>
  </section>;
}

export function ShipmentReports({ data, granularity }: Readonly<{ data: AdminReportSnapshot["shipments"]; granularity: AdminReportSnapshot["period"]["bucket_granularity"] }>) {
  return <section aria-labelledby="shipment-reports-heading" className="flex flex-col gap-4">
    <div id="shipment-reports-heading"><SectionHeading title="Shipments" description="Pickup-date volume plus authoritative delivery completions." /></div>
    <div className="grid gap-4 sm:grid-cols-3">
      <KpiCard label="Scheduled Shipments" value={number.format(data.scheduled_shipments)} supportingText="All Shipments with pickup dates in the period." icon={CalendarDays} tone="primary" />
      <KpiCard label="Completed Shipments" value={number.format(data.completed_shipments)} supportingText="Delivered approvals resolved in the period." icon={PackageCheck} tone="success" />
      <KpiCard label="Delayed Shipments" value={number.format(data.delayed_shipments)} supportingText="A separate condition within the pickup-date cohort." icon={PackageCheck} tone="warning" />
    </div>
    <div className="grid min-w-0 gap-4 xl:grid-cols-2">
      <TableCard title="Shipments by status" description="Current status of Shipments whose pickup falls in the period.">
        <TableScrollArea aria-label="Shipment status report">
          <Table><TableCaption>Every Shipment status is shown, including zero counts.</TableCaption><TableHeader><TableRow><TableHead>Status</TableHead><TableHead>Shipments</TableHead></TableRow></TableHeader><TableBody>
            {data.statuses.map((row) => <TableRow key={row.status}><TableCell><StatusBadge domain="shipment" status={row.status} /></TableCell><TableCell>{number.format(row.count)}</TableCell></TableRow>)}
          </TableBody></Table>
        </TableScrollArea>
      </TableCard>
      <TableCard title="Shipment count over time" description={`${granularity === "day" ? "Daily" : granularity === "week" ? "Weekly" : "Monthly"} pickup volume, including zero-count periods.`}>
        <TableScrollArea aria-label="Shipment volume report">
          <Table><TableCaption>Counts include every Shipment status.</TableCaption><TableHeader><TableRow><TableHead>Period</TableHead><TableHead>Shipments</TableHead></TableRow></TableHeader><TableBody>
            {data.volume.map((row) => <TableRow key={row.bucket_start}><TableCell><time dateTime={row.bucket_start}>{formatDate(row.bucket_start)}</time>{row.bucket_end !== row.bucket_start ? <> – <time dateTime={row.bucket_end}>{formatDate(row.bucket_end)}</time></> : null}</TableCell><TableCell>{number.format(row.count)}</TableCell></TableRow>)}
          </TableBody></Table>
        </TableScrollArea>
      </TableCard>
    </div>
  </section>;
}

export function FleetReports({ data }: Readonly<{ data: AdminReportSnapshot["fleet"] }>) {
  const utilization = data.utilization_percent === null ? "Not available" : `${number.format(data.utilization_percent)}%`;
  return <section aria-labelledby="fleet-reports-heading" className="flex flex-col gap-4">
    <div id="fleet-reports-heading"><SectionHeading title="Fleet" description="Current Vehicle snapshot and date-filtered maintenance history." /></div>
    <p className="text-small text-secondary">Vehicle status and utilization are a current snapshot and are unaffected by the selected historical date range.</p>
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <KpiCard label="Current Utilization" value={utilization} supportingText="In-use Vehicles divided by available plus in-use Vehicles." icon={Gauge} tone="info" />
      <KpiCard label="Maintenance Records" value={number.format(data.maintenance.records)} supportingText="Service dates within the selected period." icon={Wrench} tone="warning" />
      <KpiCard label="Vehicles Serviced" value={number.format(data.maintenance.vehicles_serviced)} supportingText="Distinct Vehicles with maintenance in the period." icon={Truck} tone="info" />
      <KpiCard label="Recorded Maintenance Cost" value={currency.format(data.maintenance.recorded_cost)} supportingText={`${number.format(data.maintenance.costed_records)} of ${number.format(data.maintenance.records)} records include cost; this is not a Shipment expense.`} icon={ReceiptText} tone="analytics" />
    </div>
    <TableCard title="Current Vehicle status" description={`${number.format(data.in_use_vehicles)} in use across ${number.format(data.serviceable_vehicles)} serviceable Vehicles.`}>
      <TableScrollArea aria-label="Current Vehicle status report"><Table><TableCaption>Current snapshot; not historical utilization.</TableCaption><TableHeader><TableRow><TableHead>Status</TableHead><TableHead>Vehicles</TableHead></TableRow></TableHeader><TableBody>
        {data.statuses.map((row) => <TableRow key={row.status}><TableCell><StatusBadge domain="vehicle" status={row.status} /></TableCell><TableCell>{number.format(row.count)}</TableCell></TableRow>)}
      </TableBody></Table></TableScrollArea>
    </TableCard>
  </section>;
}

export function DriverReports({ data }: Readonly<{ data: AdminReportSnapshot["drivers"] }>) {
  return <section aria-labelledby="driver-reports-heading" className="flex flex-col gap-4">
    <div id="driver-reports-heading"><SectionHeading title="Drivers" description="Current operational activity and completed Shipments in the selected period." /></div>
    <p className="text-small text-secondary">Driver status is a current snapshot and is unaffected by the selected historical date range. Completion ordering is not a score or rating.</p>
    <div className="grid min-w-0 gap-4 xl:grid-cols-2">
      <TableCard title="Current Driver status" description="All approved Driver operational states."><TableScrollArea aria-label="Current Driver status report"><Table><TableCaption>Current snapshot.</TableCaption><TableHeader><TableRow><TableHead>Status</TableHead><TableHead>Drivers</TableHead></TableRow></TableHeader><TableBody>
        {data.statuses.map((row) => <TableRow key={row.status}><TableCell><StatusBadge domain="driver" status={row.status} /></TableCell><TableCell>{number.format(row.count)}</TableCell></TableRow>)}
      </TableBody></Table></TableScrollArea></TableCard>
      {data.completions.length === 0 ? <EmptyState icon={UserRound} title="No Driver completions" description="No Drivers completed a Shipment in the selected period." /> : <TableCard title="Completed Shipments by Driver" description="Ordered by completed Shipment count for readable reporting only."><TableScrollArea aria-label="Driver completion report"><Table><TableCaption>This is operational activity, not a performance ranking.</TableCaption><TableHeader><TableRow><TableHead>Driver</TableHead><TableHead>Completed Shipments</TableHead></TableRow></TableHeader><TableBody>
        {data.completions.map((row) => <TableRow key={row.driver_id}><TableCell className="font-medium">{row.driver_name}</TableCell><TableCell>{number.format(row.completed_shipments)}</TableCell></TableRow>)}
      </TableBody></Table></TableScrollArea></TableCard>}
    </div>
  </section>;
}

export function ClientReports({ data }: Readonly<{ data: AdminReportSnapshot["clients"] }>) {
  return <section aria-labelledby="client-reports-heading" className="flex flex-col gap-4">
    <div id="client-reports-heading"><SectionHeading title="Clients" description="Delivered Shipment count and stored-price revenue by Client." /></div>
    {data.length === 0 ? <EmptyState icon={Building2} title="No Client results" description="No Clients have qualifying delivered Shipments in the selected period." /> : <TableCard title="Client delivery summary" description="Ordered by revenue, then completed Shipment count; no CRM scoring is applied."><TableScrollArea aria-label="Client report"><Table><TableCaption>Revenue uses stored Shipment prices for qualifying deliveries.</TableCaption><TableHeader><TableRow><TableHead>Client</TableHead><TableHead>Completed Shipments</TableHead><TableHead>Revenue</TableHead></TableRow></TableHeader><TableBody>
      {data.map((row) => <TableRow key={row.client_id}><TableCell className="font-medium">{row.company_name}</TableCell><TableCell>{number.format(row.completed_shipments)}</TableCell><TableCell>{currency.format(row.revenue)}</TableCell></TableRow>)}
    </TableBody></Table></TableScrollArea></TableCard>}
  </section>;
}
