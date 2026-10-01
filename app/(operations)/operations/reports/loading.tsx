import { PageHeader } from "@/components/ui/page-header";

const skeleton = "animate-pulse rounded-card border border-border bg-background-card motion-reduce:animate-none";

export default function AdminReportsLoading() {
  return <div className="flex min-w-0 flex-col gap-6" aria-busy="true" aria-label="Loading Admin Reports">
    <PageHeader title="Reports" description="Review company-wide operational and financial performance." />
    <div className={`${skeleton} h-28`} />
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{Array.from({ length: 4 }, (_, index) => <div className={`${skeleton} h-36`} key={index} />)}</div>
    {Array.from({ length: 4 }, (_, index) => <div className="flex flex-col gap-4" key={index}><div className="h-8 w-40 animate-pulse rounded-control bg-border-subtle motion-reduce:animate-none" /><div className="grid gap-4 xl:grid-cols-2"><div className={`${skeleton} h-72`} /><div className={`${skeleton} h-72`} /></div></div>)}
  </div>;
}
