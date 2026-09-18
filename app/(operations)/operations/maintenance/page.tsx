import Link from "next/link";
import { redirect } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PageHeader } from "@/components/ui/page-header";
import { MaintenanceFilters } from "@/features/maintenance/maintenance-filters";
import { MaintenanceList } from "@/features/maintenance/maintenance-list";
import { maintenanceListQuerySchema } from "@/features/maintenance/maintenance-schema";
import { requireRole } from "@/lib/dal/auth";
import { listMaintenanceRecords, listMaintenanceVehicleOptions } from "@/lib/dal/maintenance";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
function normalized(filters: { search: string; vehicle: string; from: string; to: string; page: number }) { const p = new URLSearchParams(); if (filters.search) p.set("search", filters.search); if (filters.vehicle !== "all") p.set("vehicle", filters.vehicle); if (filters.from) p.set("from", filters.from); if (filters.to) p.set("to", filters.to); if (filters.page > 1) p.set("page", String(filters.page)); const q = p.toString(); return q ? `/operations/maintenance?${q}` : "/operations/maintenance"; }
export default async function MaintenancePage({ searchParams }: Props) {
  const query = await searchParams; const value = (key: string) => Array.isArray(query[key]) ? query[key]?.[0] : query[key];
  const filters = maintenanceListQuerySchema.parse({ search: value("search"), vehicle: value("vehicle"), from: value("from"), to: value("to"), page: value("page") });
  const [actor, result, vehicles] = await Promise.all([requireRole("admin", "dispatcher"), listMaintenanceRecords(filters), listMaintenanceVehicleOptions()]);
  if (!actor.ok) handleAuthBoundaryFailure(actor.error);
  if (!result.ok) { if (result.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load maintenance records."); }
  if (!vehicles.ok) { if (vehicles.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load Vehicle filters."); }
  if (actor.data.role !== "admin" && actor.data.role !== "dispatcher") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
  const lastPage = Math.max(result.data.totalPages, 1); if (filters.page > lastPage) redirect(normalized({ ...filters, page: lastPage }));
  const action = actor.data.role === "admin" ? <Link href="/operations/maintenance/new" className="inline-flex min-h-11 items-center justify-center rounded-control bg-primary px-4 text-label text-on-primary hover:bg-primary-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Add maintenance record</Link> : undefined;
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Maintenance" description="Review and maintain Vehicle service history." actions={action} /><MaintenanceFilters filters={filters} vehicles={vehicles.data} /><MaintenanceList records={result.data.records} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} role={actor.data.role} /></div>;
}
