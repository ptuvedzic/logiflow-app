import { StatusBadge } from "@/components/ui/status-badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { TableCard } from "@/components/ui/table-card";
import { TableScrollArea } from "@/components/ui/table-scroll-area";
import { ShipmentStatusRequestActions } from "@/features/shipments/shipment-status-request-actions";
import type { PendingStatusRequest } from "@/lib/dal/shipments";

const formatter=new Intl.DateTimeFormat("en",{dateStyle:"medium",timeStyle:"short"});

export function PendingStatusRequestList({requests}:Readonly<{requests:readonly PendingStatusRequest[]}>){
  return <TableCard title="Pending Status Requests" description={`${requests.length} pending ${requests.length===1?"request":"requests"}`}><TableScrollArea aria-label="Pending status requests table"><Table><TableHeader><TableRow><TableHead>Tracking</TableHead><TableHead>Driver</TableHead><TableHead>Current status</TableHead><TableHead>Requested status</TableHead><TableHead>Requested at</TableHead><TableHead>Actions</TableHead></TableRow></TableHeader><TableBody>{requests.length===0?<TableRow><TableCell colSpan={6} className="text-center text-secondary">No pending status requests.</TableCell></TableRow>:requests.map((request)=><TableRow key={request.id}><TableCell className="font-medium">{request.trackingNumber}</TableCell><TableCell>{request.driverName}</TableCell><TableCell><StatusBadge domain="shipment" status={request.currentStatus}/></TableCell><TableCell><StatusBadge domain="shipment" status={request.requestedStatus}/></TableCell><TableCell>{formatter.format(new Date(request.requestedAt))}</TableCell><TableCell><ShipmentStatusRequestActions requestId={request.id} trackingNumber={request.trackingNumber}/></TableCell></TableRow>)}</TableBody></Table></TableScrollArea></TableCard>;
}
