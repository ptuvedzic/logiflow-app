import Link from "next/link";
import { notFound } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { StatusBadge } from "@/components/ui/status-badge";
import { VehicleMileageForm } from "@/features/vehicles/vehicle-actions";
import { VehicleForm } from "@/features/vehicles/vehicle-form";
import { vehicleTargetSchema } from "@/features/vehicles/vehicle-schema";
import { requireRole } from "@/lib/dal/auth";
import { getVehicleForEdit } from "@/lib/dal/vehicles";

type Props = Readonly<{ params: Promise<{ vehicleId: string }> }>;
export default async function EditVehiclePage({ params }: Props) {
  const parsed = vehicleTargetSchema.safeParse(await params); if (!parsed.success) notFound();
  const [actor, result] = await Promise.all([requireRole("admin"), getVehicleForEdit(parsed.data.vehicleId)]);
  if (!actor.ok) handleAuthBoundaryFailure(actor.error);
  if (!result.ok) { if (result.error.category === "not_found") notFound(); if (result.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load the Vehicle."); }
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title={`Edit ${result.data.registration}`} description="Update approved Vehicle master data." actions={<div className="flex items-center gap-2"><StatusBadge domain="vehicle" status={result.data.status} /><Link href="/operations/vehicles" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to vehicles</Link></div>} /><Card header={<h2 className="text-h3 text-foreground">Vehicle details</h2>}><VehicleForm vehicle={result.data} /></Card><Card id="mileage" header={<div><h2 className="text-h3 text-foreground">Update mileage</h2><p className="mt-1 text-body text-secondary">Mileage can increase but never decrease.</p></div>}><VehicleMileageForm vehicle={result.data} /></Card></div>;
}
