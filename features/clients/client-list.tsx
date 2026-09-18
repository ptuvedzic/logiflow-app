import { Building2 } from "lucide-react";
import { ClientActions } from "@/features/clients/client-actions";
import { EmptyState } from "@/components/ui/empty-state";
import { Pagination, PaginationItem, PaginationLink, PaginationNext, PaginationPrevious } from "@/components/ui/pagination";
import { StatusBadge } from "@/components/ui/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import type { ClientListInput, ClientListItem } from "@/lib/dal/clients";

function clientUrl(filters: ClientListInput, page: number) { const params = new URLSearchParams(); if (filters.search) params.set("search", filters.search); if (filters.status !== "all") params.set("status", filters.status); if (page > 1) params.set("page", String(page)); const query = params.toString(); return query ? `/operations/clients?${query}` : "/operations/clients"; }
export function ClientList({ clients, filters, totalCount, totalPages }: Readonly<{ clients: readonly ClientListItem[]; filters: ClientListInput; totalCount: number; totalPages: number }>) {
  const filtered = filters.search !== "" || filters.status !== "all";
  if (!clients.length) return <EmptyState icon={Building2} title={filtered ? "No matching clients." : "No clients."} description={filtered ? "Change or clear the client filters." : "Clients will appear here after they are created."} />;
  return <TableCard title="Clients" description={`${totalCount} ${totalCount === 1 ? "client" : "clients"}`} footer={totalPages > 1 ? <Pagination><PaginationItem>{filters.page === 1 ? <PaginationPrevious disabled /> : <PaginationPrevious href={clientUrl(filters, filters.page - 1)} />}</PaginationItem>{Array.from({ length: totalPages }, (_, i) => i + 1).map((page) => <PaginationItem key={page}><PaginationLink href={clientUrl(filters, page)} active={page === filters.page}>{page}</PaginationLink></PaginationItem>)}<PaginationItem>{filters.page === totalPages ? <PaginationNext disabled /> : <PaginationNext href={clientUrl(filters, filters.page + 1)} />}</PaginationItem></Pagination> : undefined}>
    <TableScrollArea aria-label="Clients table"><Table><TableHeader><TableRow><TableHead>Company</TableHead><TableHead>Contact person</TableHead><TableHead>Phone</TableHead><TableHead>Email</TableHead><TableHead>Status</TableHead><TableHead><span className="sr-only">Actions</span></TableHead></TableRow></TableHeader><TableBody>{clients.map((client) => <TableRow key={client.id}><TableCell className="font-medium">{client.companyName}</TableCell><TableCell>{client.contactPerson ?? "—"}</TableCell><TableCell>{client.phone ?? "—"}</TableCell><TableCell>{client.email ?? "—"}</TableCell><TableCell><StatusBadge domain="client" status={client.status} /></TableCell><TableCell className="text-right"><ClientActions client={client} /></TableCell></TableRow>)}</TableBody></Table></TableScrollArea>
  </TableCard>;
}
