import Link from "next/link";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { VehicleForm } from "@/features/vehicles/vehicle-form";
import { requireRole } from "@/lib/dal/auth";

export default async function NewVehiclePage() {
  const actor = await requireRole("admin"); if (!actor.ok) handleAuthBoundaryFailure(actor.error);
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Add Vehicle" description="Create an available Vehicle master-data record." actions={<Link href="/operations/vehicles" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to vehicles</Link>} /><Card><VehicleForm /></Card></div>;
}
