import Link from "next/link";
import { redirect } from "next/navigation";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PageHeader } from "@/components/ui/page-header";
import { AccountFilters } from "@/features/accounts/account-filters";
import { AccountList } from "@/features/accounts/account-list";
import { accountListQuerySchema } from "@/features/accounts/account-lifecycle-schema";
import { listManagedAccounts } from "@/lib/dal/accounts";

type AccountPageProps = Readonly<{
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}>;

function normalizedUrl(filters: { search: string; role: string; status: string; page: number }): string {
  const params = new URLSearchParams();
  if (filters.search !== "") params.set("search", filters.search);
  if (filters.role !== "all") params.set("role", filters.role);
  if (filters.status !== "all") params.set("status", filters.status);
  if (filters.page > 1) params.set("page", String(filters.page));
  const query = params.toString();
  return query === "" ? "/operations/accounts" : `/operations/accounts?${query}`;
}

export default async function AccountsPage({ searchParams }: AccountPageProps) {
  const query = await searchParams;
  const filters = accountListQuerySchema.parse({
    search: Array.isArray(query.search) ? query.search[0] : query.search,
    role: Array.isArray(query.role) ? query.role[0] : query.role,
    status: Array.isArray(query.status) ? query.status[0] : query.status,
    page: Array.isArray(query.page) ? query.page[0] : query.page,
  });
  const result = await listManagedAccounts(filters);

  if (!result.ok) {
    if (result.error.category === "not_found" || result.error.category === "infrastructure") {
      throw new Error("Unable to load accounts.");
    }
    handleAuthBoundaryFailure(result.error);
  }

  const lastPage = Math.max(result.data.totalPages, 1);
  if (filters.page > lastPage) {
    redirect(normalizedUrl({ ...filters, page: lastPage }));
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader
        title="Accounts"
        description="Manage Dispatcher and Driver account access."
        actions={<Link href="/operations/accounts/new" className="inline-flex h-10 items-center justify-center rounded-control border border-transparent bg-primary px-4 text-label text-primary-text-on-solid hover:bg-primary-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app">Create account</Link>}
      />
      <AccountFilters filters={filters} />
      <AccountList accounts={result.data.accounts} filters={filters} totalCount={result.data.totalCount} totalPages={result.data.totalPages} />
    </div>
  );
}
