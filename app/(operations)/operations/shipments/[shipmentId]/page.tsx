import { CircleDollarSign, HandCoins, ReceiptText, Route } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { StatusBadge } from "@/components/ui/status-badge";
import { ShipmentExpenses } from "@/features/expenses/shipment-expenses";
import { shipmentExpenseTargetSchema } from "@/features/expenses/expense-schema";
import { requireRole } from "@/lib/dal/auth";
import { getShipmentFinancialData } from "@/lib/dal/expenses";

type Props = Readonly<{ params: Promise<{ shipmentId: string }> }>;

const currency = new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR" });
const dateTime = new Intl.DateTimeFormat("en-GB", {
  dateStyle: "medium",
  timeStyle: "short",
  timeZone: "Europe/Belgrade",
});

function FinancialCard({ label, value, supportingText, icon: Icon, tone }: Readonly<{
  label: string;
  value: number;
  supportingText: string;
  icon: typeof CircleDollarSign;
  tone: "analytics" | "warning" | "success";
}>) {
  const toneClass = tone === "analytics"
    ? "bg-analytics-purple-soft text-analytics-purple"
    : tone === "warning"
      ? "bg-warning-soft text-warning-text"
      : "bg-success-soft text-success";
  return (
    <Card className="h-full">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h2 className="text-label text-secondary">{label}</h2>
          <p className="mt-2 break-words text-metric-medium text-foreground">{currency.format(value)}</p>
        </div>
        <span className={`inline-flex size-10 shrink-0 items-center justify-center rounded-control ${toneClass}`}>
          <Icon aria-hidden="true" size={20} strokeWidth={1.75} />
        </span>
      </div>
      <p className="mt-2 text-small text-secondary">{supportingText}</p>
    </Card>
  );
}

export default async function ShipmentDetailPage({ params }: Props) {
  const parsed = shipmentExpenseTargetSchema.safeParse(await params);
  if (!parsed.success) notFound();

  const actor = await requireRole("admin", "dispatcher");
  if (!actor.ok) handleAuthBoundaryFailure(actor.error);
  const result = await getShipmentFinancialData(parsed.data.shipmentId);
  if (!result.ok) {
    if (result.error.category === "not_found") notFound();
    if (result.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
    throw new Error("Unable to load Shipment financial details.");
  }

  const { shipment, expenses } = result.data;
  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader
        title={shipment.trackingNumber}
        description={`${shipment.clientCompany} · ${shipment.cargoType}`}
        breadcrumb={<nav aria-label="Breadcrumb"><Link className="hover:text-primary hover:underline" href="/operations/shipments">Shipments</Link><span aria-hidden="true"> / </span><span>{shipment.trackingNumber}</span></nav>}
        status={<div className="flex flex-wrap gap-2"><StatusBadge domain="shipment" status={shipment.status} />{shipment.delayed ? <StatusBadge domain="shipment_condition" status="delayed" /> : null}</div>}
        actions={<Link href="/operations/shipments" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to Shipments</Link>}
      />

      <div className="grid gap-4 lg:grid-cols-[2fr_1fr]">
        <Card header={<h2 className="text-h2 text-foreground">Shipment context</h2>}>
          <dl className="grid gap-4 sm:grid-cols-2">
            <div><dt className="text-label text-secondary">Client</dt><dd className="mt-1 text-body-medium text-foreground">{shipment.clientCompany}</dd></div>
            <div><dt className="text-label text-secondary">Cargo</dt><dd className="mt-1 text-body-medium text-foreground">{shipment.cargoType}</dd></div>
            <div><dt className="text-label text-secondary">Pickup</dt><dd className="mt-1 break-words text-body text-foreground">{shipment.pickupAddress}</dd></div>
            <div><dt className="text-label text-secondary">Delivery</dt><dd className="mt-1 break-words text-body text-foreground">{shipment.deliveryAddress}</dd></div>
            <div><dt className="text-label text-secondary">Pickup date</dt><dd className="mt-1 text-body text-foreground"><time dateTime={shipment.pickupAt}>{dateTime.format(new Date(shipment.pickupAt))}</time></dd></div>
            <div><dt className="text-label text-secondary">Expected delivery</dt><dd className="mt-1 text-body text-foreground"><time dateTime={shipment.expectedDeliveryAt}>{dateTime.format(new Date(shipment.expectedDeliveryAt))}</time></dd></div>
          </dl>
        </Card>
        <Card header={<div className="flex items-center gap-2"><Route aria-hidden="true" className="text-info" size={20} strokeWidth={1.75} /><h2 className="text-h2 text-foreground">Route</h2></div>}>
          <p className="break-words text-body text-foreground">{shipment.pickupAddress}</p>
          <p className="my-2 text-small text-muted">to</p>
          <p className="break-words text-body text-foreground">{shipment.deliveryAddress}</p>
        </Card>
      </div>

      <section aria-labelledby="financial-summary-heading" className="flex flex-col gap-4">
        <h2 id="financial-summary-heading" className="text-h2 text-foreground">Financial summary</h2>
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          <FinancialCard label="Revenue" value={shipment.revenue} supportingText="Authoritative stored Shipment price" icon={CircleDollarSign} tone="analytics" />
          <FinancialCard label="Total expenses" value={shipment.totalExpenses} supportingText={`${shipment.expenseCount} retained ${shipment.expenseCount === 1 ? "expense" : "expenses"}`} icon={ReceiptText} tone="warning" />
          <FinancialCard label="Profit" value={shipment.profit} supportingText="Revenue minus authoritative expenses" icon={HandCoins} tone="success" />
        </div>
      </section>

      <section aria-label="Shipment expense management">
        <ShipmentExpenses shipmentId={shipment.id} expenses={expenses} />
      </section>
    </div>
  );
}
