-- Personal friend codes and requests made with them.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'asha@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'chet@example.com');

create function pg_temp.act_as(who uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', who, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.act_as(uuid) to authenticated;
set local role authenticated;

select pg_temp.act_as('aaaaaaaa-0000-0000-0000-000000000001');
insert into public.profiles (id, name, adult_confirmed_at) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Asha', now());
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002');
insert into public.profiles (id, name, adult_confirmed_at) values ('bbbbbbbb-0000-0000-0000-000000000002', 'Bina', now());
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003');
insert into public.profiles (id, name, adult_confirmed_at) values ('cccccccc-0000-0000-0000-000000000003', 'Chet', now());

reset role;
create temp table codes on commit drop as select id, friend_code from public.profiles;
grant select on codes to authenticated;
select ok((select bool_and(friend_code ~ '^[A-HJKMNP-Z2-9]{8}$') from codes), 'everyone gets an 8-character code without look-alike characters');
select is((select count(distinct friend_code) from codes)::int, 3, 'codes are unique');
set local role authenticated;

select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002');
select is((select friend_code from public.profiles where id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  (select friend_code from codes where id = 'bbbbbbbb-0000-0000-0000-000000000002'), 'a person can read their own code');

-- Asha adds Bina with Bina's code, written with a space and in lower case.
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-000000000001');
select is(
  (select to_name from public.request_friend(lower(substr((select friend_code from codes where id = 'bbbbbbbb-0000-0000-0000-000000000002'), 1, 4) || ' ' ||
    substr((select friend_code from codes where id = 'bbbbbbbb-0000-0000-0000-000000000002'), 5)))),
  'Bina', 'a code finds its owner, however it is typed');
select throws_ok(format($$ select public.request_friend(%L) $$, (select friend_code from codes where id = 'aaaaaaaa-0000-0000-0000-000000000001')),
  '22023', null, 'you cannot add yourself');
select throws_ok($$ select public.request_friend('ZZZZZZZZ') $$, 'P0002', null, 'an unknown code finds no one');
select is((select count(*) from public.friendships)::int, 0, 'a request alone does not make friends');

-- Chet sees nothing; Bina sees the request and accepts.
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003');
select is((select count(*) from public.my_requests())::int, 0, 'a request only reaches the code''s owner');
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002');
select is((select from_name from public.my_requests()), 'Asha', 'the owner sees who asked');
select public.answer_invite((select id from public.my_requests()), null, 'accepted');
select is((select count(*) from public.friendships)::int, 1, 'accepting makes them friends');
select throws_ok(format($$ select public.request_friend(%L) $$, (select friend_code from codes where id = 'aaaaaaaa-0000-0000-0000-000000000001')),
  '22023', null, 'friends cannot ask again');

-- Two people adding each other: the second request accepts the first.
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003');
select public.request_friend((select friend_code from codes where id = 'aaaaaaaa-0000-0000-0000-000000000001'));
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-000000000001');
select is((select status from public.request_friend((select friend_code from codes where id = 'cccccccc-0000-0000-0000-000000000003'))),
  'accepted', 'adding someone who already asked you makes you friends at once');
select is((select count(*) from public.friendships)::int, 2, 'so both pairs are friends now');

select * from finish();
rollback;
