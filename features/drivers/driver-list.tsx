import { UserRound } from "lucide-react";
import { EmptyState } from "@/components/ui/empty-state";
import { Pagination, PaginationItem, PaginationLink, PaginationNext, PaginationPrevious } from "@/components/ui/pagination";
import { StatusBadge } from "@/components/ui/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import { DriverActions } from "@/features/drivers/driver-actions";
import type { DriverListInput, DriverListItem } from "@/lib/dal/drivers";

function driverUrl(filters: DriverListInput, page: number) { const params = new URLSearchParams(); if (filters.search) params.set("search", filters.search); if (filters.status !== "all") params.set("status", filters.status); if (filters.account !== "all") params.set("account", filters.account); if (page > 1) params.set("page", String(page)); const query = params.toString(); return query ? `/operations/drivers?${query}` : "/operations/drivers"; }

export function DriverList({ drivers, filters, totalCount, totalPages, role }: Readonly<{ drivers: readonly DriverListItem[]; filters: DriverListInput; totalCount: number; totalPages: number; role: "admin" | "dispatcher" }>) {
  const filtered = filters.search !== "" || filters.status !== "all" || filters.account !== "all";
  if (!drivers.length) return <EmptyState icon={UserRound} title={filtered ? "No matching drivers." : "No drivers."} description={filtered ? "Change or clear the Driver filters." : "Drivers will appear here after an Admin provisions their accounts."} />;
  return <TableCard title="Drivers" description={`${totalCount} ${totalCount === 1 ? "driver" : "drivers"}`} footer={totalPages > 1 ? <Pagination><PaginationItem>{filters.page === 1 ? <PaginationPrevious disabled /> : <PaginationPrevious href={driverUrl(filters, filters.page - 1)} />}</PaginationItem>{Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => <PaginationItem key={page}><PaginationLink href={driverUrl(filters, page)} active={page === filters.page}>{page}</PaginationLink></PaginationItem>)}<PaginationItem>{filters.page === totalPages ? <PaginationNext disabled /> : <PaginationNext href={driverUrl(filters, filters.page + 1)} />}</PaginationItem></Pagination> : undefined}>
    <TableScrollArea aria-label="Drivers table"><Table><TableHeader><TableRow><TableHead>Driver</TableHead><TableHead>Username</TableHead><TableHead>Phone</TableHead><TableHead>Account status</TableHead><TableHead>Driver status</TableHead><TableHead><span className="sr-only">Actions</span></TableHead></TableRow></TableHeader><TableBody>{drivers.map((driver) => <TableRow key={driver.id}><TableCell className="font-medium">{driver.fullName}</TableCell><TableCell>{driver.username}</TableCell><TableCell>{driver.phone ?? "—"}</TableCell><TableCell><StatusBadge domain="account" status={driver.accountActive ? "active" : "inactive"} /></TableCell><TableCell><StatusBadge domain="driver" status={driver.status} /></TableCell><TableCell className="text-right">{role === "admin" && driver.accountActive && driver.status !== "inactive" ? <DriverActions driver={driver} /> : "—"}</TableCell></TableRow>)}</TableBody></Table></TableScrollArea>
  </TableCard>;
}
