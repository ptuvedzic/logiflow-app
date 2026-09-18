import Link from "next/link";
import { notFound } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { StatusBadge } from "@/components/ui/status-badge";
import { ShipmentEditForm } from "@/features/shipments/shipment-edit-form";
import { shipmentTargetSchema } from "@/features/shipments/shipment-schema";
import { requireRole } from "@/lib/dal/auth";
import { getShipmentForEdit } from "@/lib/dal/shipments";

type Props=Readonly<{params:Promise<{shipmentId:string}>}>;
export default async function EditShipmentPage({params}:Props){const parsed=shipmentTargetSchema.safeParse(await params);if(!parsed.success)notFound();const [actor,result]=await Promise.all([requireRole("admin","dispatcher"),getShipmentForEdit(parsed.data.shipmentId)]);if(!actor.ok)handleAuthBoundaryFailure(actor.error);if(actor.data.role==="driver")handleAuthBoundaryFailure({category:"forbidden",message:"Access denied."});if(!result.ok){if(result.error.category==="not_found")notFound();if(result.error.category==="forbidden")handleAuthBoundaryFailure({category:"forbidden",message:"Access denied."});throw new Error("Unable to load the Shipment.");}if(result.data.status!=="pending"&&result.data.status!=="assigned"&&result.data.status!=="loading")notFound();return <div className="flex min-w-0 flex-col gap-4"><PageHeader title={`Edit ${result.data.trackingNumber}`} description="Update approved Shipment operational data." actions={<div className="flex items-center gap-2"><StatusBadge domain="shipment" status={result.data.status}/><Link href="/operations/shipments" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to shipments</Link></div>}/><Card header={<h2 className="text-h3 text-foreground">Shipment details</h2>}><ShipmentEditForm shipment={result.data} role={actor.data.role}/></Card></div>;}
