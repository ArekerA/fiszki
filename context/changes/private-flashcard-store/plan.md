# Prywatny, trwały magazyn fiszek (F-01) — Implementation Plan

## Overview

Pierwsza warstwa domenowa aplikacji: tabela `public.flashcards` w Supabase z izolacją per właściciel egzekwowaną przez Row Level Security, soft-delete pod guardrail „fiszki nie mogą zniknąć”, enum pochodzenia (`ai` / `ai-edited` / `manual`) pod oba KPI z PRD oraz limity treści. Izolację weryfikuje test pgTAP „użytkownik A nie widzi fiszki użytkownika B” uruchamiany na lokalnym stacku Supabase. Po stronie kodu: wygenerowane typy bazy, typowany klient i moduł `src/lib/flashcards.ts` z `listFlashcards` / `insertFlashcard`, z których korzystają kolejne plastry (S-01, S-02, S-03). Migracja trafia na hostowany projekt ręcznie przez człowieka (`supabase db push`).

Źródło: `context/foundation/roadmap.md` § F-01, `context/changes/private-flashcard-store/change.md`.

## Current State Analysis

- **Baza danych: nieobecna.** `supabase/` zawiera tylko `config.toml` (`project_id = "al-fiszki"`, `major_version = 17`) i `.gitignore`. Brak `migrations/`, brak `seed.sql` (choć `[db.seed] sql_paths = ["./seed.sql"]` na niego wskazuje), brak `tests/`, brak typów bazy. Projekt nie jest zlinkowany z hostowanym (`supabase/.temp` ma tylko `cli-latest`).
- **Auth: obecny.** `src/middleware.ts` tworzy klienta Supabase SSR per żądanie z cookies, wypełnia `Astro.locals.user` (`src/env.d.ts`) i chroni prefiks `/dashboard`. `src/lib/supabase.ts:5` `createClient()` zwraca `null`, gdy brak `SUPABASE_URL` / `SUPABASE_KEY` — każde nowe użycie klienta musi sprawdzać `null` (AGENTS.md).
- **Klient nietypowany.** `createServerClient(SUPABASE_URL, SUPABASE_KEY, …)` bez generyka `Database`, więc `.from("…")` daje `any`-podobne typy. Do naprawy w tej zmianie.
- **Walidacja.** Brak Zod w `package.json`, ale Astro 6.3.1 eksportuje `astro/zod` (re-eksport `zod/v4`, Zod 4.4.3) — dostępny bez nowej zależności. Żaden kod w `src/` jeszcze go nie używa.
- **Narzędzia lokalne (sprawdzone 2026-09-13):** Docker 29.6.2 działa; Supabase CLI 2.98.2 (`npx supabase`) ma `test db` (pgTAP), `gen types --local`, `migration new`, `db reset`. `.env` i `.dev.vars` istnieją (hostowany projekt Supabase skonfigurowany, produkcja wdrożona — `context/deployment/deploy-plan.md`).
- **Testy: brak.** Repo nie ma runnera ani skryptu `test`. Bramki jakości to `npm run lint` (strictTypeChecked), `npm run build`, CI lint + build. Roadmapa (Open Question 3) oddaje decyzję o weryfikacji temu planowi — rozstrzygnięte: pgTAP lokalnie, CI bez zmian.
- **Reguły repo (AGENTS.md):** migracje wyłącznie addytywne; operacje na produkcyjnej bazie robi człowiek; pierwsza tabela domenowa musi mieć RLS per użytkownik; nowe endpointy w konwencji form POST + redirect (poza zakresem tej zmiany).

## Desired End State

Po zakończeniu planu:

1. `supabase/migrations/<ts>_create_flashcards.sql` tworzy enum `flashcard_source`, tabelę `flashcards` z RLS (SELECT/INSERT/UPDATE tylko własne, niesoftusunięte wiersze; brak polityki i uprawnienia DELETE), trigger `updated_at`, indeks pod listowanie.
2. `npm run db:test` przechodzi na lokalnym stacku i dowodzi: A nie widzi fiszki B; B nie wstawi fiszki „jako A”; `anon` nie widzi nic; DELETE jest odrzucony; puste/za długie treści są odrzucone przez CHECK; soft-usunięta fiszka znika z SELECT.
3. `src/db/database.types.ts` odzwierciedla schemat; `createClient()` zwraca `SupabaseClient<Database> | null`; `src/lib/flashcards.ts` eksportuje schemat Zod, typy i `listFlashcards` / `insertFlashcard`, a `npm run lint` i `npm run build` przechodzą.
4. Migracja jest zaaplikowana na hostowanym projekcie (`npx supabase migration list --linked` pokazuje ją jako zastosowaną), a produkcyjny Worker nadal działa (kod nie zmienia jeszcze żadnej strony).
5. AGENTS.md opisuje nowe komendy `db:*`, regułę „każda migracja z tabelą domenową ma RLS + test pgTAP” i pułapkę soft-delete.

### Key Discoveries:

- `src/lib/supabase.ts:5-8` — wzór „klient może być `null`”; moduł domenowy przyjmuje już-utworzonego klienta jako argument i nie dotyka `astro:env/server`, więc jest testowalny i nie wycieka sekretów.
- `src/middleware.ts:4` — `PROTECTED_ROUTES` chroni tylko `/dashboard`; ta zmiana nie dodaje tras, więc nie rusza middleware.
- `astro/zod` (Astro 6.3.1 `exports["./zod"]` → `zod/v4`, zainstalowany Zod 4.4.3) — walidacja bez nowej zależności; limity 200/500 w Zod muszą być co najmniej tak surowe jak CHECK w bazie. Nie są identyczne co do znaku: Zod `.max()` liczy jednostki UTF-16 (JS `length`), Postgres `char_length` liczy znaki Unicode, więc dla emoji / znaków spoza BMP Zod odrzuci wcześniej niż baza — kierunek bezpieczny (Zod ≥ CHECK).
- `auth.uid()` w Supabase czyta `request.jwt.claims` → w pgTAP symulujemy użytkownika przez `set local role authenticated` + `set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}'`. Test biegnie jako `postgres` (superuser, omija RLS), dlatego przełączenie roli jest obowiązkowe dla każdej asercji izolacji.
- Kolumna `user_id … default auth.uid()` + polityka INSERT `with check (user_id = auth.uid())` sprawia, że klient nie musi (i nie może skutecznie) podawać właściciela.
- Polityka SELECT z `deleted_at is null` sprawia, że UPDATE z `where id = …` też nie widzi wierszy usuniętych (Postgres wymaga widoczności SELECT dla wierszy odwołanych w WHERE) — „przywrócenie” z klienta jest niemożliwe; to świadoma decyzja MVP, S-04 może ją zmienić osobną migracją.
- `config.toml` wskazuje `./seed.sql`, którego nie ma — tworzymy pusty plik, żeby `db reset` był deterministyczny i AGENTS.md przestał ostrzegać.

## What We're NOT Doing

- Żadnego UI ani stron `.astro` / endpointów API dla fiszek — to S-01 (lista), S-02 (generowanie), S-03 (ręczne tworzenie).
- Żadnych danych powtórek SM-2 (termin, interwał, ease) — dochodzą w S-05.
- Brak `update` / `softDelete` w module TS — decyzje UX (potwierdzenie usuwania, przywracanie) należą do S-04; schemat już je umożliwia.
- Brak przywracania soft-usuniętych fiszek z poziomu klienta (patrz Key Discoveries).
- Brak runnera testów JS (Vitest) — pgTAP pokrywa jedyny test bezpieczeństwa danych w MVP; warstwa TS jest chroniona przez `lint` + `build`.
- CI (`.github/workflows/ci.yml`) bez zmian — test pgTAP tylko lokalnie (decyzja użytkownika).
- Brak automatycznego `db push` z CI; produkcyjną bazę dotyka człowiek.
- Brak tabeli `error_log` i innych pomysłów z rejestru ryzyk `infrastructure.md`.
- Brak zmian w `compatibility_date`, wersjach adaptera, wranglera i CLI Supabase.

## Implementation Approach

Kolejność „schemat → test → typy → kod → produkcja”: migracja i test pgTAP powstają razem i są weryfikowane na lokalnym stacku, zanim jakikolwiek TypeScript zależy od schematu. Typy są **generowane** z lokalnej bazy (nie pisane ręcznie), więc rozjazd schematu i kodu wychodzi na `npm run db:types` + `git diff`. Moduł domenowy jest cienką warstwą nad typowanym klientem: waliduje wejście Zod, ukrywa filtr soft-delete i mapuje błędy PostgREST na wyjątki. Push na hostowany projekt to ostatnia faza, wykonywana przez człowieka, po zielonych testach lokalnych; migracja jest addytywna, więc wdrożony Worker działa i przed, i po.

## Critical Implementation Details

- **Timing & lifecycle** — `supabase test db` wykonuje pliki `supabase/tests/*.sql` jako superuser `postgres` w jednej transakcji z `rollback`. Każdy plik zaczyna się od `begin;` + `create extension if not exists pgtap with schema extensions;` + `select plan(N);` i kończy `select * from finish(); rollback;`. Przełączanie użytkownika: `set local role authenticated; set local request.jwt.claims = '…';` — powrót do superusera przez `reset role;` przed wstawianiem do `auth.users` lub kolejnym przełączeniem.
- **State sequencing** — użytkowników testowych wstawiamy bezpośrednio do `auth.users (id, email)` jako superuser przed przełączeniem roli; FK `flashcards.user_id → auth.users(id)` wymaga, by istnieli. Nie używamy API GoTrue w testach.
- **Debug & observability** — kod błędu odrzucenia RLS to `42501` (insufficient_privilege), naruszenia CHECK `23514`; asercje `throws_ok` mają sprawdzać kod, nie tekst komunikatu (teksty różnią się między wersjami Postgresa).

## Phase 1: Schemat, RLS i test izolacji (lokalnie)

### Overview

Tworzy migrację `flashcards`, pusty `seed.sql`, test pgTAP i skrypty npm; weryfikuje wszystko na `npx supabase start`. Nie dotyka `src/`.

### Changes Required:

#### 1. Migracja

**File**: `supabase/migrations/<YYYYMMDDHHmmss>_create_flashcards.sql` (utworzyć przez `npx supabase migration new create_flashcards`)

**Intent**: Jedna encja i polityka izolacji — dokładnie zakres F-01. Addytywna, idempotentnie bezpieczna do `db push` na działającą produkcję.

**Contract**:

- `create type public.flashcard_source as enum ('ai', 'ai-edited', 'manual');`
- `create table public.flashcards`:
  - `id uuid primary key default gen_random_uuid()`
  - `user_id uuid not null default auth.uid() references auth.users(id) on delete cascade`
  - `front text not null`, `back text not null`
  - `source public.flashcard_source not null`
  - `created_at timestamptz not null default now()`, `updated_at timestamptz not null default now()`
  - `deleted_at timestamptz` (null = aktywna)
  - CHECK: `flashcards_front_not_blank` (`length(btrim(front)) > 0`), `flashcards_back_not_blank`, `flashcards_front_max` (`char_length(front) <= 200`), `flashcards_back_max` (`char_length(back) <= 500`)
- Indeks: `flashcards_user_id_created_at_idx on (user_id, created_at desc) where deleted_at is null`.
- Trigger `set_updated_at` (funkcja `public.set_updated_at()` `language plpgsql security invoker set search_path = ''`, `before update` ustawia `new.updated_at = pg_catalog.now()`). Ustalony `search_path` jest obowiązkowy: bez niego Supabase Security Advisor (panel hostowanego projektu) zgłasza WARN `function_search_path_mutable`, czego `db lint --local` nie wykrywa.
- `alter table public.flashcards enable row level security;`
- Polityki dla roli `authenticated` (osobno per operacja, zgodnie z konwencją Supabase):
  - `flashcards_select_own`: `for select using (user_id = auth.uid() and deleted_at is null)`
  - `flashcards_insert_own`: `for insert with check (user_id = auth.uid())`
  - `flashcards_update_own`: `for update using (user_id = auth.uid() and deleted_at is null) with check (user_id = auth.uid())`
  - **brak** polityki DELETE; dodatkowo `revoke delete on public.flashcards from anon, authenticated;`
- Brak polityk dla `anon` (domyślna odmowa).
- Komentarze `comment on column … deleted_at is 'Soft-delete; wiersze z deleted_at != null są niewidoczne przez RLS'` i na `source` (znaczenie `ai-edited`: fiszka z AI poprawiona przed akceptacją; do KPI adopcji liczy się `ai + ai-edited`).

#### 2. Seed

**File**: `supabase/seed.sql`

**Intent**: `config.toml` wskazuje ten plik; pusty plik z komentarzem usuwa niedeterminizm `db reset` i pułapkę z AGENTS.md.

**Contract**: Plik zawiera tylko komentarz SQL („brak danych startowych; użytkownicy testowi powstają w `supabase/tests/`”).

#### 3. Test izolacji pgTAP

**File**: `supabase/tests/flashcards_rls.test.sql`

**Intent**: Jedyny automatyczny dowód wymagania NFR „dane fiszek dostępne wyłącznie dla właściciela” oraz guardraila o utracie danych; chroni polityki przed regresją w S-04/S-05.

**Contract**: Plik w konwencji z „Critical Implementation Details”. Minimalny zestaw asercji (każda nazwana po polsku, dokładny `plan(N)` po zliczeniu):

1. Tabela ma RLS włączone (`select is(relrowsecurity, true) from pg_class where relname = 'flashcards'`).
2. Jako A (`set local role authenticated` + claims A): INSERT bez `user_id` → wiersz ma `user_id = A` (`default auth.uid()`).
3. Jako A: `is((select count(*) from public.flashcards), 1::bigint, '…')` = 1.
4. Jako B: `is((select count(*) from public.flashcards), 0::bigint, '…')` („B nie widzi fiszki A”).
5. Jako B: `throws_ok` INSERT z jawnym `user_id = A` → `42501`.
6. Jako B: UPDATE fiszki A `where id = …` modyfikuje 0 wierszy — w formie CTE: `is((with r as (update public.flashcards set front = 'x' where id = <id A> returning 1) select count(*) from r), 0::bigint, '…')`.
7. Jako A: `throws_ok` DELETE → `42501` (uprawnienie odebrane).
8. Jako A: UPDATE `set deleted_at = now()` → po nim `count(*)` = `0::bigint` (soft-usunięta znika z SELECT).
9. Jako `anon` (`set local role anon`, bez claims): `count(*)` = `0::bigint`.

Pułapki pgTAP obowiązujące w całym pliku: (a) `count(*)` zwraca `bigint`, a `is(anyelement, anyelement)` wymaga zgodnych typów — każdy oczekiwany literal rzutować `::bigint` (albo `count(*)::int`); (b) instrukcja modyfikująca z `RETURNING` nie może stać w podzapytaniu `FROM` — zawsze przez `WITH … AS (update … returning …)`.
10. Jako A: `throws_ok` INSERT z `front = '   '` → `23514`; INSERT z `front` o długości 201 → `23514`; INSERT z `back` o długości 501 → `23514`.
11. Jako A: `throws_ok` INSERT z `source = 'import'` → `22P02` (invalid enum).

#### 4. Skrypty npm

**File**: `package.json`

**Intent**: Nazwane, powtarzalne komendy dla człowieka i agenta; AGENTS.md będzie się do nich odwoływać.

**Contract**: Dodać w `scripts`:

- `"db:start": "supabase start"`
- `"db:stop": "supabase stop"`
- `"db:reset": "supabase db reset"`
- `"db:test": "supabase test db supabase/tests"` (ścieżka jawnie — `--help` CLI 2.98.2 nie deklaruje katalogu domyślnego)
- `"db:types": "supabase gen types --local --schema public > src/db/database.types.ts"` (używany w Fazie 2; dodany tu, by `package.json` był edytowany raz; katalog `src/db/` musi istnieć przed pierwszym uruchomieniem — na Windows `>` do nieistniejącego katalogu kończy się błędem)

Bez zmiany `dependencies` — `supabase` już jest w `devDependencies`.

### Success Criteria:

#### Automated Verification:

- Migracja aplikuje się na czystym stacku: `npm run db:reset` kończy się bez błędu (w tym seed).
- Test izolacji przechodzi: `npm run db:test` raportuje wszystkie asercje jako `ok`, zero `not ok`.
- Schemat zgadza się z kontraktem: `npx supabase db lint --local` nie zgłasza błędów w `public`.
- Formatowanie: `npm run format` nie zmienia `package.json` po edycji (Prettier w pre-commit).

#### Manual Verification:

- W Supabase Studio (`http://127.0.0.1:54323`) tabela `flashcards` ma włączone RLS i trzy polityki (select/insert/update), brak polityki delete.
- Celowe zepsucie polityki SELECT (np. usunięcie warunku `user_id = auth.uid()` w lokalnej kopii migracji), potem `npm run db:reset` (test biegnie na aktualnym stanie bazy, sam nie aplikuje migracji) i `npm run db:test` — test faluje, czyli naprawdę chroni izolację. Przywrócić plik i ponownie `db:reset` po próbie.

**Implementation Note**: Po zakończeniu tej fazy i przejściu weryfikacji automatycznej zatrzymaj się na potwierdzeniu człowieka, że ręczna weryfikacja się udała, zanim przejdziesz do Fazy 2. Bloki faz mają zwykłe punktory — checkboxy żyją w sekcji `## Progress` na końcu planu.

---

## Phase 2: Typy i warstwa dostępu w kodzie

### Overview

Generuje typy bazy z lokalnego stacku, typuje klienta Supabase i dodaje moduł domenowy `flashcards.ts` z walidacją Zod oraz dwiema funkcjami (`list`, `insert`). Bez UI. Weryfikacja: lint, build, `astro check`.

### Changes Required:

#### 1. Wygenerowane typy bazy

**File**: `src/db/database.types.ts` (nowy, generowany)

**Intent**: Jedyne źródło typów schematu w kodzie; regenerowany po każdej migracji, nigdy edytowany ręcznie.

**Contract**: Utworzyć katalog `src/db/` (przekierowanie `>` w skrypcie go nie tworzy), następnie wynik `npm run db:types` (po `npm run db:reset`). Plik zaczyna się nagłówkiem generatora Supabase i eksportuje `Database`. W `eslint.config.js` dodać do tablicy `tseslint.config(...)` (obok `includeIgnoreFile(gitignorePath)`, który dziś jest jedynym źródłem ignorowania) wpis `{ ignores: ["src/db/database.types.ts"] }` — kod generowany nie przechodzi `strictTypeChecked` i nie powinien być „naprawiany” przez `eslint --fix` w pre-commit. Tę samą ścieżkę wpisać do `.prettierignore` (nowy plik, jedna linia), tak by `git diff` po regeneracji był czysty.

#### 2. Typowany klient

**File**: `src/lib/supabase.ts`

**Intent**: `.from("flashcards")` ma zwracać typowane wiersze; reszta zachowania (null bez konfiguracji, cookies) bez zmian.

**Contract**: `createServerClient<Database>(…)` (import typu `Database` z `@/db/database.types`); eksport typu `export type TypedSupabaseClient = NonNullable<ReturnType<typeof createClient>>` używany przez moduły domenowe — alias wyprowadzony ze zwrotu `createClient`, a nie z `SupabaseClient<Database>` z `@supabase/supabase-js`, żeby nie rozjechał się z realnym zwrotem `@supabase/ssr` przy bumpie pakietów (dziś oba typy są tożsame: ssr 0.10.3 zwraca `SupabaseClient<Database, "public">`). Sygnatura `createClient(requestHeaders, cookies): TypedSupabaseClient | null` (w praktyce: typ wnioskowany, alias tylko go nazywa). `src/middleware.ts` i endpointy auth kompilują się bez zmian.

#### 3. Moduł domenowy

**File**: `src/lib/flashcards.ts` (nowy)

**Intent**: Cienka, typowana warstwa nad tabelą, z której korzystają S-01 (lista) i S-03/S-02 (zapis). Ukrywa filtr soft-delete i egzekwuje te same limity co baza, zanim żądanie wyjdzie do Supabase.

**Contract**:

- Stałe: `FLASHCARD_FRONT_MAX = 200`, `FLASHCARD_BACK_MAX = 500`, `FLASHCARD_SOURCES = ["ai", "ai-edited", "manual"] as const` (wartości muszą odpowiadać `Database["public"]["Enums"]["flashcard_source"]` — wymusić typem, np. `satisfies readonly FlashcardSource[]`).
- `flashcardInputSchema = z.object({ front: z.string().trim().min(1).max(200), back: z.string().trim().min(1).max(500), source: z.enum(FLASHCARD_SOURCES) })` z `import { z } from "astro/zod"`; `type FlashcardInput = z.infer<…>`.
- `type Flashcard = Database["public"]["Tables"]["flashcards"]["Row"]`.
- `listFlashcards(supabase: TypedSupabaseClient): Promise<Flashcard[]>` — `select("*")`, `.is("deleted_at", null)`, `order("created_at", { ascending: false })`; przy `error` rzuca `Error` z `error.message`.
- `insertFlashcard(supabase: TypedSupabaseClient, input: FlashcardInput): Promise<Flashcard>` — `const parsed = flashcardInputSchema.parse(input)`, następnie `insert(parsed).select().single()` — do bazy idzie **wynik `parse` (po `.trim()`)**, nigdy surowe `input`; **nie** przekazuje `user_id` (baza ustawia `auth.uid()`); przy `error` rzuca `Error`.
- Moduł nie importuje `astro:env/server` i nie tworzy klienta — jest czystą funkcją klienta, zgodnie ze wzorem „każde użycie sprawdza `null`” u wywołującego.

### Success Criteria:

#### Automated Verification:

- Typy zsynchronizowane: `npm run db:types` po `db:reset` nie zmienia `src/db/database.types.ts` (`git diff --exit-code src/db`).
- Lint przechodzi: `npx astro sync && npm run lint` (bez błędów; `no-console` bez nowych ostrzeżeń).
- Build przechodzi: `npm run build`.
- Sprawdzenie typów Astro: `npx astro check` bez błędów w `src/lib/**`.

#### Manual Verification:

- W `npm run dev` istniejący przepływ `/auth/signin` → `/dashboard` działa jak przed zmianą (klient typowany nie zmienił zachowania auth).
- Przegląd kodu: `insertFlashcard` nie przyjmuje ani nie ustawia `user_id`; limity w Zod = limity w migracji.

**Implementation Note**: Po zakończeniu tej fazy i przejściu weryfikacji automatycznej zatrzymaj się na potwierdzeniu człowieka przed Fazą 3.

---

## Phase 3: Migracja na produkcję i domknięcie dokumentacji

### Overview

Człowiek linkuje projekt i pushuje migrację na hostowany Supabase; agent weryfikuje stan zdalny i aktualizuje AGENTS.md o nowe komendy, reguły i pułapki. Kod produkcyjny Workera nie zmienia zachowania (moduł nie ma jeszcze konsumenta), więc deploy przez Workers Builds po merge jest bezpieczny.

### Changes Required:

#### 1. Push migracji (człowiek)

**File**: — (operacja na hostowanym projekcie)

**Intent**: Schemat produkcyjny = schemat lokalny, z zapisem w `supabase_migrations.schema_migrations`, żeby przyszłe `db push` nie konfliktowały.

**Contract**: Człowiek wykonuje w swoim terminalu: `npx supabase link --project-ref <ref>` (ref z `SUPABASE_URL`). Po `link` potwierdza parytet wersji Postgresa: wersja hostowanego projektu (ostrzeżenie CLI przy `link` lub panel → Settings → Infrastructure) musi zgadzać się z `major_version = 17` w `supabase/config.toml`; jeśli nie — rozjazd naprawia osobny commit `config.toml` (i ponowny `db:reset` + `db:test` lokalnie) **przed** `db push`. Następnie `npx supabase db push` i potwierdzenie w czacie. Agent nie uruchamia żadnej z tych komend (AGENTS.md).

#### 2. Weryfikacja stanu zdalnego (agent, read-only)

**File**: —

**Intent**: Dowód, że migracja jest na produkcji i typy zdalne są tożsame z lokalnymi.

**Contract**: `npx supabase migration list --linked` pokazuje migrację jako zastosowaną lokalnie i zdalnie; `npx supabase gen types --linked --schema public` porównane z `src/db/database.types.ts` nie różni się (poza nagłówkiem, jeśli generator go wersjonuje).

#### 3. AGENTS.md

**File**: `AGENTS.md`

**Intent**: Nowe fakty o repo, których agent nie wyczyta z kodu: komendy bazy, reguła RLS + pgTAP dla każdej tabeli domenowej, soft-delete, kto robi `db push`.

**Contract**:

- „Pułapki”: zastąpić akapit „`supabase/` zawiera tylko `config.toml`…” opisem stanu po zmianie: migracje w `supabase/migrations/`, testy pgTAP w `supabase/tests/`, `seed.sql` pusty; **każda nowa tabela domenowa: RLS włączone, polityki per operacja, test w `supabase/tests/`**; fiszki są soft-usuwane (`deleted_at`), SELECT przez RLS pomija usunięte, DELETE odebrany — filtr jest w bazie, moduł `src/lib/flashcards.ts` dodatkowo filtruje.
- „Komendy”: dodać blok `npm run db:start|db:reset|db:test|db:types`; `npx supabase link` + `db push` = człowiek; po każdej migracji `npm run db:types` i commit wygenerowanego pliku.
- „Architektura”: jedno zdanie o warstwie `src/lib/flashcards.ts` (funkcje przyjmują klienta, nie tworzą go; wywołujący sprawdza `null`) i o `src/db/database.types.ts` jako pliku generowanym.
- „Człowiek, nie agent”: dopisać `supabase link` / `db push` / zmiany w panelu Supabase (już częściowo jest).

#### 4. Zamknięcie zmiany

**File**: `context/changes/private-flashcard-store/change.md`, `context/foundation/roadmap.md`

**Intent**: Stan planu i roadmapy odzwierciedla rzeczywistość; zamknięcie lifecycle należy do `/10x-archive`.

**Contract**: `/10x-implement` aktualizuje `## Progress` i SHA; roadmapa F-01 przechodzi na `in-progress` przy pierwszej fazie (robi to `/10x-implement`). Ten plan niczego tu ręcznie nie stempluje poza tym, co robi skill.

### Success Criteria:

#### Automated Verification:

- `npx supabase migration list --linked` pokazuje `create_flashcards` jako zastosowaną zdalnie.
- `npx supabase gen types --linked --schema public` jest tożsame z `src/db/database.types.ts` (porównanie `diff` po zapisaniu do pliku tymczasowego).
- `npm run lint && npm run build` po edycji AGENTS.md (Prettier w pre-commit formatuje `.md`).

#### Manual Verification:

- Produkcyjny URL (`context/deployment/deploy-plan.md` → `production_url`) odpowiada 200 na `/` i przepływ `/auth/signin` działa po deployu przez Workers Builds.
- W panelu Supabase (Table Editor) tabela `flashcards` istnieje z włączonym RLS, a Security Advisor nie zgłasza ostrzeżeń dla schematu `public` (w szczególności brak `function_search_path_mutable`); człowiek potwierdza w czacie.

---

## Testing Strategy

### Unit Tests:

- Brak testów jednostkowych TS (decyzja: bez runnera JS w tej zmianie). Walidacja Zod jest pokryta typami i lintem; jej granice odpowiadają CHECK-om testowanym w pgTAP.

### Integration Tests:

- `supabase/tests/flashcards_rls.test.sql` (pgTAP) — pełna lista asercji w Fazie 1 §3. Uruchamiane `npm run db:test` na lokalnym stacku; wymaga Dockera.

### Manual Testing Steps:

1. `npm run db:start` → `npm run db:reset` → `npm run db:test`: wszystko zielone.
2. Studio: sprawdzić polityki i brak DELETE.
3. Negatywny test: zepsuć politykę lokalnie, `db:reset` + `db:test` → czerwone; przywrócić.
4. Po Fazie 2: `npm run dev`, logowanie i `/dashboard` bez regresji.
5. Po Fazie 3: `migration list --linked`, Table Editor, produkcyjny URL.

## Performance Considerations

Skala `users: small`; jedyny wzór zapytania w MVP to „lista aktywnych fiszek właściciela od najnowszej” — pokryty indeksem częściowym `(user_id, created_at desc) where deleted_at is null`. RLS z `auth.uid()` jest tani (funkcja `stable`). Brak dodatkowych zapytań na żądanie; nie zwiększa ryzyka limitu CPU Workera (rejestr ryzyk `infrastructure.md`), bo ta zmiana nie dodaje renderowania.

## Migration Notes

- Migracja jest wyłącznie addytywna (nowy typ, nowa tabela). Wdrożony kod nie odwołuje się do tabeli, więc kolejność „push migracji” vs „deploy kodu” nie ma znaczenia w tej zmianie; w S-01 kolejność będzie: najpierw `db push`, potem merge.
- Rollback schematu nie jest przewidziany (`wrangler rollback` nie cofa migracji — AGENTS.md); w razie potrzeby kolejna migracja addytywna.
- `supabase link` zapisuje ref projektu w `supabase/.temp` (gitignorowane) — każdy nowy checkout linkuje ponownie (człowiek).

## References

- Roadmapa F-01: `context/foundation/roadmap.md` §Foundations
- Zmiana: `context/changes/private-flashcard-store/change.md`
- PRD: `context/foundation/prd.md` (US-01, NFR izolacja, Guardrails, Access Control)
- Klient Supabase: `src/lib/supabase.ts:5-23`; middleware: `src/middleware.ts:4-25`
- Reguły repo: `AGENTS.md` (Środowisko i sekrety, Pułapki, Komendy)
- Wdrożenie: `context/deployment/deploy-plan.md`

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Schemat, RLS i test izolacji (lokalnie)

#### Automated

- [x] 1.1 Migracja aplikuje się na czystym stacku (`npm run db:reset`)
- [x] 1.2 Test izolacji przechodzi (`npm run db:test`)
- [x] 1.3 Schemat bez błędów lintu (`npx supabase db lint --local`)
- [x] 1.4 Formatowanie `package.json` czyste (`npm run format`)

#### Manual

- [x] 1.5 Studio: RLS włączone, 3 polityki, brak DELETE
- [x] 1.6 Negatywny test: zepsuta polityka → `db:test` faluje, plik przywrócony

### Phase 2: Typy i warstwa dostępu w kodzie

#### Automated

- [ ] 2.1 Typy zsynchronizowane (`npm run db:types` bez diffu)
- [ ] 2.2 Lint przechodzi (`npx astro sync && npm run lint`)
- [ ] 2.3 Build przechodzi (`npm run build`)
- [ ] 2.4 `npx astro check` bez błędów w `src/lib/**`

#### Manual

- [ ] 2.5 `/auth/signin` → `/dashboard` bez regresji w `npm run dev`
- [ ] 2.6 Przegląd: brak `user_id` w `insertFlashcard`, limity Zod = CHECK

### Phase 3: Migracja na produkcję i domknięcie dokumentacji

#### Automated

- [ ] 3.1 `migration list --linked` pokazuje migrację jako zastosowaną zdalnie
- [ ] 3.2 Typy zdalne tożsame z `src/db/database.types.ts`
- [ ] 3.3 `npm run lint && npm run build` po edycji AGENTS.md

#### Manual

- [ ] 3.4 Produkcyjny URL odpowiada, przepływ auth działa
- [ ] 3.5 Panel Supabase: tabela `flashcards` z RLS, Security Advisor bez ostrzeżeń, potwierdzenie człowieka
