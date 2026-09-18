grant select (
  id,
  full_name,
  username,
  role,
  is_active
) on table public.profiles to authenticated;

create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = (select auth.uid()));
