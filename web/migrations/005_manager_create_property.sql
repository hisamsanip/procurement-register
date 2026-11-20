-- 005: Property Managers may create a property (and so its letterhead); it is assigned to them automatically.
drop policy if exists prop_insert on public.properties;
create policy prop_insert on public.properties for insert to authenticated
  with check ((select private.has_role(array['admin','manager'])));

create or replace function private.prop_assign() returns trigger
 language plpgsql security definer set search_path to '' as $$
begin
  if exists (select 1 from public.profiles p where p.id = auth.uid() and p.active and p.role = 'manager') then
    insert into public.user_properties (user_id, property_code) values (auth.uid(), new.code) on conflict do nothing;
  end if;
  return new;
end $$;
drop trigger if exists prop_assign on public.properties;
create trigger prop_assign after insert on public.properties for each row execute function private.prop_assign();
