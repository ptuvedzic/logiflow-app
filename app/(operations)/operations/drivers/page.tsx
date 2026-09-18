import { redirect } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PageHeader } from "@/components/ui/page-header";
import { DriverFilters } from "@/features/drivers/driver-filters";
import { DriverList } from "@/features/drivers/driver-list";
import { driverListQuerySchema } from "@/features/drivers/driver-schema";
import { requireRole } from "@/lib/dal/auth";
import { listDrivers } from "@/lib/dal/drivers";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
function normalized(filters: { search: string; status: string; account: string; page: number }) { const params = new URLSearchParams(); if (filters.search) params.set("search", filters.search); if (filters.status !== "all") params.set("status", filters.status); if (filters.account !== "all") params.set("account", filters.account); if (filters.page > 1) params.set("page", String(filters.page)); const query = params.toString(); return query ? `/operations/drivers?${query}` : "/operations/drivers"; }

export default async function DriversPage({ searchParams }: Props) {
  const query = await searchParams;
  const filters = driverListQuerySchema.parse({ search: Array.isArray(query.search) ? query.search[0] : query.search, status: Array.isArray(query.status) ? query.status[0] : query.status, account: Array.isArray(query.account) ? query.account[0] : query.account, page: Array.isArray(query.page) ? query.page[0] : query.page });
  const [actor, result] = await Promise.all([requireRole("admin", "dispatcher"), listDrivers(filters)]);
  if (!actor.ok) handleAuthBoundaryFailure(actor.error);
  if (actor.data.role !== "admin" && actor.data.role !== "dispatcher") handleAuthBoundaryFailure({ category: "forbidden", message: "Access denied." });
  if (!result.ok) { if (result.error.category === "infrastructure" || result.error.category === "not_found" || result.error.category === "conflict" || result.error.category === "business_rule") throw new Error("Unable to load drivers."); handleAuthBoundaryFailure(result.error); }
  const lastPage = Math.max(result.data.totalPages, 1); if (filters.page > lastPage) redirect(normalized({ ...filters, page: lastPage }));
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Drivers" description="View Driver availability and operational master data." /><DriverFilters filters={filters} /><DriverList drivers={result.data.drivers} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} role={actor.data.role} /></div>;
}
