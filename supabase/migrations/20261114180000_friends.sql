-- Friends online: invites, friendships, shared expenses and payments.
-- Only split expenses come here. Every write goes through a function that
-- checks the caller, the friendship and the money; tables are read-only to
-- the app and filtered by row level security.

create table public.friendships (
  user_a uuid not null references auth.users (id) on delete cascade,
  user_b uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users (id) on delete cascade,
  code text not null unique default upper(substr(md5(gen_random_uuid()::text), 1, 10)),
  email text check (email is null or email = lower(btrim(email))),
  friend_name text not null check (char_length(btrim(friend_name)) between 1 and 60),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'blocked')),
  accepted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  answered_at timestamptz
);
create index invites_email on public.invites (email) where status = 'pending';

-- Participants are plain ids (no foreign key) so friends keep shared expenses
-- after someone deletes their account; the app shows them as "Deleted user".
create table public.expenses (
  id uuid primary key,
  created_by uuid not null,
  title text not null check (char_length(btrim(title)) between 1 and 80),
  total integer not null check (total > 0),
  payer uuid not null,
  day date not null,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index expenses_updated on public.expenses (updated_at);

create table public.expense_shares (
  expense_id uuid not null references public.expenses (id) on delete cascade,
  user_id uuid not null,
  share integer not null check (share >= 0),
  primary key (expense_id, user_id)
);
create index expense_shares_user on public.expense_shares (user_id);

create table public.payments (
  id uuid primary key,
  from_user uuid not null,
  to_user uuid not null,
  amount integer not null check (amount > 0),
  day date not null,
  created_by uuid not null,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (from_user <> to_user)
);
create index payments_updated on public.payments (updated_at);

alter table public.friendships enable row level security;
alter table public.invites enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_shares enable row level security;
alter table public.payments enable row level security;

revoke all on public.friendships, public.invites, public.expenses, public.expense_shares, public.payments from anon, authenticated;
grant select on public.friendships, public.invites, public.expenses, public.expense_shares, public.payments to authenticated;

-- Helpers (security definer so policies don't recurse).
create function public.is_friend(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.friendships
    where user_a = least(auth.uid(), other) and user_b = greatest(auth.uid(), other)
  );
$$;

create function public.in_expense(e uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.expense_shares where expense_id = e and user_id = auth.uid());
$$;

create function public.shares_expense_with(other uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.expense_shares mine
    join public.expense_shares theirs on theirs.expense_id = mine.expense_id
    where mine.user_id = auth.uid() and theirs.user_id = other
  );
$$;

create function public.my_email() returns text
language sql stable as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

revoke execute on function public.is_friend(uuid), public.in_expense(uuid), public.shares_expense_with(uuid) from public, anon;
grant execute on function public.is_friend(uuid), public.in_expense(uuid), public.shares_expense_with(uuid) to authenticated;

create policy "own friendships" on public.friendships
  for select to authenticated using ((select auth.uid()) in (user_a, user_b));

create policy "invites I sent" on public.invites
  for select to authenticated using (from_user = (select auth.uid()));

create policy "expenses I'm in" on public.expenses
  for select to authenticated using (public.in_expense(id));

create policy "shares of expenses I'm in" on public.expense_shares
  for select to authenticated using (public.in_expense(expense_id));

create policy "payments I'm in" on public.payments
  for select to authenticated using ((select auth.uid()) in (from_user, to_user));

-- Friends and people you share an expense with can see your name.
create policy "friends' profiles" on public.profiles
  for select to authenticated using (public.is_friend(id) or public.shares_expense_with(id));

-- Invites -----------------------------------------------------------------

-- Creates an invite and returns its id and code. At most 30 a day.
create function public.create_invite(p_friend_name text, p_email text)
returns table (id uuid, code text)
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  clean text := nullif(lower(btrim(coalesce(p_email, ''))), '');
  blocked boolean;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if (select count(*) from public.invites i where i.from_user = me and i.created_at > now() - interval '1 day') >= 30 then
    raise exception 'too many invites today' using errcode = '54000';
  end if;
  if clean is not null and clean = public.my_email() then
    raise exception 'that is your own email' using errcode = '22023';
  end if;
  -- Someone who chose "I don't know them" never sees another request from this person.
  blocked := clean is not null and exists (
    select 1 from public.invites i where i.from_user = me and i.email = clean and i.status = 'blocked');
  return query
    insert into public.invites (from_user, email, friend_name, status)
    values (me, clean, btrim(p_friend_name), case when blocked then 'blocked' else 'pending' end)
    returning invites.id, invites.code;
end;
$$;

-- Requests waiting for me: invites sent to my email. Shows the sender's
-- name and a partly hidden email, never anything they've spent.
create function public.my_requests()
returns table (id uuid, from_user uuid, from_name text, from_email text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select i.id, i.from_user, coalesce(p.name, 'Someone'),
         left(u.email, 3) || '•••@' || split_part(u.email, '@', 2), i.created_at
  from public.invites i
  join auth.users u on u.id = i.from_user
  left join public.profiles p on p.id = i.from_user
  where i.status = 'pending' and i.email is not null and i.email = public.my_email()
    and i.from_user <> auth.uid()
  order by i.created_at desc;
$$;

-- Looks up an invite someone sent me by its code.
create function public.invite_by_code(p_code text)
returns table (id uuid, from_user uuid, from_name text)
language sql stable security definer set search_path = '' as $$
  select i.id, i.from_user, coalesce(p.name, 'Someone')
  from public.invites i left join public.profiles p on p.id = i.from_user
  where i.code = upper(btrim(p_code)) and i.status = 'pending' and i.from_user <> auth.uid();
$$;

-- Accept, decline or block an invite sent to my email, or one whose code I
-- have. Accepting makes us friends. Returns the sender's id.
create function public.answer_invite(p_id uuid, p_code text, p_answer text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  inv public.invites;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if p_answer not in ('accepted', 'declined', 'blocked') then raise exception 'bad answer' using errcode = '22023'; end if;
  select * into inv from public.invites
  where invites.id = p_id and status = 'pending' and from_user <> me
    and ((email is not null and email = public.my_email()) or code = upper(btrim(coalesce(p_code, ''))))
  for update;
  if not found then raise exception 'invite not found' using errcode = 'P0002'; end if;
  update public.invites set status = p_answer, accepted_by = case when p_answer = 'accepted' then me end, answered_at = now()
  where invites.id = inv.id;
  if p_answer = 'accepted' then
    insert into public.friendships (user_a, user_b)
    values (least(me, inv.from_user), greatest(me, inv.from_user)) on conflict do nothing;
  end if;
  return inv.from_user;
end;
$$;

-- Expenses and payments ----------------------------------------------------

-- Saves or updates a shared expense I created. Everyone in it must be me or
-- my friend, the payer must be in it, and the shares must add up.
create function public.save_expense(p_id uuid, p_title text, p_total integer, p_payer uuid, p_day date, p_shares jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  owner uuid;
  s record;
  sum_shares bigint := 0;
  people int := 0;
  has_me boolean := false;
  has_payer boolean := false;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  select created_by into owner from public.expenses where id = p_id;
  if found and owner <> me then raise exception 'only the person who added it can change it' using errcode = '42501'; end if;
  for s in select key::uuid as uid, value::int as share from jsonb_each_text(p_shares) loop
    if s.share < 0 then raise exception 'negative share' using errcode = '22023'; end if;
    if s.uid <> me and not public.is_friend(s.uid) then raise exception 'not your friend' using errcode = '42501'; end if;
    sum_shares := sum_shares + s.share;
    people := people + 1;
    has_me := has_me or s.uid = me;
    has_payer := has_payer or s.uid = p_payer;
  end loop;
  if people < 2 or not has_me or not has_payer then raise exception 'a shared expense needs you, a friend and the payer' using errcode = '22023'; end if;
  if sum_shares <> p_total then raise exception 'shares must add up to the total' using errcode = '22023'; end if;
  insert into public.expenses (id, created_by, title, total, payer, day)
  values (p_id, me, btrim(p_title), p_total, p_payer, p_day)
  on conflict (id) do update set title = excluded.title, total = excluded.total, payer = excluded.payer,
    day = excluded.day, deleted = false, updated_at = now();
  delete from public.expense_shares where expense_id = p_id;
  insert into public.expense_shares (expense_id, user_id, share)
  select p_id, key::uuid, value::int from jsonb_each_text(p_shares);
end;
$$;

create function public.delete_expense(p_id uuid, p_deleted boolean default true)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.expenses set deleted = p_deleted, updated_at = now() where id = p_id and created_by = auth.uid();
  if not found then raise exception 'only the person who added it can delete it' using errcode = '42501'; end if;
end;
$$;

-- Records a payment between me and a friend, in either direction.
create function public.save_payment(p_id uuid, p_from uuid, p_to uuid, p_amount integer, p_day date)
returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); other uuid;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if me not in (p_from, p_to) then raise exception 'a payment must involve you' using errcode = '42501'; end if;
  other := case when p_from = me then p_to else p_from end;
  if not public.is_friend(other) then raise exception 'not your friend' using errcode = '42501'; end if;
  insert into public.payments (id, from_user, to_user, amount, day, created_by)
  values (p_id, p_from, p_to, p_amount, p_day, me)
  on conflict (id) do nothing;
end;
$$;

revoke execute on function public.create_invite(text, text), public.my_requests(), public.invite_by_code(text),
  public.answer_invite(uuid, text, text), public.save_expense(uuid, text, integer, uuid, date, jsonb),
  public.delete_expense(uuid, boolean), public.save_payment(uuid, uuid, uuid, integer, date) from public, anon;
grant execute on function public.create_invite(text, text), public.my_requests(), public.invite_by_code(text),
  public.answer_invite(uuid, text, text), public.save_expense(uuid, text, integer, uuid, date, jsonb),
  public.delete_expense(uuid, boolean), public.save_payment(uuid, uuid, uuid, integer, date) to authenticated;
