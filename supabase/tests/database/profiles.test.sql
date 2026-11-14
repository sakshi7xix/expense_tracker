-- Who can see and change profiles. Runs with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'asha@example.com'),
  ('22222222-2222-2222-2222-222222222222', 'bina@example.com');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'row level security is on for profiles'
);

-- Asha
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select lives_ok(
  $$ insert into public.profiles (id, name, adult_confirmed_at)
     values ('11111111-1111-1111-1111-111111111111', 'Asha', now()) $$,
  'a person can create their own profile'
);
select throws_ok(
  $$ insert into public.profiles (id, name, adult_confirmed_at)
     values ('22222222-2222-2222-2222-222222222222', 'Fake Bina', now()) $$,
  '42501', null,
  'a person cannot create a profile for someone else'
);
select throws_ok(
  $$ update public.profiles set adult_confirmed_at = null
     where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null,
  'the 18+ confirmation cannot be changed afterwards'
);

-- Bina
set local request.jwt.claims = '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';
select lives_ok(
  $$ insert into public.profiles (id, name, adult_confirmed_at)
     values ('22222222-2222-2222-2222-222222222222', 'Bina', now()) $$,
  'a second person creates theirs'
);
select is((select count(*) from public.profiles)::int, 1, 'a person sees only their own profile');
update public.profiles set name = 'Hacked' where id = '11111111-1111-1111-1111-111111111111';
select throws_ok(
  $$ delete from public.profiles where id = '22222222-2222-2222-2222-222222222222' $$,
  '42501', null,
  'profiles cannot be deleted directly'
);

-- Signed out
reset role;
select is(
  (select name from public.profiles where id = '11111111-1111-1111-1111-111111111111'),
  'Asha',
  'nobody can rename someone else'
);
set local role anon;
select throws_ok($$ select * from public.profiles $$, '42501', null, 'signed-out visitors cannot read profiles');
select throws_ok($$ select public.delete_account() $$, '42501', null, 'signed-out visitors cannot delete accounts');

-- Asha deletes her account
set local role authenticated;
set local request.jwt.claims = '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select public.delete_account();
reset role;
select is(
  (select count(*) from auth.users u join public.profiles p on p.id = u.id where u.id = '11111111-1111-1111-1111-111111111111')::int
    + (select count(*) from auth.users where id = '11111111-1111-1111-1111-111111111111')::int,
  0,
  'deleting an account removes the sign-in and the profile, and only that one'
);

select * from finish();
rollback;
