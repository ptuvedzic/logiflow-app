import Link from "next/link";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { ReportFilters } from "@/features/reports/report-schema";

export function ReportFilters({ filters, errors = {} }: Readonly<{
  filters: ReportFilters;
  errors?: Readonly<Partial<Record<keyof ReportFilters | "form", string>>>;
}>) {
  return (
    <form action="/operations/reports" method="get" aria-describedby={errors.form ? "report-filter-error" : undefined}>
      <TableToolbar
        leading={<>
          <div className="flex flex-col gap-2">
            <label className="text-label text-secondary" htmlFor="report-from">From</label>
            <Input id="report-from" name="from" type="date" defaultValue={filters.from} invalid={Boolean(errors.from)} aria-describedby={errors.from ? "report-from-error" : undefined} className="min-h-11 md:min-h-10" focusSurface="card" />
            {errors.from ? <p id="report-from-error" className="text-small text-danger">{errors.from}</p> : null}
          </div>
          <div className="flex flex-col gap-2">
            <label className="text-label text-secondary" htmlFor="report-to">To</label>
            <Input id="report-to" name="to" type="date" defaultValue={filters.to} invalid={Boolean(errors.to)} aria-describedby={errors.to ? "report-to-error" : undefined} className="min-h-11 md:min-h-10" focusSurface="card" />
            {errors.to ? <p id="report-to-error" className="text-small text-danger">{errors.to}</p> : null}
          </div>
        </>}
        trailing={<>
          <Button type="submit" variant="outline" className="min-h-11 md:min-h-10" focusSurface="card">Apply</Button>
          <Link href="/operations/reports" className="inline-flex min-h-11 items-center justify-center rounded-control px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:min-h-10">Reset</Link>
        </>}
      />
      {errors.form ? <p id="report-filter-error" role="alert" className="mt-2 text-small text-danger">{errors.form}</p> : null}
    </form>
  );
}
