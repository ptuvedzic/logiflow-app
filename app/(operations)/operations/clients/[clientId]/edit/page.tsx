import Link from "next/link";
import { notFound } from "next/navigation";
import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ClientForm } from "@/features/clients/client-form";
import { clientTargetSchema } from "@/features/clients/client-schema";
import { getClient } from "@/lib/dal/clients";

type Props = Readonly<{ params: Promise<{ clientId: string }> }>;
export default async function EditClientPage({ params }: Props) {
  const parsed = clientTargetSchema.safeParse(await params); if (!parsed.success) notFound();
  const result = await getClient(parsed.data.clientId);
  if (!result.ok) { if (result.error.category === "not_found") notFound(); if (result.error.category === "infrastructure" || result.error.category === "conflict" || result.error.category === "business_rule") throw new Error("Unable to load the client."); handleAuthBoundaryFailure(result.error); }
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Edit client" description={`Update ${result.data.companyName}.`} actions={<Link href="/operations/clients" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to clients</Link>} /><Card><ClientForm client={result.data} /></Card></div>;
}
