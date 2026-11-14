-- Friend codes: everyone gets one personal code, shown in the app. You add a
-- friend by typing their code; they get a request and become your friend
-- when they accept. Nothing is sent by email or messaging apps.

-- 8 characters without look-alikes (no 0/O, 1/I/L).
create function public.new_friend_code() returns text
language plpgsql security definer set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  c text;
begin
  loop
    c := '';
    for i in 1..8 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where friend_code = c);
  end loop;
  return c;
end;
$$;

alter table public.profiles add column friend_code text unique;
update public.profiles set friend_code = public.new_friend_code() where friend_code is null;
alter table public.profiles alter column friend_code set default public.new_friend_code();
alter table public.profiles alter column friend_code set not null;

-- A request made with a code goes to one person.
alter table public.invites add column to_user uuid references auth.users (id) on delete cascade;
create index invites_to_user on public.invites (to_user) where status = 'pending';

-- Sends a friend request to whoever owns [p_code]. Returns the request id and
-- that person's id and name. If they had already asked you, you become
-- friends straight away. At most 30 requests a day.
create function public.request_friend(p_code text)
returns table (id uuid, to_user uuid, to_name text, status text)
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  clean text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  target public.profiles;
  theirs uuid;
  mine uuid;
  was_blocked boolean;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if (select count(*) from public.invites i where i.from_user = me and i.created_at > now() - interval '1 day') >= 30 then
    raise exception 'too many requests today' using errcode = '54000';
  end if;
  select * into target from public.profiles p where p.friend_code = clean;
  if not found then raise exception 'no one has that code' using errcode = 'P0002'; end if;
  if target.id = me then raise exception 'that is your own code' using errcode = '22023'; end if;
  if exists (select 1 from public.friendships f where f.user_a = least(me, target.id) and f.user_b = greatest(me, target.id)) then
    raise exception 'you are already friends' using errcode = '22023';
  end if;

  -- They asked first: accept theirs.
  select i.id into theirs from public.invites i
  where i.from_user = target.id and i.to_user = me and i.status = 'pending' limit 1;
  if theirs is not null then
    update public.invites set status = 'accepted', accepted_by = me, answered_at = now() where invites.id = theirs;
    insert into public.friendships (user_a, user_b) values (least(me, target.id), greatest(me, target.id)) on conflict do nothing;
    return query select theirs, target.id, target.name, 'accepted'::text;
    return;
  end if;

  select i.id into mine from public.invites i
  where i.from_user = me and i.to_user = target.id and i.status in ('pending', 'declined', 'blocked')
  order by i.created_at desc limit 1;
  if mine is null then
    -- Someone who chose "I don't know them" never sees another request from you.
    was_blocked := exists (select 1 from public.invites i where i.from_user = me and i.to_user = target.id and i.status = 'blocked');
    insert into public.invites (from_user, to_user, friend_name, status)
    values (me, target.id, target.name, case when was_blocked then 'blocked' else 'pending' end)
    returning invites.id into mine;
  end if;
  -- To the sender a declined or blocked request still looks like it's waiting.
  return query select mine, target.id, target.name, 'pending'::text;
end;
$$;

-- Requests waiting for me: sent to my code (or, from older versions, my email).
create or replace function public.my_requests()
returns table (id uuid, from_user uuid, from_name text, from_email text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select i.id, i.from_user, coalesce(p.name, 'Someone'),
         left(u.email, 3) || '•••@' || split_part(u.email, '@', 2), i.created_at
  from public.invites i
  join auth.users u on u.id = i.from_user
  left join public.profiles p on p.id = i.from_user
  where i.status = 'pending' and i.from_user <> auth.uid()
    and (i.to_user = auth.uid() or (i.to_user is null and i.email is not null and i.email = public.my_email()))
  order by i.created_at desc;
$$;

create or replace function public.answer_invite(p_id uuid, p_code text, p_answer text)
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
    and (to_user = me
         or (to_user is null and email is not null and email = public.my_email())
         or (to_user is null and code = upper(btrim(coalesce(p_code, '')))))
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

revoke execute on function public.request_friend(text) from public, anon;
grant execute on function public.request_friend(text) to authenticated;
revoke execute on function public.new_friend_code() from public, anon;
grant execute on function public.new_friend_code() to authenticated;
