import Link from "next/link";
import { redirect } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PageHeader } from "@/components/ui/page-header";
import { VehicleFilters } from "@/features/vehicles/vehicle-filters";
import { VehicleList } from "@/features/vehicles/vehicle-list";
import { vehicleListQuerySchema } from "@/features/vehicles/vehicle-schema";
import { requireRole } from "@/lib/dal/auth";
import { listVehicles, listVehicleTypes } from "@/lib/dal/vehicles";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
function normalized(filters: { search: string; status: string; type: string; page: number }) { const params = new URLSearchParams(); if (filters.search) params.set("search", filters.search); if (filters.status !== "all") params.set("status", filters.status); if (filters.type !== "all") params.set("type", filters.type); if (filters.page > 1) params.set("page", String(filters.page)); const query = params.toString(); return query ? `/operations/vehicles?${query}` : "/operations/vehicles"; }

export default async function VehiclesPage({ searchParams }: Props) {
  const query = await searchParams;
  const filters = vehicleListQuerySchema.parse({ search: Array.isArray(query.search) ? query.search[0] : query.search, status: Array.isArray(query.status) ? query.status[0] : query.status, type: Array.isArray(query.type) ? query.type[0] : query.type, page: Array.isArray(query.page) ? query.page[0] : query.page });
  const [actor, result, types] = await Promise.all([requireRole("admin", "dispatcher"), listVehicles(filters), listVehicleTypes()]);
  if (!actor.ok) handleAuthBoundaryFailure(actor.error);
  if (!result.ok) { if (result.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load Vehicles."); }
  if (!types.ok) { if (types.error.category === "forbidden") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." }); throw new Error("Unable to load Vehicle filters."); }
  if (actor.data.role !== "admin" && actor.data.role !== "dispatcher") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
  const lastPage = Math.max(result.data.totalPages, 1); if (filters.page > lastPage) redirect(normalized({ ...filters, page: lastPage }));
  const action = actor.data.role === "admin" ? <Link href="/operations/vehicles/new" className="inline-flex min-h-11 items-center justify-center rounded-control bg-primary px-4 text-label text-on-primary hover:bg-primary-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Add vehicle</Link> : undefined;
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Vehicles" description="View fleet master data and operational availability." actions={action} /><VehicleFilters filters={filters} types={types.data} /><VehicleList vehicles={result.data.vehicles} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} role={actor.data.role} /></div>;
}
