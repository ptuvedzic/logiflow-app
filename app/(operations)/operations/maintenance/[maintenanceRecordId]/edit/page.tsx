import Link from "next/link";
import { notFound } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { MaintenanceForm } from "@/features/maintenance/maintenance-form";
import { maintenanceTargetSchema } from "@/features/maintenance/maintenance-schema";
import { requireRole } from "@/lib/dal/auth";
import { getMaintenanceRecordForEdit } from "@/lib/dal/maintenance";

type Props = Readonly<{ params: Promise<{ maintenanceRecordId: string }> }>;
export default async function EditMaintenancePage({ params }: Props) { const parsed = maintenanceTargetSchema.safeParse(await params); if (!parsed.success) notFound(); const [actor, result] = await Promise.all([requireRole("admin"), getMaintenanceRecordForEdit(parsed.data.maintenanceRecordId)]); if (!actor.ok) handleAuthBoundaryFailure(actor.error); if (!result.ok) { if (result.error.category === "not_found") notFound(); if (result.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load maintenance record."); } return <div className="flex min-w-0 flex-col gap-4"><PageHeader title={`Edit maintenance — ${result.data.vehicleRegistration}`} description="Correct approved Vehicle service history." actions={<Link href="/operations/maintenance" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover">Back to maintenance</Link>} /><Card><MaintenanceForm record={result.data} /></Card></div>; }
