import Link from "next/link";
import { notFound } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { DriverForm } from "@/features/drivers/driver-form";
import { driverTargetSchema } from "@/features/drivers/driver-schema";
import { getDriver } from "@/lib/dal/drivers";

type Props = Readonly<{ params: Promise<{ driverId: string }> }>;
export default async function EditDriverPage({ params }: Props) {
  const parsed = driverTargetSchema.safeParse(await params); if (!parsed.success) notFound();
  const result = await getDriver(parsed.data.driverId, true);
  if (!result.ok) { if (result.error.category === "not_found") notFound(); if (result.error.category === "infrastructure" || result.error.category === "conflict" || result.error.category === "business_rule") throw new Error("Unable to load the driver."); handleAuthBoundaryFailure(result.error); }
  if (!result.data.accountActive || result.data.status === "inactive") notFound();
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Edit Driver phone" description={`Update ${result.data.fullName}.`} actions={<Link href="/operations/drivers" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to drivers</Link>} /><Card><DriverForm driver={result.data} /></Card></div>;
}
