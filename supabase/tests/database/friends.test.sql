-- Invites, friendships, shared expenses and payments: who can do what.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'asha@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'chet@example.com');
insert into public.profiles (id, name, adult_confirmed_at) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Asha', now()),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'Bina', now()),
  ('cccccccc-0000-0000-0000-000000000003', 'Chet', now());

create function pg_temp.act_as(who uuid, mail text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', who, 'email', mail, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.act_as(uuid, text) to authenticated;

set local role authenticated;

-- Asha invites Bina by email.
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-000000000001', 'asha@example.com');
create temp table t_inv on commit drop as select * from public.create_invite('Bina', ' Bina@Example.com ');
select is((select count(*) from public.invites)::int, 1, 'the sender sees the invite they sent');
select is((select email from public.invites), 'bina@example.com', 'invite emails are stored in lower case');
select throws_ok($$ select public.create_invite('Me', 'asha@example.com') $$, '22023', null, 'you cannot invite yourself');
select throws_ok(
  $$ select public.save_expense(gen_random_uuid(), 'Too soon', 1000, 'aaaaaaaa-0000-0000-0000-000000000001', current_date,
     '{"aaaaaaaa-0000-0000-0000-000000000001": 500, "bbbbbbbb-0000-0000-0000-000000000002": 500}'::jsonb) $$,
  '42501', null, 'you cannot share an expense with someone before they accept'
);

-- Chet can't see or answer it.
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003', 'chet@example.com');
select is((select count(*) from public.invites)::int, 0, 'others cannot read invites');
select is((select count(*) from public.my_requests())::int, 0, 'a request only reaches its email');
select throws_ok(format($$ select public.answer_invite(%L, null, 'accepted') $$, (select id from t_inv)), 'P0002', null,
  'someone else cannot accept it');

-- Bina sees and accepts.
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com');
select is((select from_name from public.my_requests()), 'Asha', 'the request shows the sender''s name');
select is((select from_email from public.my_requests()), 'ash•••@example.com', 'and only part of their email');
select is(public.answer_invite((select id from t_inv), null, 'accepted'), 'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
  'accepting returns the sender');
select is((select count(*) from public.friendships)::int, 1, 'accepting makes them friends');
select is((select name from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'Asha', 'friends can see each other''s names');

-- Asha adds a shared dinner.
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-000000000001', 'asha@example.com');
select lives_ok(
  $$ select public.save_expense('eeeeeeee-0000-0000-0000-000000000001', 'Dinner', 1200, 'aaaaaaaa-0000-0000-0000-000000000001', current_date,
     '{"aaaaaaaa-0000-0000-0000-000000000001": 600, "bbbbbbbb-0000-0000-0000-000000000002": 600}'::jsonb) $$,
  'a friend can be in a shared expense'
);
select throws_ok(
  $$ select public.save_expense(gen_random_uuid(), 'Wrong', 1200, 'aaaaaaaa-0000-0000-0000-000000000001', current_date,
     '{"aaaaaaaa-0000-0000-0000-000000000001": 600, "bbbbbbbb-0000-0000-0000-000000000002": 500}'::jsonb) $$,
  '22023', null, 'shares must add up to the total'
);
select throws_ok(
  $$ select public.save_expense(gen_random_uuid(), 'Stranger', 1000, 'aaaaaaaa-0000-0000-0000-000000000001', current_date,
     '{"aaaaaaaa-0000-0000-0000-000000000001": 500, "cccccccc-0000-0000-0000-000000000003": 500}'::jsonb) $$,
  '42501', null, 'a stranger cannot be put in an expense'
);
select throws_ok($$ insert into public.expenses (id, created_by, title, total, payer, day)
  values (gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'x', 1, 'aaaaaaaa-0000-0000-0000-000000000001', current_date) $$,
  '42501', null, 'the tables cannot be written directly');

-- Bina sees it but can't change it; Chet sees nothing.
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com');
select is((select share from public.expense_shares where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 600, 'the friend sees their share');
select throws_ok($$ select public.delete_expense('eeeeeeee-0000-0000-0000-000000000001') $$, '42501', null,
  'only the person who added it can delete it');
select lives_ok(
  $$ select public.save_payment(gen_random_uuid(), 'bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 600, current_date) $$,
  'a friend can record paying you back'
);
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003', 'chet@example.com');
select is((select count(*) from public.expenses)::int + (select count(*) from public.payments)::int, 0,
  'outsiders see no expenses or payments');
select is((select count(*) from public.profiles where id <> 'cccccccc-0000-0000-0000-000000000003')::int, 0,
  'outsiders cannot see names');

-- Blocking: "I don't know them" stops further requests from that sender.
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003', 'chet@example.com');
create temp table t_spam on commit drop as select * from public.create_invite('Bina', 'bina@example.com');
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com');
select public.answer_invite((select id from t_spam), null, 'blocked');
select pg_temp.act_as('cccccccc-0000-0000-0000-000000000003', 'chet@example.com');
select public.create_invite('Bina again', 'bina@example.com');
select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com');
select is((select count(*) from public.my_requests())::int, 0, 'a blocked sender cannot send another request');

select * from finish();
rollback;
