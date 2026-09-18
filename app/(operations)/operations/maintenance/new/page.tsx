import Link from "next/link";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { MaintenanceForm } from "@/features/maintenance/maintenance-form";
import { requireRole } from "@/lib/dal/auth";
import { listMaintenanceVehicleOptions } from "@/lib/dal/maintenance";

export default async function NewMaintenancePage() { const [actor, vehicles] = await Promise.all([requireRole("admin"), listMaintenanceVehicleOptions()]); if (!actor.ok) handleAuthBoundaryFailure(actor.error); if (!vehicles.ok) { if (vehicles.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load Vehicles."); } return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Add maintenance record" description="Record completed Vehicle service and mileage." actions={<Link href="/operations/maintenance" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover">Back to maintenance</Link>} /><Card><MaintenanceForm vehicles={vehicles.data} /></Card></div>; }
