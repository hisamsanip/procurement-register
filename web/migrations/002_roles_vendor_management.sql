-- Roles: admin, manager (Property Manager), management, vendor (vendor management team), viewer.
-- Vendor blacklist guard and private storage for SSM documents.
alter table public.profiles drop constraint profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('admin','manager','management','vendor','viewer'));

create or replace function private.has_role(r text[]) returns boolean
 language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and active and role = any(r)) $$;
revoke all on function private.has_role(text[]) from public;
grant execute on function private.has_role(text[]) to authenticated;

create or replace function private.can_see_prop(p text) returns boolean
 language sql stable security definer set search_path to '' as $$
  select private.has_role(array['admin','management','vendor'])
      or (private.is_active() and exists (select 1 from public.user_properties where user_id = auth.uid() and property_code = p)) $$;

drop policy vend_insert on public.vendors;
drop policy vend_update on public.vendors;
drop policy vend_delete on public.vendors;
create policy vend_insert on public.vendors for insert to authenticated
  with check ((select private.has_role(array['admin','manager','vendor'])));
create policy vend_update on public.vendors for update to authenticated
  using ((select private.has_role(array['admin','vendor'])))
  with check ((select private.has_role(array['admin','vendor'])));
create policy vend_delete on public.vendors for delete to authenticated
  using ((select private.has_role(array['admin','vendor'])));

create or replace function private.vendor_guard() returns trigger
 language plpgsql set search_path to '' as $$
begin
  if auth.uid() is null or private.has_role(array['admin','vendor']) then return new; end if;
  if coalesce((new.data->>'bl')::boolean, false) then
    raise exception 'Only the vendor management team can blacklist a vendor';
  end if;
  if tg_op = 'INSERT' and coalesce(new.data->>'ssmdoc','') = '' then
    raise exception 'An SSM registration document is required';
  end if;
  return new;
end $$;
create trigger vendor_guard before insert or update on public.vendors
  for each row execute function private.vendor_guard();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('vendor-docs','vendor-docs', false, 5242880, array['application/pdf','image/jpeg','image/png'])
on conflict (id) do nothing;

create policy vdocs_read on storage.objects for select to authenticated
  using (bucket_id = 'vendor-docs' and (select private.is_active()));
create policy vdocs_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'vendor-docs' and (select private.has_role(array['admin','manager','vendor'])));
create policy vdocs_delete on storage.objects for delete to authenticated
  using (bucket_id = 'vendor-docs' and (select private.has_role(array['admin','vendor'])));
