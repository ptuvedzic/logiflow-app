import { Wrench } from "lucide-react";
import Link from "next/link";
import { EmptyState } from "@/components/ui/empty-state";
import { Pagination, PaginationItem, PaginationLink, PaginationNext, PaginationPrevious } from "@/components/ui/pagination";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import type { MaintenanceListInput } from "./maintenance-schema";
import type { MaintenanceListItem } from "@/lib/dal/maintenance";

const dateFormatter = new Intl.DateTimeFormat("en-GB", { year: "numeric", month: "short", day: "numeric", timeZone: "UTC" });
const currencyFormatter = new Intl.NumberFormat("en-IE", { style: "currency", currency: "EUR" });
const date = (value: string) => dateFormatter.format(new Date(`${value}T12:00:00Z`));
function url(filters: MaintenanceListInput, page: number) { const p = new URLSearchParams(); if (filters.search) p.set("search", filters.search); if (filters.vehicle !== "all") p.set("vehicle", filters.vehicle); if (filters.from) p.set("from", filters.from); if (filters.to) p.set("to", filters.to); if (page > 1) p.set("page", String(page)); const q = p.toString(); return q ? `/operations/maintenance?${q}` : "/operations/maintenance"; }
function nextService(record: MaintenanceListItem) { const parts = []; if (record.nextServiceDate) parts.push(date(record.nextServiceDate)); if (record.nextServiceMileage !== null) parts.push(`${record.nextServiceMileage.toLocaleString()} km`); return parts.length ? parts.join(" · ") : "—"; }

export function MaintenanceList({ records, filters, totalCount, totalPages, role }: Readonly<{ records: readonly MaintenanceListItem[]; filters: MaintenanceListInput; totalCount: number; totalPages: number; role: "admin" | "dispatcher" }>) {
  const filtered = filters.search !== "" || filters.vehicle !== "all" || filters.from !== "" || filters.to !== "";
  if (!records.length) return <EmptyState icon={Wrench} title={filtered ? "No matching maintenance records." : "No maintenance records."} description={filtered ? "Change or clear the maintenance filters." : "Maintenance history will appear after an Admin records service."} />;
  const footer = totalPages > 1 ? <Pagination><PaginationItem>{filters.page === 1 ? <PaginationPrevious disabled /> : <PaginationPrevious href={url(filters, filters.page - 1)} />}</PaginationItem>{Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => <PaginationItem key={page}><PaginationLink href={url(filters, page)} active={page === filters.page}>{page}</PaginationLink></PaginationItem>)}<PaginationItem>{filters.page === totalPages ? <PaginationNext disabled /> : <PaginationNext href={url(filters, filters.page + 1)} />}</PaginationItem></Pagination> : undefined;
  return <TableCard title="Maintenance history" description={`${totalCount} ${totalCount === 1 ? "record" : "records"}`} footer={footer}><TableScrollArea aria-label="Vehicle maintenance records table"><Table><TableHeader><TableRow><TableHead>Vehicle</TableHead><TableHead>Service type</TableHead><TableHead>Service date</TableHead><TableHead>Mileage</TableHead><TableHead>Workshop</TableHead><TableHead>Cost</TableHead><TableHead>Next service</TableHead><TableHead>Actions</TableHead></TableRow></TableHeader><TableBody>{records.map((record) => <TableRow key={record.id}><TableCell className="font-medium">{record.vehicleRegistration}</TableCell><TableCell>{record.serviceType}</TableCell><TableCell><time dateTime={record.serviceDate}>{date(record.serviceDate)}</time></TableCell><TableCell>{record.mileageAtService.toLocaleString()} km</TableCell><TableCell>{record.workshop ?? "—"}</TableCell><TableCell>{record.cost === null ? "—" : currencyFormatter.format(record.cost)}</TableCell><TableCell>{nextService(record)}</TableCell><TableCell className="text-right">{role === "admin" ? <Link className="font-medium text-primary hover:underline" href={`/operations/maintenance/${record.id}/edit`}>Edit</Link> : "—"}</TableCell></TableRow>)}</TableBody></Table></TableScrollArea></TableCard>;
}
