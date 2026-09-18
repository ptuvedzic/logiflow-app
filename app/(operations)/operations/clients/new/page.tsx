import Link from "next/link";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ClientForm } from "@/features/clients/client-form";

export default function NewClientPage() {
  return <div className="flex min-w-0 flex-col gap-4"><PageHeader title="Create client" description="Add a client for future logistics operations." actions={<Link href="/operations/clients" className="inline-flex min-h-11 items-center justify-center rounded-control border border-input bg-background-card px-4 text-label text-secondary hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app md:min-h-10">Back to clients</Link>} /><Card><ClientForm /></Card></div>;
}
