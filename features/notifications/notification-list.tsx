"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

import { acknowledgeNotificationAction } from "@/app/(operations)/operations/notifications/actions";
import { Button } from "@/components/ui/button";
import { NotificationItem } from "@/components/ui/notification-item";
import { Pagination, PaginationItem, PaginationLink, PaginationNext, PaginationPrevious } from "@/components/ui/pagination";
import { Select } from "@/components/ui/select";
import { TableToolbar } from "@/components/ui/table-toolbar";
import type { NotificationListInput } from "@/features/notifications/notification-schema";
import type { OperationsNotification } from "@/lib/dal/notifications";

const formatter = new Intl.DateTimeFormat("en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Belgrade"});
function url(filters: NotificationListInput, page: number) { const params = new URLSearchParams(); if (filters.status !== "all") params.set("status", filters.status); if (page > 1) params.set("page", String(page)); const query = params.toString(); return query ? `/operations/notifications?${query}` : "/operations/notifications"; }

export function NotificationList({ notifications, filters, totalCount, totalPages }: Readonly<{ notifications: readonly OperationsNotification[]; filters: NotificationListInput; totalCount: number; totalPages: number }>) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  function acknowledge(id: string) { setPendingId(id); setError(null); startTransition(async () => { const result = await acknowledgeNotificationAction(id); if (result.status === "success") router.refresh(); else setError(result.status === "validation" || result.status === "not_found" ? "This notification is unavailable." : "Unable to mark this notification as read. Try again."); setPendingId(null); }); }
  const footer = totalPages > 1 ? <Pagination><PaginationItem>{filters.page === 1 ? <PaginationPrevious disabled /> : <PaginationPrevious href={url(filters, filters.page - 1)} />}</PaginationItem>{Array.from({ length: totalPages }, (_, index) => index + 1).map((page) => <PaginationItem key={page}><PaginationLink href={url(filters, page)} active={page === filters.page}>{page}</PaginationLink></PaginationItem>)}<PaginationItem>{filters.page === totalPages ? <PaginationNext disabled /> : <PaginationNext href={url(filters, filters.page + 1)} />}</PaginationItem></Pagination> : null;
  return <div className="flex min-w-0 flex-col gap-4">
    <form action="/operations/notifications" method="get"><TableToolbar leading={<Select aria-label="Notification status" name="status" defaultValue={filters.status} focusSurface="card"><option value="all">All notifications</option><option value="unread">Unread</option><option value="read">Read</option></Select>} trailing={<><Button type="submit" variant="outline" focusSurface="card">Apply</Button><Link href="/operations/notifications" className="inline-flex min-h-11 items-center justify-center rounded-control px-4 text-label text-secondary hover:bg-background-hover md:min-h-10">Clear</Link></>} /></form>
    <p className="text-small text-secondary">{totalCount} {totalCount === 1 ? "notification" : "notifications"}</p>
    {error ? <p role="alert" className="text-small text-danger">{error}</p> : null}
    <ol className="grid min-w-0 gap-4">{notifications.map((notification) => <li key={notification.id}><NotificationItem title={notification.title} message={notification.message} createdAt={notification.createdAt} timestamp={formatter.format(new Date(notification.createdAt))} unread={notification.readAt === null} context={notification.entityHref ? <Link className="font-medium text-primary hover:underline" href={notification.entityHref}>View related shipments</Link> : null} action={notification.readAt === null ? <Button variant="outline" focusSurface="card" className="min-h-11 w-full md:w-auto" loading={isPending && pendingId === notification.id} disabled={isPending && pendingId !== notification.id} onClick={() => acknowledge(notification.id)}>Mark as read</Button> : undefined} /></li>)}</ol>
    {footer}
  </div>;
}
