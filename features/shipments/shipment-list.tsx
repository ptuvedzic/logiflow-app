import { Pagination, PaginationItem, PaginationLink, PaginationNext, PaginationPrevious } from "@/components/ui/pagination";
import { StatusBadge } from "@/components/ui/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import type { ShipmentCandidateData, ShipmentListItem } from "@/lib/dal/shipments";
import { requireRole } from "@/lib/dal/auth";
import { ShipmentCancellation } from "./shipment-cancellation";
import { ShipmentDelayAction } from "./shipment-delay-action";
import { ShipmentAssignment } from "./shipment-assignment";
import type { ShipmentListInput } from "./shipment-schema";

function shipmentUrl(filters: ShipmentListInput, page: number) {
  const params = new URLSearchParams();
  if (filters.search) params.set("search", filters.search);
  if (filters.status !== "all") params.set("status", filters.status);
  if (filters.delayed !== "all") params.set("delayed", filters.delayed);
  if (page > 1) params.set("page", String(page));
  const query = params.toString();
  return query ? `/operations/shipments?${query}` : "/operations/shipments";
}

export async function ShipmentList({ shipments, filters, totalCount, totalPages, candidates }: Readonly<{
  shipments: readonly ShipmentListItem[];
  filters: ShipmentListInput;
  totalCount: number;
  totalPages: number;
  candidates: ShipmentCandidateData;
}>) {
  const actor=await requireRole("admin","dispatcher");
  const canOperate=actor.ok;
  const footer = totalPages > 1 ? (
    <Pagination>
      <PaginationItem>{filters.page === 1 ? <PaginationPrevious disabled /> : <PaginationPrevious href={shipmentUrl(filters, filters.page - 1)} />}</PaginationItem>
      {Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => <PaginationItem key={page}><PaginationLink href={shipmentUrl(filters, page)} active={page === filters.page}>{page}</PaginationLink></PaginationItem>)}
      <PaginationItem>{filters.page === totalPages ? <PaginationNext disabled /> : <PaginationNext href={shipmentUrl(filters, filters.page + 1)} />}</PaginationItem>
    </Pagination>
  ) : undefined;

  return <TableCard title="Shipments" description={`${totalCount} ${totalCount === 1 ? "shipment" : "shipments"}`} footer={footer}>
    <TableScrollArea aria-label="Shipments table"><Table><TableHeader><TableRow><TableHead>Tracking</TableHead><TableHead>Client</TableHead><TableHead>Route</TableHead><TableHead>Driver</TableHead><TableHead>Vehicle</TableHead><TableHead>Status</TableHead><TableHead>Delayed</TableHead><TableHead>Actions</TableHead></TableRow></TableHeader><TableBody>
      {shipments.length === 0 ? <TableRow><TableCell colSpan={8} className="text-center text-secondary">No shipments found.</TableCell></TableRow> : shipments.map((shipment) => <TableRow key={shipment.id}>
        <TableCell className="font-medium">{shipment.trackingNumber}</TableCell><TableCell>{shipment.clientCompany}</TableCell><TableCell>{shipment.pickupAddress} to {shipment.deliveryAddress}</TableCell><TableCell>{shipment.driverName ?? "Unassigned"}</TableCell><TableCell>{shipment.vehicleRegistration ?? "Unassigned"}</TableCell><TableCell><StatusBadge domain="shipment" status={shipment.status} /></TableCell><TableCell>{shipment.delayed ? <StatusBadge domain="shipment_condition" status="delayed" /> : "No"}</TableCell><TableCell>{canOperate&&shipment.status!=="delivered"&&shipment.status!=="cancelled"?<div className="flex min-w-max items-center gap-2">{shipment.status==="pending"?<ShipmentAssignment shipmentId={shipment.id} candidates={candidates}/>:null}{shipment.status==="pending"||shipment.status==="assigned"||shipment.status==="loading"?<Link href={`/operations/shipments/${shipment.id}/edit`} className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10">Edit</Link>:null}{shipment.status==="in_transit"?<ShipmentDelayAction shipmentId={shipment.id} trackingNumber={shipment.trackingNumber} delayed={shipment.delayed} updatedAt={shipment.updatedAt}/>:null}<ShipmentCancellation shipmentId={shipment.id} trackingNumber={shipment.trackingNumber}/></div>:"No actions"}</TableCell>
      </TableRow>)}
    </TableBody></Table></TableScrollArea>
  </TableCard>;
}
import Link from "next/link";
