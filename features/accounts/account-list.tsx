import { Users } from "lucide-react";

import { AccountActions } from "@/features/accounts/account-actions";
import { EmptyState } from "@/components/ui/empty-state";
import {
  Pagination,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";
import { StatusBadge } from "@/components/ui/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import type { ManagedAccount, ManagedAccountListInput } from "@/lib/dal/accounts";

const dateFormatter = new Intl.DateTimeFormat("en", {
  dateStyle: "medium",
  timeZone: "UTC",
});

function accountUrl(filters: ManagedAccountListInput, page: number): string {
  const params = new URLSearchParams();
  if (filters.search !== "") params.set("search", filters.search);
  if (filters.role !== "all") params.set("role", filters.role);
  if (filters.status !== "all") params.set("status", filters.status);
  if (page > 1) params.set("page", String(page));
  const query = params.toString();
  return query === "" ? "/operations/accounts" : `/operations/accounts?${query}`;
}

export function AccountList({
  accounts,
  filters,
  totalCount,
  totalPages,
}: Readonly<{
  accounts: readonly ManagedAccount[];
  filters: ManagedAccountListInput;
  totalCount: number;
  totalPages: number;
}>) {
  const hasFilters = filters.search !== "" || filters.role !== "all" || filters.status !== "all";

  if (accounts.length === 0) {
    return (
      <EmptyState
        icon={Users}
        title={hasFilters ? "No matching accounts" : "No accounts"}
        description={hasFilters ? "Change or clear the account filters." : "Dispatcher and Driver accounts will appear here."}
      />
    );
  }

  return (
    <TableCard
      title="Managed accounts"
      description={`${totalCount} ${totalCount === 1 ? "account" : "accounts"}`}
      footer={totalPages > 1 ? (
        <Pagination>
          <PaginationItem>{filters.page === 1 ? <PaginationPrevious disabled /> : <PaginationPrevious href={accountUrl(filters, filters.page - 1)} />}</PaginationItem>
          {Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => (
            <PaginationItem key={page}><PaginationLink href={accountUrl(filters, page)} active={page === filters.page}>{page}</PaginationLink></PaginationItem>
          ))}
          <PaginationItem>{filters.page === totalPages ? <PaginationNext disabled /> : <PaginationNext href={accountUrl(filters, filters.page + 1)} />}</PaginationItem>
        </Pagination>
      ) : undefined}
    >
      <TableScrollArea aria-label="Managed accounts table">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Full name</TableHead>
              <TableHead>Username</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Account status</TableHead>
              <TableHead>Created at</TableHead>
              <TableHead><span className="sr-only">Actions</span></TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {accounts.map((account) => (
              <TableRow key={account.username}>
                <TableCell className="font-medium">{account.fullName}</TableCell>
                <TableCell>{account.username}</TableCell>
                <TableCell className="capitalize">{account.role}</TableCell>
                <TableCell><StatusBadge domain="account" status={account.status} /></TableCell>
                <TableCell><time dateTime={account.createdAt}>{dateFormatter.format(new Date(account.createdAt))}</time></TableCell>
                <TableCell className="text-right"><AccountActions account={account} /></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableScrollArea>
    </TableCard>
  );
}
