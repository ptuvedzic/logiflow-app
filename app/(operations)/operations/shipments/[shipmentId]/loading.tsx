export default function ShipmentDetailLoading() {
  return (
    <div className="flex animate-pulse flex-col gap-4 motion-reduce:animate-none" aria-label="Loading Shipment details">
      <div className="h-12 w-64 rounded-control bg-border-subtle" />
      <div className="grid gap-4 lg:grid-cols-[2fr_1fr]">
        <div className="h-64 rounded-card border border-border bg-background-card" />
        <div className="h-64 rounded-card border border-border bg-background-card" />
      </div>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 3 }, (_, index) => <div key={index} className="h-32 rounded-card border border-border bg-background-card" />)}
      </div>
      <div className="h-72 rounded-card border border-border bg-background-card" />
    </div>
  );
}
