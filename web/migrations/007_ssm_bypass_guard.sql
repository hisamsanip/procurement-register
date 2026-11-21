-- SSM document bypass, controlled by an administrator per project.
-- properties.data.ssmbp  : only an administrator may change it.
-- vendors.data.ssmbypass : a vendor may be registered without the SSM document only
--                          when the named project has ssmbp = true and the user can see that project.

create or replace function private.guard_prop_ssmbp() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    if tg_op = 'INSERT' then
      new.data := new.data - 'ssmbp';
    elsif (new.data->'ssmbp') is distinct from (old.data->'ssmbp') then
      new.data := case when old.data ? 'ssmbp'
                       then jsonb_set(new.data, '{ssmbp}', old.data->'ssmbp')
                       else new.data - 'ssmbp' end;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists prop_ssmbp_guard on public.properties;
create trigger prop_ssmbp_guard before insert or update on public.properties
for each row execute function private.guard_prop_ssmbp();

create or replace function private.guard_vendor_ssmbypass() returns trigger
language plpgsql security definer set search_path = '' as $$
declare pc text; ok boolean;
begin
  if coalesce(new.data->>'ssmbypass','') = 'true'
     and (tg_op = 'INSERT' or (old.data->>'ssmbypass') is distinct from 'true'
          or (old.data->>'bypassprop') is distinct from (new.data->>'bypassprop'))
     and not private.is_admin() then
    pc := new.data->>'bypassprop';
    select coalesce((p.data->>'ssmbp')='true', false) into ok from public.properties p where p.code = pc;
    if not coalesce(ok,false) or not private.can_see_prop(pc) then
      raise exception 'ssm_bypass_not_allowed' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists vendor_ssmbypass_guard on public.vendors;
create trigger vendor_ssmbypass_guard before insert or update on public.vendors
for each row execute function private.guard_vendor_ssmbypass();
