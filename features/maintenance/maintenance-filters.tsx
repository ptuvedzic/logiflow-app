import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { MaintenanceListInput } from "./maintenance-schema";
import type { MaintenanceVehicleOption } from "@/lib/dal/maintenance";

export function MaintenanceFilters({ filters, vehicles }: Readonly<{ filters: MaintenanceListInput; vehicles: readonly MaintenanceVehicleOption[] }>) {
  return <form action="/operations/maintenance" method="get"><TableToolbar leading={<>
    <div className="flex min-w-[min(100%,16rem)] flex-1 flex-col gap-1"><label className="sr-only" htmlFor="maintenance-search">Search maintenance</label><Input id="maintenance-search" name="search" type="search" defaultValue={filters.search} placeholder="Search Vehicle, service or workshop" maxLength={100} className="min-h-11 md:min-h-10" focusSurface="card" /></div>
    <Select aria-label="Filter by Vehicle" name="vehicle" defaultValue={filters.vehicle} className="min-h-11 md:min-h-10" focusSurface="card"><option value="all">All Vehicles</option>{vehicles.map((vehicle) => <option key={vehicle.id} value={vehicle.id}>{vehicle.registration}</option>)}</Select>
    <div><label className="sr-only" htmlFor="maintenance-from">Service date from</label><Input id="maintenance-from" name="from" type="date" defaultValue={filters.from} className="min-h-11 md:min-h-10" focusSurface="card" /></div>
    <div><label className="sr-only" htmlFor="maintenance-to">Service date to</label><Input id="maintenance-to" name="to" type="date" defaultValue={filters.to} className="min-h-11 md:min-h-10" focusSurface="card" /></div>
  </>} trailing={<><Button type="submit" variant="outline" className="min-h-11 md:min-h-10" focusSurface="card">Apply</Button><Link href="/operations/maintenance" className="inline-flex min-h-11 items-center justify-center rounded-control px-4 text-label text-secondary hover:bg-background-hover">Clear</Link></>} /></form>;
}
