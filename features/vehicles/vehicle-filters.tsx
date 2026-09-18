import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { VehicleListInput } from "@/lib/dal/vehicles";

export function VehicleFilters({ filters, types }: Readonly<{ filters: VehicleListInput; types: readonly string[] }>) {
  return <form action="/operations/vehicles" method="get"><TableToolbar leading={<>
    <div className="flex min-w-[min(100%,16rem)] flex-1 flex-col gap-1"><label className="sr-only" htmlFor="vehicle-search">Search vehicles</label><Input id="vehicle-search" name="search" type="search" defaultValue={filters.search} placeholder="Search registration or model" maxLength={100} className="min-h-11 md:min-h-10" focusSurface="card" /></div>
    <div className="flex flex-1 flex-col gap-1 sm:flex-none"><label className="sr-only" htmlFor="vehicle-status">Vehicle status</label><Select id="vehicle-status" name="status" defaultValue={filters.status} className="min-h-11 md:min-h-10" focusSurface="card"><option value="all">All statuses</option><option value="available">Available</option><option value="in_use">In use</option><option value="maintenance">Maintenance</option><option value="out_of_service">Out of service</option><option value="archived">Archived</option></Select></div>
    <div className="flex flex-1 flex-col gap-1 sm:flex-none"><label className="sr-only" htmlFor="vehicle-type">Vehicle type</label><Select id="vehicle-type" name="type" defaultValue={filters.type} className="min-h-11 md:min-h-10" focusSurface="card"><option value="all">All types</option>{types.map((type) => <option key={type} value={type}>{type}</option>)}</Select></div>
  </>} trailing={<><Button type="submit" variant="outline" className="min-h-11 md:min-h-10" focusSurface="card">Apply</Button><Link href="/operations/vehicles" className="inline-flex min-h-11 items-center justify-center rounded-control border border-transparent px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10">Clear</Link></>} /></form>;
}
