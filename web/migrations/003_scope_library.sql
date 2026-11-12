-- Shared library of past requests (description and scope only, no amounts or vendors),
-- readable by every active user so wording can be standardised across projects.
create table public.templates (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.templates enable row level security;
create policy tpl_read on public.templates for select to authenticated
  using ((select private.is_active()));

create or replace function private.sync_template() returns trigger
 language plpgsql security definer set search_path to '' as $$
begin
  if tg_op = 'DELETE' then
    delete from public.templates where id = old.id;
    return old;
  end if;
  if coalesce(new.data->>'desc','') = '' or new.data->>'cancel' = 'Yes' then
    delete from public.templates where id = new.id;
    return new;
  end if;
  insert into public.templates (id, data, updated_at)
  values (new.id, jsonb_strip_nulls(jsonb_build_object(
    'prop', new.data->'prop', 'prfdate', new.data->'prfdate', 'cat', new.data->'cat', 'desc', new.data->'desc',
    'scope', new.data->'scope', 'pdesc', new.data->'pdesc', 'area', new.data->'area', 'job', new.data->'job',
    'freq', new.data->'freq', 'qty', new.data->'qty', 'sst', new.data->'sst')), now())
  on conflict (id) do update set data = excluded.data, updated_at = now();
  return new;
end $$;
create trigger sync_template after insert or update or delete on public.records
  for each row execute function private.sync_template();

-- backfill from existing records
update public.records set data = data;
