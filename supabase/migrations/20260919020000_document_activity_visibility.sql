drop policy activity_logs_dispatcher_shipment_select on public.activity_logs;
create policy activity_logs_dispatcher_shipment_select on public.activity_logs for select to authenticated using (
  (select public.current_active_profile_role())='dispatcher' and (
    (shipment_id is not null and driver_id is null and client_id is null and document_id is null and status_request_id is null and maintenance_record_id is null and expense_id is null and vehicle_id is null and action_type in ('shipment_created','shipment_updated','shipment_assigned','shipment_status_changed','shipment_cancelled','tracking_started','tracking_stopped','shipment_delayed','alert_created','alert_resolved'))
    or (status_request_id is not null and shipment_id is null and vehicle_id is null and driver_id is null and client_id is null and document_id is null and maintenance_record_id is null and expense_id is null and action_type in ('status_request_created','status_request_approved','status_request_rejected'))
    or (document_id is not null and shipment_id is null and vehicle_id is null and driver_id is null and client_id is null and status_request_id is null and maintenance_record_id is null and expense_id is null and action_type in ('document_uploaded','document_archived','document_restored','alert_created','alert_resolved'))
  )
);
