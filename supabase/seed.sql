-- LogiFlow SD1 local demo seed foundation.
--
-- Supabase runs this file during `supabase db reset`. Rows that require real
-- Auth identities are intentionally created by `npm run demo:bootstrap` after
-- the reset. The bootstrap uses Supabase Admin Auth, the normal username
-- mapping RPC, authenticated workflow RPCs, and the private Storage workflow.
--
-- These deterministic, Auth-independent rows use narrowly scoped
-- `ON CONFLICT DO NOTHING`, so a repeated seed application cannot overwrite
-- operational state produced by the workflow bootstrap.

begin;

insert into public.clients (
  id, company_name, contact_person, phone, email, address, notes, status
)
values
  (
    '40000000-0000-4000-8000-000000000001',
    'Danube Fresh Logistics',
    'Milica Jovanovic',
    '+381 11 555 0140',
    'operations@danubefresh.example',
    'Dunavska 24, Belgrade, Serbia',
    'Regional food distribution and cold-chain deliveries.',
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    'Adriatic Industrial Supply',
    'Luka Kovac',
    '+381 21 555 0188',
    'dispatch@adriaticindustrial.example',
    'Industrijska 18, Novi Sad, Serbia',
    'Industrial parts and scheduled factory replenishment.',
    'active'
  )
on conflict (id) do nothing;

insert into public.vehicles (
  id, registration, make, model, vehicle_type, vin, mileage,
  fuel_type, first_registration_date, status
)
values
  ('30000000-0000-4000-8000-000000000001', 'BG-101-LF', 'Volvo', 'FH 460', 'Tractor unit', 'YV2RT40A0LA000101', 184200, 'Diesel', '2020-03-12', 'available'),
  ('30000000-0000-4000-8000-000000000002', 'BG-202-LF', 'Scania', 'R450', 'Tractor unit', 'YS2R4X20005500202', 226750, 'Diesel', '2019-06-08', 'available'),
  ('30000000-0000-4000-8000-000000000003', 'NS-303-LF', 'Mercedes-Benz', 'Actros', 'Tractor unit', 'WDB9634031L303303', 163900, 'Diesel', '2021-09-21', 'available'),
  ('30000000-0000-4000-8000-000000000004', 'BG-404-LF', 'MAN', 'TGM', 'Rigid truck', 'WMA06XZZ8KM404404', 97800, 'Diesel', '2022-02-17', 'available'),
  ('30000000-0000-4000-8000-000000000005', 'NI-505-LF', 'Iveco', 'Eurocargo', 'Rigid truck', 'ZCFA71JJ005505505', 141250, 'Diesel', '2018-11-04', 'maintenance'),
  ('30000000-0000-4000-8000-000000000006', 'KG-606-LF', 'DAF', 'XF 480', 'Tractor unit', 'XLRTEH4300G606606', 288100, 'Diesel', '2017-05-29', 'out_of_service'),
  ('30000000-0000-4000-8000-000000000007', 'SU-707-LF', 'Renault', 'T High', 'Tractor unit', 'VF611A369KD707707', 251600, 'Diesel', '2016-08-13', 'archived')
on conflict (id) do nothing;

commit;
