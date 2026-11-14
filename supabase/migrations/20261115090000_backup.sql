-- Private backup: a copy of everything on your phone (spends, friends,
-- balances, groups, budget), readable and writable only by you. One row per
-- thing on the phone; `data` is that thing as JSON. Rows are never shared and
-- go when the account is deleted.

create table public.backup_rows (
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null check (kind in ('friend', 'entry', 'ledger', 'group', 'setting')),
  key text not null check (char_length(key) between 1 and 64),
  data jsonb not null check (pg_column_size(data) <= 8192),
  updated_at timestamptz not null default now(),
  primary key (owner, kind, key)
);

alter table public.backup_rows enable row level security;

create policy "own backup: read" on public.backup_rows
  for select to authenticated using (owner = (select auth.uid()));
create policy "own backup: add" on public.backup_rows
  for insert to authenticated with check (owner = (select auth.uid()));
create policy "own backup: change" on public.backup_rows
  for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "own backup: remove" on public.backup_rows
  for delete to authenticated using (owner = (select auth.uid()));

revoke all on public.backup_rows from anon, authenticated;
grant select, insert, update, delete on public.backup_rows to authenticated;

-- Keeps updated_at honest and stops one account filling the database.
create function public.backup_rows_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  if tg_op = 'INSERT' and (select count(*) from public.backup_rows where owner = new.owner) >= 200000 then
    raise exception 'backup is full' using errcode = '54000';
  end if;
  return new;
end;
$$;

create trigger backup_rows_touch before insert or update on public.backup_rows
  for each row execute function public.backup_rows_touch();
