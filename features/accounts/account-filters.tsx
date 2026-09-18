import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { ManagedAccountListInput } from "@/lib/dal/accounts";

export function AccountFilters({ filters }: Readonly<{ filters: ManagedAccountListInput }>) {
  return (
    <form action="/operations/accounts" method="get">
      <TableToolbar
        leading={
          <>
            <div className="flex min-w-[min(100%,16rem)] flex-1 flex-col gap-1">
              <label className="sr-only" htmlFor="account-search">Search accounts</label>
              <Input id="account-search" name="search" type="search" defaultValue={filters.search} placeholder="Search name or username" maxLength={100} focusSurface="card" />
            </div>
            <div className="flex flex-1 flex-col gap-1 sm:flex-none">
              <label className="sr-only" htmlFor="account-role">Role</label>
              <Select id="account-role" name="role" defaultValue={filters.role} focusSurface="card">
                <option value="all">All roles</option>
                <option value="dispatcher">Dispatcher</option>
                <option value="driver">Driver</option>
              </Select>
            </div>
            <div className="flex flex-1 flex-col gap-1 sm:flex-none">
              <label className="sr-only" htmlFor="account-status">Account status</label>
              <Select id="account-status" name="status" defaultValue={filters.status} focusSurface="card">
                <option value="all">All statuses</option>
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </Select>
            </div>
          </>
        }
        trailing={
          <>
            <Button type="submit" variant="outline" focusSurface="card">Apply</Button>
            <Link href="/operations/accounts" className="inline-flex h-10 items-center justify-center rounded-control border border-transparent px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card">Clear</Link>
          </>
        }
      />
    </form>
  );
}
