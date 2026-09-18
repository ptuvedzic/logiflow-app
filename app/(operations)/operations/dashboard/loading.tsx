import { PageHeader } from "@/components/ui/page-header";

const skeleton = "animate-pulse rounded-card border border-border-subtle bg-background-card motion-reduce:animate-none";

export default function OperationsDashboardLoading() {
  return (
    <div className="flex min-w-0 flex-col gap-4" aria-busy="true" aria-label="Loading Operations dashboard">
      <PageHeader title="Dashboard" description="Monitor the current state of logistics operations." />
      <div className="h-11 animate-pulse rounded-control bg-background-hover motion-reduce:animate-none md:w-96" />
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {Array.from({ length: 4 }, (_, index) => <div className={`${skeleton} h-36`} key={index} />)}
      </div>
      <div className="grid gap-4 xl:grid-cols-[2fr_1fr]">
        <div className={`${skeleton} h-80`} />
        <div className={`${skeleton} h-80`} />
      </div>
      <div className={`${skeleton} h-72`} />
    </div>
  );
}
