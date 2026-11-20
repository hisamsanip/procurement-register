-- 006: only administrators create properties again; the auto-assign trigger from 005 is no longer needed.
drop trigger if exists prop_assign on public.properties;
drop function if exists private.prop_assign();
drop policy if exists prop_insert on public.properties;
create policy prop_insert on public.properties for insert to authenticated
  with check ((select private.is_admin()));
