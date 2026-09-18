import type { ComponentPropsWithoutRef } from "react";

import { cn } from "@/lib/utils";

export type ShipmentBadgeStatus =
  | "pending"
  | "assigned"
  | "loading"
  | "in_transit"
  | "delivered"
  | "cancelled";

export type ShipmentConditionBadgeStatus = "delayed";

export type VehicleBadgeStatus =
  | "available"
  | "in_use"
  | "maintenance"
  | "out_of_service"
  | "archived";

export type DriverBadgeStatus =
  | "available"
  | "assigned"
  | "off_duty"
  | "inactive"
  | "archived";

export type ClientBadgeStatus = "active" | "archived";

export type DocumentBadgeStatus =
  | "valid"
  | "expiring"
  | "expired"
  | "no_expiry"
  | "archived";

export type StatusRequestBadgeStatus = "pending" | "approved" | "rejected";

export type AlertBadgeStatus = "active" | "resolved";
export type AlertSeverityBadgeStatus = "info" | "warning" | "critical";
export type AccountBadgeStatus = "active" | "inactive";

type StatusBadgeSelection =
  | { domain: "shipment"; status: ShipmentBadgeStatus }
  | { domain: "shipment_condition"; status: ShipmentConditionBadgeStatus }
  | { domain: "vehicle"; status: VehicleBadgeStatus }
  | { domain: "driver"; status: DriverBadgeStatus }
  | { domain: "client"; status: ClientBadgeStatus }
  | { domain: "document"; status: DocumentBadgeStatus }
  | { domain: "status_request"; status: StatusRequestBadgeStatus }
  | { domain: "alert"; status: AlertBadgeStatus }
  | { domain: "alert_severity"; status: AlertSeverityBadgeStatus }
  | { domain: "account"; status: AccountBadgeStatus };

type StatusBadgeNativeProps = Omit<
  ComponentPropsWithoutRef<"span">,
  "children"
>;

export type StatusBadgeProps = StatusBadgeNativeProps & StatusBadgeSelection;

type SemanticVariant =
  | "success"
  | "warning"
  | "danger"
  | "information"
  | "neutral";

type BadgeConfig = {
  label: string;
  variant: SemanticVariant;
};

const semanticClasses: Record<SemanticVariant, string> = {
  success: "border-success-border bg-success-soft text-success",
  warning: "border-warning-border bg-warning-soft text-warning-text",
  danger: "border-danger-border bg-danger-soft text-danger",
  information: "border-info-border bg-info-soft text-info",
  neutral: "border-border-strong bg-background-hover text-secondary",
};

function getBadgeConfig(selection: StatusBadgeSelection): BadgeConfig {
  switch (selection.domain) {
    case "shipment":
      return ({
        pending: { label: "Pending", variant: "warning" },
        assigned: { label: "Assigned", variant: "information" },
        loading: { label: "Loading", variant: "information" },
        in_transit: { label: "In transit", variant: "information" },
        delivered: { label: "Delivered", variant: "success" },
        cancelled: { label: "Cancelled", variant: "danger" },
      } satisfies Record<ShipmentBadgeStatus, BadgeConfig>)[selection.status];
    case "shipment_condition":
      return { label: "Delayed", variant: "warning" };
    case "vehicle":
      return ({
        available: { label: "Available", variant: "success" },
        in_use: { label: "In use", variant: "information" },
        maintenance: { label: "Maintenance", variant: "danger" },
        out_of_service: { label: "Out of service", variant: "warning" },
        archived: { label: "Archived", variant: "neutral" },
      } satisfies Record<VehicleBadgeStatus, BadgeConfig>)[selection.status];
    case "driver":
      return ({
        available: { label: "Available", variant: "success" },
        assigned: { label: "Assigned", variant: "information" },
        off_duty: { label: "Off duty", variant: "neutral" },
        inactive: { label: "Inactive", variant: "neutral" },
        archived: { label: "Archived", variant: "neutral" },
      } satisfies Record<DriverBadgeStatus, BadgeConfig>)[selection.status];
    case "client":
      return ({
        active: { label: "Active", variant: "success" },
        archived: { label: "Archived", variant: "neutral" },
      } satisfies Record<ClientBadgeStatus, BadgeConfig>)[selection.status];
    case "document":
      return ({
        valid: { label: "Valid", variant: "success" },
        expiring: { label: "Expiring soon", variant: "warning" },
        expired: { label: "Expired", variant: "danger" },
        no_expiry: { label: "No expiry", variant: "neutral" },
        archived: { label: "Archived", variant: "neutral" },
      } satisfies Record<DocumentBadgeStatus, BadgeConfig>)[selection.status];
    case "status_request":
      return ({
        pending: { label: "Pending", variant: "warning" },
        approved: { label: "Approved", variant: "success" },
        rejected: { label: "Rejected", variant: "danger" },
      } satisfies Record<StatusRequestBadgeStatus, BadgeConfig>)[selection.status];
    case "alert":
      return ({
        active: { label: "Active", variant: "danger" },
        resolved: { label: "Resolved", variant: "neutral" },
      } satisfies Record<AlertBadgeStatus, BadgeConfig>)[selection.status];
    case "alert_severity":
      return ({
        info: { label: "Info", variant: "information" },
        warning: { label: "Warning", variant: "warning" },
        critical: { label: "Critical", variant: "danger" },
      } satisfies Record<AlertSeverityBadgeStatus, BadgeConfig>)[selection.status];
    case "account":
      return ({
        active: { label: "Active", variant: "success" },
        inactive: { label: "Inactive", variant: "neutral" },
      } satisfies Record<AccountBadgeStatus, BadgeConfig>)[selection.status];
  }
}

export function StatusBadge(props: StatusBadgeProps) {
  const config = getBadgeConfig(props);
  const { className, domain, status, ...badgeProps } = props;

  return (
    <span
      className={cn(
        "inline-flex items-center whitespace-nowrap rounded-pill border px-2 py-1 text-caption",
        semanticClasses[config.variant],
        className,
      )}
      data-domain={domain}
      data-status={status}
      {...badgeProps}
    >
      {config.label}
    </span>
  );
}
