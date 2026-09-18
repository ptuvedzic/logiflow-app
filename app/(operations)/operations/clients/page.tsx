import Link from "next/link";
import { redirect } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PageHeader } from "@/components/ui/page-header";
import { ClientFilters } from "@/features/clients/client-filters";
import { ClientList } from "@/features/clients/client-list";
import { clientListQuerySchema } from "@/features/clients/client-schema";
import { listClients } from "@/lib/dal/clients";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;
function normalized(filters: { search: string; status: string; page: number }) { const params = new URLSearchParams(); if (filters.search) params.set("search", filters.search); if (filters.status !== "all") params.set("status", filters.status); if (filters.page > 1) params.set("page", String(filters.page)); const query = params.toString(); return query ? `/operations/clients?${query}` : "/operations/clients"; }
export default async function ClientsPage({ searchParams }: Props) {
  const query = await searchParams;
  const filters = clientListQuerySchema.parse({ search: Array.isArray(query.search) ? query.search[0] : query.search, status: Array.isArray(query.status) ? query.status[0] : query.status, page: Array.isArray(query.page) ? query.page[0] : query.page });
  const result = await listClients(filters);
  if (!result.ok) { if (result.error.category === "infrastructure" || result.error.category === "not_found" || result.error.category === "conflict" || result.error.category === "business_rule") throw new Error("Unable to load clients."); handleAuthBoundaryFailure(result.error); }
  const lastPage = Math.max(result.data.totalPages, 1); if (filters.page > lastPage) redirect(normalized({ ...filters, page: lastPage }));
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Clients" description="Manage clients used by logistics operations." actions={<Link href="/operations/clients/new" className="inline-flex min-h-11 items-center justify-center rounded-control border border-transparent bg-primary px-4 text-label text-primary-text-on-solid hover:bg-primary-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Create client</Link>} /><ClientFilters filters={filters} /><ClientList clients={result.data.clients} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} /></div>;
}
