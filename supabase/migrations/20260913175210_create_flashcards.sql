-- F-01: prywatny, trwały magazyn fiszek (context/changes/private-flashcard-store)
-- Migracja addytywna: nowy enum, nowa tabela, RLS per właściciel, soft-delete.

create type public.flashcard_source as enum ('ai', 'ai-edited', 'manual');

comment on type public.flashcard_source is
  'Pochodzenie fiszki: ai = wygenerowana przez AI i zaakceptowana bez zmian; ai-edited = z AI, poprawiona przed akceptacją; manual = utworzona ręcznie. Do KPI adopcji AI liczy się ai + ai-edited.';

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  front text not null,
  back text not null,
  source public.flashcard_source not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint flashcards_front_not_blank check (length(btrim(front)) > 0),
  constraint flashcards_back_not_blank check (length(btrim(back)) > 0),
  constraint flashcards_front_max check (char_length(front) <= 200),
  constraint flashcards_back_max check (char_length(back) <= 500)
);

comment on table public.flashcards is 'Fiszki użytkowników. Widoczne wyłącznie dla właściciela (RLS).';
comment on column public.flashcards.source is
  'Pochodzenie fiszki (enum flashcard_source). ai-edited = fiszka z AI poprawiona przed akceptacją; do KPI adopcji liczy się ai + ai-edited.';
comment on column public.flashcards.deleted_at is
  'Soft-delete; wiersze z deleted_at != null są niewidoczne przez RLS. Fizyczne DELETE jest odebrane rolom anon i authenticated.';

create index flashcards_user_id_created_at_idx
  on public.flashcards (user_id, created_at desc)
  where deleted_at is null;

-- updated_at utrzymywany przez trigger; search_path pusty (Security Advisor: function_search_path_mutable).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = pg_catalog.now();
  return new;
end;
$$;

create trigger set_updated_at
  before update on public.flashcards
  for each row
  execute function public.set_updated_at();

-- Izolacja per użytkownik
alter table public.flashcards enable row level security;

create policy flashcards_select_own
  on public.flashcards
  for select
  to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null);

create policy flashcards_insert_own
  on public.flashcards
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));

create policy flashcards_update_own
  on public.flashcards
  for update
  to authenticated
  using (user_id = (select auth.uid()) and deleted_at is null)
  with check (user_id = (select auth.uid()));

-- Brak polityki DELETE (guardrail „fiszki nie mogą zniknąć”); dodatkowo odebrane uprawnienie.
revoke delete on public.flashcards from anon, authenticated;

-- Soft-delete przez funkcję: polityka SELECT (deleted_at is null) jest przez Postgresa sprawdzana także
-- na NOWYM wierszu po UPDATE, więc klient nie może sam ustawić deleted_at. Funkcja działa jako właściciel
-- (security definer), ale ogranicza się do fiszek wywołującego. Zwraca true, gdy fiszka została usunięta.
create or replace function public.soft_delete_flashcard(flashcard_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with r as (
    update public.flashcards
    set deleted_at = pg_catalog.now()
    where id = flashcard_id
      and user_id = (select auth.uid())
      and deleted_at is null
    returning 1
  )
  select count(*) > 0 from r;
$$;

comment on function public.soft_delete_flashcard(uuid) is
  'Soft-delete własnej fiszki (ustawia deleted_at). Jedyna droga usunięcia z poziomu klienta; true = usunięto, false = brak własnej aktywnej fiszki o tym id.';

revoke execute on function public.soft_delete_flashcard(uuid) from public, anon;
grant execute on function public.soft_delete_flashcard(uuid) to authenticated;
