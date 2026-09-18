import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { DriverListInput } from "@/lib/dal/drivers";

export function DriverFilters({ filters }: Readonly<{ filters: DriverListInput }>) {
  return <form action="/operations/drivers" method="get"><TableToolbar leading={<>
    <div className="flex min-w-[min(100%,16rem)] flex-1 flex-col gap-1"><label className="sr-only" htmlFor="driver-search">Search drivers</label><Input id="driver-search" name="search" type="search" defaultValue={filters.search} placeholder="Search name or username" maxLength={100} className="min-h-11 md:min-h-10" focusSurface="card" /></div>
    <div className="flex flex-1 flex-col gap-1 sm:flex-none"><label className="sr-only" htmlFor="driver-status">Driver status</label><Select id="driver-status" name="status" defaultValue={filters.status} className="min-h-11 md:min-h-10" focusSurface="card"><option value="all">All Driver statuses</option><option value="available">Available</option><option value="assigned">Assigned</option><option value="off_duty">Off duty</option><option value="inactive">Inactive</option><option value="archived">Archived</option></Select></div>
    <div className="flex flex-1 flex-col gap-1 sm:flex-none"><label className="sr-only" htmlFor="driver-account">Account status</label><Select id="driver-account" name="account" defaultValue={filters.account} className="min-h-11 md:min-h-10" focusSurface="card"><option value="all">All account statuses</option><option value="active">Active accounts</option><option value="inactive">Inactive accounts</option></Select></div>
  </>} trailing={<><Button type="submit" variant="outline" className="min-h-11 md:min-h-10" focusSurface="card">Apply</Button><Link href="/operations/drivers" className="inline-flex min-h-11 items-center justify-center rounded-control border border-transparent px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10">Clear</Link></>} /></form>;
}
