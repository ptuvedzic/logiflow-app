import type { LucideIcon } from "lucide-react";
import Link from "next/link";

import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

type KpiTone = "primary" | "info" | "success" | "warning";

export type KpiCardProps = Readonly<{
  label: string;
  value: number;
  supportingText: string;
  href: string;
  icon: LucideIcon;
  tone: KpiTone;
}>;

const toneClasses: Record<KpiTone, Readonly<{ container: string; icon: string }>> = {
  primary: { container: "bg-primary-soft", icon: "text-primary-icon" },
  info: { container: "bg-info-soft", icon: "text-info" },
  success: { container: "bg-success-soft", icon: "text-success" },
  warning: { container: "bg-warning-soft", icon: "text-warning-text" },
};

export function KpiCard({ label, value, supportingText, href, icon: Icon, tone }: KpiCardProps) {
  const classes = toneClasses[tone];

  return (
    <Link
      href={href}
      aria-label={`${label}: ${value}. ${supportingText}`}
      className="block rounded-card focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-app"
    >
      <Card variant="hover" className="h-full">
        <div className="flex items-start justify-between gap-4">
          <div className="min-w-0">
            <h2 className="text-label text-secondary">{label}</h2>
            <p className="mt-2 text-metric text-foreground">{value}</p>
          </div>
          <span className={cn("inline-flex size-10 shrink-0 items-center justify-center rounded-control", classes.container)}>
            <Icon aria-hidden="true" className={classes.icon} size={20} strokeWidth={1.75} />
          </span>
        </div>
        <p className="mt-2 break-words text-small text-secondary">{supportingText}</p>
      </Card>
    </Link>
  );
}
