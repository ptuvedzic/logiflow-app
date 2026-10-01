import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { ErrorState } from "@/components/ui/error-state";
import { PageHeader } from "@/components/ui/page-header";
import { ReportFilters } from "@/features/reports/report-filters";
import { ClientReports, DriverReports, FinancialReports, FleetReports, ShipmentReports } from "@/features/reports/report-sections";
import { getBelgradeToday, getDefaultReportFilters, reportFilterSchema } from "@/features/reports/report-schema";
import type { ReportFilters as ReportFilterValues } from "@/features/reports/report-schema";
import { requireRole } from "@/lib/dal/auth";
import { getAdminReports } from "@/lib/dal/reports";

type Props = Readonly<{ searchParams: Promise<Record<string, string | string[] | undefined>> }>;

function first(value: string | string[] | undefined) {
  return Array.isArray(value) ? value[0] : value;
}

export default async function AdminReportsPage({ searchParams }: Props) {
  const actor = await requireRole("admin");
  if (!actor.ok) handleAuthBoundaryFailure(actor.error);

  const defaults = getDefaultReportFilters();
  const query = await searchParams;
  const filters: ReportFilterValues = {
    from: first(query.from) ?? defaults.from,
    to: first(query.to) ?? defaults.to,
  };
  const parsed = reportFilterSchema.safeParse(filters);
  const futureError = parsed.success && parsed.data.to > getBelgradeToday()
    ? "End date cannot be in the future."
    : null;

  if (!parsed.success || futureError) {
    const flattened = parsed.success ? null : parsed.error.flatten();
    return <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="Reports" description="Review company-wide operational and financial performance." />
      <ReportFilters filters={filters} errors={{
        from: flattened?.fieldErrors.from?.[0],
        to: futureError ?? flattened?.fieldErrors.to?.[0],
        form: "Choose a valid historical range of 366 days or fewer.",
      }} />
      <ErrorState title="Report range unavailable" description="Correct the date range to load Admin Reports." />
    </div>;
  }

  const result = await getAdminReports(parsed.data);
  if (!result.ok) {
    if (result.error.category === "unauthenticated" || result.error.category === "missing_profile" || result.error.category === "inactive_profile" || result.error.category === "forbidden") {
      handleAuthBoundaryFailure(result.error);
    }
    if (result.error.category === "validation") {
      return <div className="flex min-w-0 flex-col gap-4">
        <PageHeader title="Reports" description="Review company-wide operational and financial performance." />
        <ReportFilters filters={parsed.data} errors={{ form: result.error.message }} />
        <ErrorState title="Report range unavailable" description={result.error.message} />
      </div>;
    }
    throw new Error("Unable to load Admin Reports.");
  }

  return <div className="flex min-w-0 flex-col gap-6">
    <PageHeader title="Reports" description="Review company-wide operational and financial performance." />
    <ReportFilters filters={parsed.data} />
    <FinancialReports data={result.data.financial} />
    <ShipmentReports data={result.data.shipments} granularity={result.data.period.bucket_granularity} />
    <FleetReports data={result.data.fleet} />
    <DriverReports data={result.data.drivers} />
    <ClientReports data={result.data.clients} />
  </div>;
}
