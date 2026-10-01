import "server-only";

import type { AdminReportSnapshot, ReportFilters } from "@/features/reports/report-schema";
import { adminReportSnapshotSchema } from "@/features/reports/report-schema";
import { requireRole } from "@/lib/dal/auth";
import type { AuthBoundaryError } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";

type ReportError = AuthBoundaryError | Readonly<{
  category: "validation" | "infrastructure";
  message: string;
}>;

export type ReportResult<T> = Readonly<{ ok: true; data: T }> | Readonly<{ ok: false; error: ReportError }>;

export async function getAdminReports(filters: ReportFilters): Promise<ReportResult<AdminReportSnapshot>> {
  const actor = await requireRole("admin");
  if (!actor.ok) return actor;

  const client = await createClient();
  const { data, error } = await client.rpc("get_admin_reports", {
    report_from: filters.from,
    report_to: filters.to,
  });

  if (error) {
    if (error.message.includes("admin_reports_access_denied")) {
      return { ok: false, error: { category: "forbidden", message: "Access denied." } };
    }
    if (error.message.includes("admin_reports_date_invalid")) {
      return { ok: false, error: { category: "validation", message: "Choose a valid historical range of 366 days or fewer." } };
    }
    return { ok: false, error: { category: "infrastructure", message: "Unable to load reports." } };
  }

  const parsed = adminReportSnapshotSchema.safeParse(data);
  if (!parsed.success) {
    return { ok: false, error: { category: "infrastructure", message: "Unable to load reports." } };
  }

  return { ok: true, data: parsed.data };
}
