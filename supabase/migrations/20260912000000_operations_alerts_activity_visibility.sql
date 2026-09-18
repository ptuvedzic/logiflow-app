grant select (
  id, alert_type, severity, message, alert_state,
  shipment_id, vehicle_id, driver_id, document_id,
  created_at, resolved_at, resolved_by_profile_id
) on table public.alerts to authenticated;

grant select (
  id, actor_profile_id, action_type, occurred_at,
  shipment_id, vehicle_id, driver_id, client_id, document_id,
  status_request_id, maintenance_record_id, expense_id, metadata
) on table public.activity_logs to authenticated;

create policy alerts_operations_select
on public.alerts
for select
to authenticated
using (
  (select public.current_active_profile_role()) in ('admin', 'dispatcher')
);

create policy activity_logs_admin_select
on public.activity_logs
for select
to authenticated
using (
  (select public.current_active_profile_role()) = 'admin'
);

create policy activity_logs_dispatcher_shipment_select
on public.activity_logs
for select
to authenticated
using (
  (select public.current_active_profile_role()) = 'dispatcher'
  and (
    (
      shipment_id is not null
      and action_type in (
        'shipment_created',
        'shipment_updated',
        'shipment_assigned',
        'shipment_status_changed',
        'shipment_cancelled',
        'tracking_started',
        'tracking_stopped'
      )
    )
    or (
      status_request_id is not null
      and action_type in (
        'status_request_created',
        'status_request_approved',
        'status_request_rejected'
      )
    )
  )
);
