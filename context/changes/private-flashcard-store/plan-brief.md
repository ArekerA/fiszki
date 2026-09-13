# Prywatny, trwały magazyn fiszek (F-01) — Plan Brief

> Full plan: `context/changes/private-flashcard-store/plan.md`

## What & Why

Budujemy pierwszą warstwę danych aplikacji: tabelę `flashcards` w Supabase z izolacją per właściciel egzekwowaną po stronie bazy (RLS), soft-delete i oznaczeniem pochodzenia fiszki. Bez niej gwiazda przewodnia (S-02) nie ma gdzie zapisać zaakceptowanych fiszek, a żaden plaster nie da się bezpiecznie wdrożyć, bo PRD wymaga, by żaden użytkownik nie widział fiszek innego. Fundament jest celowo minimalny: jedna encja, polityka izolacji, dowód w teście.

## Starting Point

Repo to scaffold `10x-astro-starter` z działającym auth (Supabase SSR, sesja w cookies, `Astro.locals.user`), wdrożony na Cloudflare Workers. Katalog `supabase/` ma tylko `config.toml`: brak migracji, typów bazy, testów i runnera testów. Klient Supabase jest nietypowany i może być `null`, gdy brak konfiguracji.

## Desired End State

Migracja tworzy `flashcards` (pytanie, odpowiedź, właściciel z `default auth.uid()`, `source` = `ai | ai-edited | manual`, `deleted_at`, limity 200/500 znaków) z politykami RLS select/insert/update tylko dla własnych, aktywnych wierszy i bez możliwości DELETE. Test pgTAP `npm run db:test` dowodzi, że użytkownik A nie widzi fiszki B. Kod ma wygenerowane typy, typowany klient i moduł `src/lib/flashcards.ts` z `listFlashcards` / `insertFlashcard`. Migracja jest na hostowanym projekcie, AGENTS.md opisuje nowe komendy i reguły.

## Key Decisions Made

| Decision            | Choice                                                       | Why (1 sentence)                                                                                          |
| ------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Pochodzenie fiszki  | Enum `ai` / `ai-edited` / `manual`                           | KPI adopcji liczy `ai + ai-edited`, KPI jakości odróżnia akceptację „jak jest” od poprawionej.            |
| Soft-delete         | Kolumna `deleted_at` już teraz; RLS ukrywa usunięte; DELETE odebrany | Guardrail „fiszki nie mogą zniknąć” spełniony w bazie, S-04 zmienia tylko UI.                     |
| Limity treści       | not null, niepuste po trim, max 200 / 500 znaków             | Fiszka jest krótka z definicji; chroni przed „odpowiedzią = akapit tekstu” z AI.                          |
| Właściciel          | `user_id default auth.uid()` + `with check`                  | Klient nie podaje właściciela, więc nie może go sfałszować.                                               |
| Test izolacji       | pgTAP przez `supabase test db` na lokalnym stacku            | Testuje RLS tam, gdzie żyje, bez nowych zależności npm.                                                   |
| CI                  | Bez zmian; test tylko lokalnie                               | Decyzja użytkownika: CI zostaje szybkie, solo dev uruchamia `db:test` przed commitem.                     |
| Push na produkcję   | `supabase link` + `db push` ręcznie przez człowieka          | Zgodne z regułą repo „produkcyjna baza = człowiek”; migracja addytywna.                                   |
| Warstwa kodu        | Generowane typy + `flashcards.ts` (list/insert), Zod z `astro/zod` | S-01 i S-03 dostają typowane wejście; filtr soft-delete i limity w jednym miejscu; brak nowej zależności. |
| Walidacja w Zod     | Limity co najmniej tak surowe jak CHECK (Zod liczy UTF-16, baza znaki) | Błąd walidacji wychodzi przed żądaniem do Supabase, a baza pozostaje ostatnią linią obrony.               |

## Scope

**In scope:**

- Migracja `create_flashcards` (enum, tabela, CHECK, indeks, trigger `updated_at`, RLS, revoke DELETE)
- Pusty `supabase/seed.sql`, test `supabase/tests/flashcards_rls.test.sql`, skrypty `db:*` w `package.json`
- `src/db/database.types.ts` (generowany), `createClient<Database>`, `src/lib/flashcards.ts`
- Push migracji na hostowany projekt (człowiek), aktualizacja AGENTS.md

**Out of scope:**

- UI, strony i endpointy dla fiszek (S-01, S-02, S-03)
- Dane SM-2 (S-05), `update` / `softDelete` w module TS i przywracanie usuniętych (S-04)
- Runner testów JS, zmiany w CI, automatyczny `db push`
- Zmiany wersji adaptera, wranglera, CLI Supabase, `compatibility_date`

## Architecture / Approach

Schemat → test → typy → kod → produkcja. Migracja i test pgTAP powstają razem i są weryfikowane na `npx supabase start`. Typy są generowane z lokalnej bazy, więc rozjazd schematu i kodu wychodzi na `git diff`. Moduł domenowy przyjmuje już utworzonego klienta (wywołujący sprawdza `null`, jak w middleware), waliduje wejście Zod i ukrywa filtr `deleted_at`. Baza jest źródłem prawdy dla izolacji; kod jej nie duplikuje, tylko ją wykorzystuje.

## Phases at a Glance

| Phase                                          | What it delivers                                                        | Key risk                                                                    |
| ---------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| 1. Schemat, RLS i test izolacji (lokalnie)     | Migracja, seed, test pgTAP, skrypty npm; zielony `db:test`              | Symulacja JWT w pgTAP (`set local role` + `request.jwt.claims`) wymaga precyzji |
| 2. Typy i warstwa dostępu w kodzie             | `database.types.ts`, typowany klient, `flashcards.ts`; lint + build     | Wygenerowany plik kontra `strictTypeChecked` (ignorować w ESLint/Prettier)  |
| 3. Migracja na produkcję i dokumentacja        | `db push` (człowiek), weryfikacja `migration list`, AGENTS.md           | Krok ręczny; `link` trzeba powtórzyć na każdym checkoucie                    |

**Prerequisites:** Docker uruchomiony; Supabase CLI z `devDependencies` (2.98.2); dostęp człowieka do hostowanego projektu Supabase (ref z `SUPABASE_URL`).
**Estimated effort:** ~2–3 sesje po godzinach, 3 fazy; Faza 1 największa.

## Open Risks & Assumptions

- Zakładamy, że wstawianie użytkowników testowych bezpośrednio do `auth.users (id, email)` działa na lokalnym Postgres 17 z aktualnym schematem GoTrue; jeśli nie, test doda brakujące kolumny wymagane (`instance_id`, `aud`, `role`).
- `supabase test db` musi sam włączyć pgTAP; plik testu zawiera `create extension if not exists pgtap` na wypadek, gdyby nie.
- Ukrywanie soft-usuniętych wierszy w RLS oznacza brak przywracania z klienta w MVP; S-04 może to zmienić osobną, addytywną migracją.
- Test biegnie tylko lokalnie; regresja polityk w S-04/S-05 zostanie wyłapana wyłącznie, gdy dev uruchomi `npm run db:test`.

## Success Criteria (Summary)

- `npm run db:reset && npm run db:test` przechodzi: A nie widzi B, DELETE niemożliwy, CHECK-i i enum działają, soft-usunięta fiszka znika.
- `npm run lint && npm run build` przechodzą z typowanym klientem i modułem `flashcards.ts`; auth bez regresji.
- `npx supabase migration list --linked` pokazuje migrację na produkcji, a AGENTS.md opisuje komendy `db:*` i regułę „RLS + test dla każdej tabeli domenowej”.
