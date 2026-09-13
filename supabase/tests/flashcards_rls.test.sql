-- Test izolacji per użytkownik dla public.flashcards (pgTAP).
-- Uruchamianie: npm run db:test (po npm run db:reset). Biegnie jako superuser w jednej transakcji z rollback,
-- dlatego każda asercja izolacji przełącza rolę na authenticated/anon i ustawia claims JWT.
begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

-- Użytkownicy testowi (superuser, przed przełączeniem roli; FK flashcards.user_id -> auth.users)
insert into auth.users (id, email)
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'user-a@test.local'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'user-b@test.local');

-- 1. RLS włączone
select is(
  (select relrowsecurity from pg_class where relname = 'flashcards' and relnamespace = 'public'::regnamespace),
  true,
  'Tabela flashcards ma włączone Row Level Security'
);

-- Jako użytkownik A
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';

insert into public.flashcards (id, front, back, source)
values ('00000000-0000-4000-8000-00000000c001', 'Pytanie A', 'Odpowiedź A', 'manual');

-- 2. default auth.uid() ustawia właściciela
select is(
  (select user_id from public.flashcards where id = '00000000-0000-4000-8000-00000000c001'),
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid,
  'INSERT bez user_id przypisuje fiszkę do zalogowanego użytkownika A'
);

-- 3. A widzi swoją fiszkę
select is(
  (select count(*) from public.flashcards),
  1::bigint,
  'Użytkownik A widzi dokładnie jedną (swoją) fiszkę'
);

-- Jako użytkownik B
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';

-- 4. B nie widzi fiszki A
select is(
  (select count(*) from public.flashcards),
  0::bigint,
  'Użytkownik B nie widzi fiszki użytkownika A'
);

-- 5. B nie wstawi fiszki „jako A”
select throws_ok(
  $$insert into public.flashcards (user_id, front, back, source)
    values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Podszyta', 'Odpowiedź', 'manual')$$,
  '42501',
  null,
  'Użytkownik B nie może wstawić fiszki z user_id użytkownika A'
);

-- 6. B nie zmodyfikuje fiszki A (UPDATE dotyka 0 wierszy)
-- CTE modyfikujące dane musi być na najwyższym poziomie; agregat bez GROUP BY zawsze zwraca jeden wiersz.
with r as (
  update public.flashcards set front = 'zhakowane'
  where id = '00000000-0000-4000-8000-00000000c001'
  returning 1
)
select is(count(*), 0::bigint, 'UPDATE użytkownika B na fiszce użytkownika A modyfikuje 0 wierszy') from r;

-- Z powrotem jako A
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';

-- 7. DELETE odebrany nawet właścicielowi
select throws_ok(
  $$delete from public.flashcards where id = '00000000-0000-4000-8000-00000000c001'$$,
  '42501',
  null,
  'Fizyczne DELETE jest odrzucone (uprawnienie odebrane roli authenticated)'
);

-- 8a. Klient nie może sam ustawić deleted_at (nowy wiersz nie przechodzi polityki SELECT) — soft-delete tylko przez funkcję
select throws_ok(
  $$update public.flashcards set deleted_at = now() where id = '00000000-0000-4000-8000-00000000c001'$$,
  '42501',
  null,
  'Bezpośredni UPDATE deleted_at przez klienta jest odrzucony'
);

-- 8b. B nie soft-usunie fiszki A przez funkcję
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}';

select is(
  public.soft_delete_flashcard('00000000-0000-4000-8000-00000000c001'),
  false,
  'Użytkownik B nie soft-usunie fiszki użytkownika A (funkcja zwraca false)'
);

-- 8c. Właściciel soft-usuwa; fiszka znika z SELECT
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';

select is(
  public.soft_delete_flashcard('00000000-0000-4000-8000-00000000c001'),
  true,
  'Właściciel soft-usuwa swoją fiszkę (funkcja zwraca true)'
);

select is(
  (select count(*) from public.flashcards),
  0::bigint,
  'Soft-usunięta fiszka znika z SELECT właściciela'
);

-- 9. anon nie widzi nic
reset role;
set local request.jwt.claims = '';
set local role anon;

select is(
  (select count(*) from public.flashcards),
  0::bigint,
  'Rola anon nie widzi żadnych fiszek'
);

-- Znów jako A: ograniczenia treści
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}';

-- 10. CHECK-i treści
select throws_ok(
  $$insert into public.flashcards (front, back, source) values ('   ', 'Odpowiedź', 'manual')$$,
  '23514',
  null,
  'Pusty (białe znaki) front jest odrzucony'
);

select throws_ok(
  $$insert into public.flashcards (front, back, source) values (repeat('a', 201), 'Odpowiedź', 'manual')$$,
  '23514',
  null,
  'Front dłuższy niż 200 znaków jest odrzucony'
);

select throws_ok(
  $$insert into public.flashcards (front, back, source) values ('Pytanie', repeat('b', 501), 'manual')$$,
  '23514',
  null,
  'Back dłuższy niż 500 znaków jest odrzucony'
);

-- 11. Enum pochodzenia
select throws_ok(
  $$insert into public.flashcards (front, back, source) values ('Pytanie', 'Odpowiedź', 'import')$$,
  '22P02',
  null,
  'Nieznane pochodzenie fiszki (source) jest odrzucone'
);

select * from finish();

rollback;
