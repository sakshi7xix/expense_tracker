-- Profiles: one row per signed-in person, readable and editable only by its owner.
-- Personal spends, budgets and statistics never come to the server; only what is
-- needed to split with friends does (later migrations).

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  -- When the person confirmed they are 18 or older (DPDP: no children's data).
  adult_confirmed_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on public.profiles from anon;
revoke all on public.profiles from authenticated;
grant select, insert, update (name, updated_at) on public.profiles to authenticated;

create policy "read own profile" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

create policy "create own profile" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

create policy "update own profile" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- No delete policy: an account is removed only through delete_account().

-- Deletes the signed-in person's account. The profile goes with it (on delete
-- cascade). Runs with the owner's rights so it can remove the auth user, but
-- only ever the caller's own.
create function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
