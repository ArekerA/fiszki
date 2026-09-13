<!-- PLAN-REVIEW-REPORT -->
# Plan Review: Prywatny, trwały magazyn fiszek (F-01)

- **Plan**: `context/changes/private-flashcard-store/plan.md`
- **Mode**: Deep
- **Date**: 2026-09-13
- **Verdict**: SOUND (przed triage: SOUND z drobnymi ostrzeżeniami; po triage wszystkie 6 ustaleń naniesione do planu)
- **Findings**: 0 critical, 3 warnings, 3 observations

## Verdicts

| Dimension             | Verdict                        |
| --------------------- | ------------------------------ |
| End-State Alignment   | PASS                           |
| Lean Execution        | PASS                           |
| Architectural Fitness | PASS                           |
| Blind Spots           | WARNING → PASS po poprawkach   |
| Plan Completeness     | WARNING → PASS po poprawkach   |

## Grounding

8/8 paths ✓ (`.prettierignore` celowo nowy), 6/6 symbols ✓ (`createClient`, `PROTECTED_ROUTES`, `includeIgnoreFile`, `astro/zod`, `supabase` w devDependencies, `major_version = 17`), brief↔plan ✓, Progress↔Phase ✓ (3 fazy, 17 kryteriów = 17 checkboxów).

Weryfikacja w kodzie (sub-agent): `createServerClient<Database>` (ssr 0.10.3) zwraca `SupabaseClient<Database, "public">` — tożsame z `SupabaseClient<Database>` (supabase-js 2.105.3); 4 callery `createClient` (`src/middleware.ts`, `src/pages/api/auth/{signin,signup,signout}.ts`) używają tylko `.auth.*` — typowanie nic im nie zmienia; flagi CLI 2.98.2 `db lint --local`, `gen types --local --schema`, `migration list --linked` istnieją; `astro/zod` = `zod/v4` (Zod 4.4.3) z `.trim()` i `z.enum(readonly)`; wpis `{ ignores }` w `tseslint.config(...)` poprawny.

## Findings

### F1 — Asercje pgTAP w kontrakcie testu nie skompilują się jak zapisano

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 1 §3 — Test izolacji pgTAP (asercje 3, 4, 6, 8, 9)
- **Detail**: (a) `is((select count(*) …), 0)` — `count(*)` to `bigint`, literal `0` to `integer`; pgTAP `is(anyelement, anyelement)` wymaga zgodnych typów. (b) `select count(*) from (update … returning 1) as r` jest nielegalne — instrukcja modyfikująca z RETURNING musi być w CTE.
- **Fix**: Rzutowanie `::bigint` we wszystkich asercjach na count, forma `with r as (update … returning 1) select count(*) from r` dla asercji 6, usunięty wariant „row_count”; dopisany akapit o pułapkach pgTAP pod listą asercji.
- **Decision**: FIXED

### F2 — Funkcja triggera bez `set search_path` → ostrzeżenie Security Advisor

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Phase 1 §1 — Migracja (trigger `set_updated_at`)
- **Detail**: Kontrakt określał `security invoker`, ale nie `search_path`. Supabase Security Advisor oznacza taką funkcję jako WARN `function_search_path_mutable`; `db lint --local` (kryterium 1.3) tego nie wykrywa — wyszłoby dopiero w panelu po `db push`.
- **Fix**: Kontrakt funkcji: `language plpgsql security invoker set search_path = ''`, `pg_catalog.now()`; kryterium Manual 3.5 i Progress 3.5 rozszerzone o „Security Advisor bez ostrzeżeń dla `public`”.
- **Decision**: FIXED

### F3 — Faza 3 nie sprawdza parytetu wersji Postgresa lokalnie ↔ hostowany

- **Severity**: ⚠️ WARNING
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Phase 3 §1 — Push migracji (człowiek)
- **Detail**: `config.toml` ma `major_version = 17`; plan nie ustalał wersji hostowanego projektu. Przy rozjeździe lokalny `db reset` nie odwzorowuje produkcji, a `link` zaskakuje ostrzeżeniami.
- **Fix**: Kontrakt Fazy 3 §1: po `link` człowiek potwierdza wersję PG hostowanego projektu i zgodność z `major_version`; rozjazd = osobny commit `config.toml` + ponowny `db:reset`/`db:test` przed `db push`.
- **Decision**: FIXED

### F4 — Parytet Zod ↔ CHECK ma dwie niedopowiedziane krawędzie

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Blind Spots
- **Location**: Phase 2 §3 — Moduł domenowy; Key Discoveries; Current State (wersja Zod)
- **Detail**: (a) Zod `.max(200)` liczy jednostki UTF-16, Postgres `char_length` liczy znaki — Zod surowszy dla emoji, „identyczne” nie jest ścisłe (kierunek bezpieczny). (b) Kontrakt nie mówił, że do `insert` idzie wynik `parse` (po trim), nie surowe `input`. Dodatkowo Current State podawał „Zod 3.x”, a `astro/zod` to `zod/v4` 4.4.3.
- **Fix**: `insertFlashcard` wstawia `parsed`; Key Discoveries i brief: „Zod co najmniej tak surowy jak CHECK (UTF-16 vs znaki)”; poprawiona wersja Zod w Current State.
- **Decision**: FIXED

### F5 — Drobiazgi uprzęży testowej i skryptów

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Plan Completeness
- **Location**: Phase 1 §4 — Skrypty npm; Phase 2 §1; Manual 1.6
- **Detail**: `test db --help` nie deklaruje domyślnego katalogu; `db:types` przekierowuje do nieistniejącego `src/db/` (na Windows `>` do nieistniejącego katalogu = błąd); kryterium 1.6 nie wspominało o `db:reset` między zepsuciem polityki a testem.
- **Fix**: `"db:test": "supabase test db supabase/tests"`; „utworzyć `src/db/`” w Fazie 2 §1 i przy skrypcie; `db:reset` przed i po negatywnym teście w kryterium 1.6.
- **Decision**: FIXED

### F6 — Alias `TypedSupabaseClient` lepiej wyprowadzić z `createClient`

- **Severity**: ℹ️ OBSERVATION
- **Impact**: 🏃 LOW — quick decision; fix is obvious and narrowly scoped
- **Dimension**: Architectural Fitness
- **Location**: Phase 2 §2 — Typowany klient
- **Detail**: `SupabaseClient<Database>` i zwrot `createServerClient<Database>` są dziś tożsame, ale `SupabaseClient` ma 5 slotów generycznych z unią w drugim — bump ssr/supabase-js może je rozjechać.
- **Fix**: `export type TypedSupabaseClient = NonNullable<ReturnType<typeof createClient>>`, bez importu z `@supabase/supabase-js`.
- **Decision**: FIXED
