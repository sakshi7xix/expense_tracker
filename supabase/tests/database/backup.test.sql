-- Private backup rows: only their owner can see or change them.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'asha@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bina@example.com');

create function pg_temp.act_as(who uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', who, 'role', 'authenticated')::text, true);
$$;
grant execute on function pg_temp.act_as(uuid) to authenticated;

select ok((select relrowsecurity from pg_class where oid = 'public.backup_rows'::regclass), 'backup rows have row level security');

set local role authenticated;
select pg_temp.act_as('aaaaaaaa-0000-0000-0000-000000000001');
select lives_ok($$ insert into public.backup_rows (kind, key, data) values ('entry', 'e1', '{"title":"Rent","amount":1500000}') $$,
  'you can back up a spend');
select lives_ok($$ insert into public.backup_rows (kind, key, data) values ('entry', 'e1', '{"title":"Rent","amount":1600000}')
  on conflict (owner, kind, key) do update set data = excluded.data $$, 'and update it');
select is((select data->>'amount' from public.backup_rows where key = 'e1'), '1600000', 'the newest copy is kept');
select throws_ok($$ insert into public.backup_rows (owner, kind, key, data) values ('bbbbbbbb-0000-0000-0000-000000000002', 'entry', 'x', '{}') $$,
  '42501', null, 'you cannot write into someone else''s backup');
select throws_ok($$ insert into public.backup_rows (kind, key, data) values ('secret', 'x', '{}') $$,
  '23514', null, 'only known kinds of rows');

select pg_temp.act_as('bbbbbbbb-0000-0000-0000-000000000002');
select is((select count(*) from public.backup_rows)::int, 0, 'a friend sees none of your backup');
update public.backup_rows set data = '{}' where key = 'e1';
delete from public.backup_rows where key = 'e1';

reset role;
select is((select data->>'amount' from public.backup_rows where key = 'e1'), '1600000', 'nor can they change or delete it');

set local role anon;
select throws_ok($$ select * from public.backup_rows $$, '42501', null, 'signed-out visitors cannot read backups');

select * from finish();
rollback;
