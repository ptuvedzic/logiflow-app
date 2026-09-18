import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { ClientListInput } from "@/lib/dal/clients";

export function ClientFilters({ filters }: Readonly<{ filters: ClientListInput }>) {
  return <form action="/operations/clients" method="get"><TableToolbar leading={<><div className="flex min-w-[min(100%,16rem)] flex-1 flex-col gap-1"><label className="sr-only" htmlFor="client-search">Search clients</label><Input id="client-search" name="search" type="search" defaultValue={filters.search} placeholder="Search company or contact" maxLength={100} className="min-h-11 md:min-h-10" focusSurface="card" /></div><div className="flex flex-1 flex-col gap-1 sm:flex-none"><label className="sr-only" htmlFor="client-status">Client status</label><Select id="client-status" name="status" defaultValue={filters.status} className="min-h-11 md:min-h-10" focusSurface="card"><option value="all">All statuses</option><option value="active">Active</option><option value="archived">Archived</option></Select></div></>} trailing={<><Button type="submit" variant="outline" className="min-h-11 md:min-h-10" focusSurface="card">Apply</Button><Link href="/operations/clients" className="inline-flex min-h-11 items-center justify-center rounded-control border border-transparent px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10">Clear</Link></>} /></form>;
}
