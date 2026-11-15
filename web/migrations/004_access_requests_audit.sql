-- 004: access requests with admin approval, audit log, record deletion by Property Managers,
--      email to administrators on a new access request.

-- profiles: request details and approval status
alter table public.profiles add column if not exists designation text not null default '';
alter table public.profiles add column if not exists company text not null default '';
alter table public.profiles add column if not exists requested_props text[] not null default '{}';
alter table public.profiles add column if not exists status text not null default 'pending';
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles drop constraint if exists profiles_status_check;
alter table public.profiles add constraint profiles_status_check check (status in ('pending','approved','rejected'));
alter table public.profiles alter column active set default false;
update public.profiles set status = 'approved' where active;

-- every new sign-up or invite waits for approval
create or replace function private.handle_new_user() returns trigger
 language plpgsql security definer set search_path to '' as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, email, full_name, designation, company, requested_props, role, active, status)
  values (new.id, new.email,
          left(coalesce(m->>'full_name',''),80), left(coalesce(m->>'designation',''),80), left(coalesce(m->>'company',''),120),
          coalesce(array(select left(x,20) from jsonb_array_elements_text(case when jsonb_typeof(m->'projects')='array' then m->'projects' else '[]'::jsonb end) x limit 50), '{}'),
          'viewer', false, 'pending');
  return new;
end $$;

-- project list for the request-access form (codes and names only)
create or replace function public.project_list() returns table(code text, name text)
 language sql stable security definer set search_path to '' as $$
  select p.code, coalesce(p.data->>'name','') from public.properties p order by p.code $$;
revoke all on function public.project_list() from public;
grant execute on function public.project_list() to anon, authenticated;

-- Property Managers may delete records of their own properties; administrators any record
drop policy if exists rec_delete on public.records;
create policy rec_delete on public.records for delete to authenticated
  using ((select private.has_role(array['admin'])) or ((select private.has_role(array['manager'])) and (select private.can_see_prop(records.prop))));

-- audit log, readable by administrators only
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor uuid,
  actor_email text,
  action text not null,
  tbl text not null,
  row_id text,
  label text,
  changes jsonb
);
create index if not exists audit_log_at on public.audit_log (at desc);
alter table public.audit_log enable row level security;
drop policy if exists audit_read on public.audit_log;
create policy audit_read on public.audit_log for select to authenticated using ((select private.is_admin()));

create or replace function private.audit() returns trigger
 language plpgsql security definer set search_path to '' as $$
declare o jsonb; n jsonb; r jsonb; ch jsonb; lab text;
begin
  o := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  n := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  r := coalesce(n, o);
  lab := coalesce(r->'data'->>'prfno', r->'data'->>'name', r->>'email', r->>'property_code', r->>'code', r->>'id');
  if tg_op = 'UPDATE' then
    if n ? 'data' then
      select jsonb_object_agg(k, jsonb_build_object('from', o->'data'->k, 'to', n->'data'->k)) into ch
      from (select jsonb_object_keys(coalesce(o->'data','{}'::jsonb) || coalesce(n->'data','{}'::jsonb)) k) s
      where (o->'data'->k) is distinct from (n->'data'->k);
    else
      select jsonb_object_agg(k, jsonb_build_object('from', o->k, 'to', n->k)) into ch
      from (select jsonb_object_keys(o || n) k) s
      where (o->k) is distinct from (n->k) and k not in ('updated_at','updated_by','notified_at');
    end if;
    if ch is null then return new; end if;
  elsif tg_op = 'DELETE' then
    ch := jsonb_build_object('deleted', o);
  else
    ch := jsonb_build_object('created', n);
  end if;
  insert into public.audit_log (actor, actor_email, action, tbl, row_id, label, changes)
  values (auth.uid(), (select p.email from public.profiles p where p.id = auth.uid()), lower(tg_op), tg_table_name,
          coalesce(r->>'id', r->>'code', (r->>'user_id') || ':' || (r->>'property_code')), lab, ch);
  return coalesce(new, old);
end $$;

do $$ declare t text; begin
  foreach t in array array['records','vendors','properties','settings','profiles','user_properties'] loop
    execute format('drop trigger if exists audit_%1$s on public.%1$I', t);
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$I for each row execute function private.audit()', t);
  end loop;
end $$;

-- sign-ins
create or replace function private.audit_signin() returns trigger
 language plpgsql security definer set search_path to '' as $$
begin
  if new.last_sign_in_at is distinct from old.last_sign_in_at then
    insert into public.audit_log (actor, actor_email, action, tbl, row_id, label)
    values (new.id, new.email, 'sign in', 'auth', new.id::text, new.email);
  end if;
  return new;
end $$;
drop trigger if exists audit_signin on auth.users;
create trigger audit_signin after update of last_sign_in_at on auth.users for each row execute function private.audit_signin();

-- email administrators when someone requests access (Edge Function supabase/functions/notify-admin)
create extension if not exists pg_net with schema extensions;
alter table public.profiles add column if not exists notified_at timestamptz;
create or replace function private.notify_request() returns trigger
 language plpgsql security definer set search_path to '' as $$
begin
  perform net.http_post(
    url := 'https://mzrwmvvikxewbahiuzij.supabase.co/functions/v1/notify-admin',
    headers := jsonb_build_object('Content-Type','application/json'),
    body := jsonb_build_object('id', new.id));
  return new;
exception when others then return new;
end $$;
drop trigger if exists notify_request on public.profiles;
create trigger notify_request after insert on public.profiles for each row execute function private.notify_request();
