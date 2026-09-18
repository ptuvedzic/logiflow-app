import { PageHeader } from "@/components/ui/page-header";

export default function DriverNotificationsLoading() {
  return (
    <div className="flex min-w-0 flex-col gap-4" aria-busy="true" aria-label="Loading notifications">
      <PageHeader title="Notifications" description="Review updates addressed to you." />
      <div className="h-12 animate-pulse rounded-card bg-background-hover motion-reduce:animate-none" />
      <div className="h-40 animate-pulse rounded-card border border-border-subtle bg-background-card motion-reduce:animate-none" />
      <div className="h-40 animate-pulse rounded-card border border-border-subtle bg-background-card motion-reduce:animate-none" />
    </div>
  );
}
