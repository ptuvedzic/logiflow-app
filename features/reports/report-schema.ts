import { z } from "zod";

const reportDate = z.string().trim().refine((value) => z.iso.date().safeParse(value).success, "Enter a valid date.");

export const reportFilterSchema = z.object({
  from: reportDate,
  to: reportDate,
}).superRefine((value, context) => {
  if (value.from > value.to) {
    context.addIssue({ code: "custom", path: ["to"], message: "End date must be on or after the start date." });
    return;
  }

  const inclusiveDays = Math.round((Date.parse(`${value.to}T00:00:00Z`) - Date.parse(`${value.from}T00:00:00Z`)) / 86_400_000) + 1;
  if (inclusiveDays > 366) {
    context.addIssue({ code: "custom", path: ["to"], message: "Choose a range of 366 days or fewer." });
  }
});

const count = z.number().int().nonnegative();
const money = z.number();

const shipmentStatuses = ["pending", "assigned", "loading", "in_transit", "delivered", "cancelled"] as const;
const vehicleStatuses = ["available", "in_use", "maintenance", "out_of_service", "archived"] as const;
const driverStatuses = ["available", "assigned", "off_duty", "inactive", "archived"] as const;

export const adminReportSnapshotSchema = z.object({
  period: z.object({
    from: z.iso.date(),
    to: z.iso.date(),
    bucket_granularity: z.enum(["day", "week", "month"]),
  }),
  financial: z.object({
    completed_shipments: count,
    revenue: money,
    total_expenses: money,
    profit: money,
  }),
  shipments: z.object({
    scheduled_shipments: count,
    completed_shipments: count,
    delayed_shipments: count,
    statuses: z.array(z.object({ status: z.enum(shipmentStatuses), count })),
    volume: z.array(z.object({ bucket_start: z.iso.date(), bucket_end: z.iso.date(), count })),
  }),
  fleet: z.object({
    available_vehicles: count,
    in_use_vehicles: count,
    serviceable_vehicles: count,
    utilization_percent: z.number().min(0).max(100).nullable(),
    statuses: z.array(z.object({ status: z.enum(vehicleStatuses), count })),
    maintenance: z.object({
      records: count,
      vehicles_serviced: count,
      costed_records: count,
      recorded_cost: money,
    }),
  }),
  drivers: z.object({
    statuses: z.array(z.object({ status: z.enum(driverStatuses), count })),
    completions: z.array(z.object({
      driver_id: z.uuid(),
      driver_name: z.string().min(1),
      completed_shipments: count,
    })).max(100),
  }),
  clients: z.array(z.object({
    client_id: z.uuid(),
    company_name: z.string().min(1),
    completed_shipments: count,
    revenue: money,
  })).max(100),
});

export type ReportFilters = Readonly<z.infer<typeof reportFilterSchema>>;
export type AdminReportSnapshot = Readonly<z.infer<typeof adminReportSnapshotSchema>>;

export function getBelgradeToday(now = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Belgrade",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const value = (type: Intl.DateTimeFormatPartTypes) => parts.find((part) => part.type === type)?.value;
  return `${value("year")}-${value("month")}-${value("day")}`;
}

export function getDefaultReportFilters(now = new Date()): ReportFilters {
  const to = getBelgradeToday(now);
  return { from: `${to.slice(0, 8)}01`, to };
}
