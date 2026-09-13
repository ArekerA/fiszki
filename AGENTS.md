# Repository Guidelines

## Środowisko i sekrety

- Dwa pliki na te same zmienne: `.env` czyta Node/Astro (np. `astro check`), `.dev.vars` czyta workerd przy `npm run dev`. Oba gitignorowane; wzór w `.env.example`.
- `SUPABASE_URL` i `SUPABASE_KEY` są zadeklarowane w `astro.config.mjs` jako `context: "server", access: "secret", optional: true`. Importuj je **wyłącznie** z `astro:env/server` i wyłącznie w kodzie serwerowym (middleware, `src/pages/api/**`, frontmatter `.astro`, `src/lib/**`). Import w komponencie React zbuduje się błędnie lub wycieknie sekret.
- Ponieważ zmienne są opcjonalne, aplikacja **musi działać bez Supabase**: `createClient()` z `@/lib/supabase` zwraca `null`, a `Layout.astro` pokazuje baner z `missingConfigs` (`src/lib/config-status.ts`). Każde nowe użycie klienta ma sprawdzać `null`; nową zewnętrzną integrację (np. dostawcę LLM) dopisz do `configStatuses`, żeby brak klucza był widoczny w UI zamiast wysypywać stronę.
- Sekrety produkcyjne żyją w Workers Secrets: `npx wrangler secret put NAME` lub `npx wrangler secret bulk .dev.vars` (wpisuje człowiek, nigdy agent). Sekrety są **per wersja Workera**: zmiana tworzy nową wersję, a istniejące wersje (w tym aliasy preview `smoke-…`) zachowują stare wartości — po zmianie sekretu ponów `versions upload`, żeby preview je dostał. Objaw złego `SUPABASE_URL` to puste 500 na każdej ścieżce (wyjątek `Invalid supabaseUrl` w middleware). GitHub Actions nie potrzebuje sekretów Cloudflare, bo nie deployuje (patrz „Deploy").
- Rotacja `SUPABASE_KEY`: `secret put` → sesje auth są w cookies Supabase, więc nic więcej; gdyby kiedyś kod zaczął używać `Astro.session` (KV `SESSION`), po rotacji trzeba dodatkowo wyczyścić ten namespace.

## Deploy (Cloudflare Workers, nie Pages)

- Platforma: Workers + Static Assets (`context/foundation/infrastructure.md`). Deploy = `npx wrangler deploy`; **nigdy** `wrangler pages deploy` — adapter `@astrojs/cloudflare` 13.x nie wspiera Pages. Nie zmieniać `main` w `wrangler.jsonc` (`@astrojs/cloudflare/entrypoints/server` jest poprawne dla 13.x; przewodniki z `dist/_worker.js` dotyczą adaptera ≤12).
- Dev = `npm run dev` (workerd przez `@cloudflare/vite-plugin`), **nie** `wrangler dev`. `npm run preview` wymaga wcześniejszego `npm run build`.
- Auto-deploy `master` robi Cloudflare **Workers Builds** (repo podpięte w panelu Workera `al-fiszki`, build `npm run build`, deploy `npx wrangler deploy`); GitHub Actions to tylko lint + build. Ręczny `npx wrangler deploy` jest ścieżką awaryjną; preview bez dotykania produkcji: `npx wrangler versions upload --preview-alias <nazwa>`.
- Adapter auto-provisionuje bindingi `SESSION` (KV) i `IMAGES` przy deployu — widać je w `npx wrangler deploy --dry-run`. Kod ich nie używa (auth = cookies Supabase); nie usuwać ich ręcznie, bo `wrangler rollback` na wersję z bindingiem do usuniętego zasobu jest blokowany.
- `compatibility_date` w `wrangler.jsonc` oraz wersje `@astrojs/cloudflare` i `wrangler` podbijać tylko świadomym commitem z przeczytanym changelogiem (zmiana daty zmienia runtime bez zmiany kodu; od 2026-08-04 `nodejs_compat` jest domyślne).
- Rollback: `npx wrangler rollback [VERSION_ID] -y` (do 100 wersji, `npx wrangler versions list`). Nie cofa sekretów ani migracji Supabase — migracje tylko addytywne. Logi: `npx wrangler tail --format json --status error` (Free: 3 dni retencji, preview URL bez logów).
- Człowiek, nie agent: pierwszy deploy produkcyjny, rollback, rotacja kluczy, usunięcie Workera/KV, zmiana planu Free → Paid, operacje w panelu Supabase, `supabase link` i `supabase db push` (migracje na hostowaną bazę).

## Pułapki

- Baza: migracje w `supabase/migrations/` (pierwsza: `create_flashcards`), testy pgTAP w `supabase/tests/*.sql`, `supabase/seed.sql` celowo pusty (wskazuje na niego `config.toml`). Lokalny stack: `npm run db:start` (Docker). **Każda nowa tabela domenowa: RLS włączone, polityki osobno per operacja dla roli `authenticated`, test izolacji w `supabase/tests/`** (`npm run db:test` biegnie na aktualnym stanie bazy — po zmianie migracji najpierw `npm run db:reset`). Funkcje SQL zawsze z `set search_path = ''` (Security Advisor: `function_search_path_mutable`; `db lint` tego nie wykrywa).
- Fiszki są soft-usuwane (`deleted_at`): polityka SELECT pomija usunięte, uprawnienie DELETE jest odebrane rolom `anon`/`authenticated`. Postgres sprawdza nowy wiersz po UPDATE także względem polityki SELECT, więc klient **nie może** sam ustawić `deleted_at` (RLS odrzuci) — jedyna droga to RPC `soft_delete_flashcard(id)` (security definer, tylko własne fiszki, zwraca `true/false`). Przywracanie usuniętych fiszek z klienta jest niemożliwe (świadoma decyzja MVP; zmiana = osobna migracja). `src/lib/flashcards.ts` dodatkowo filtruje `deleted_at is null`.
- Pułapki pgTAP: `count(*)` to `bigint` — literal w `is()` rzutuj `::bigint`; CTE modyfikujące dane musi być na najwyższym poziomie (`with r as (update … returning 1) select is(count(*), …) from r`); `throws_ok` z kodem błędu to forma 4-argumentowa `(sql, '42501', null, opis)` — 3-argumentowa traktuje trzeci argument jako tekst komunikatu. Użytkowników testowych wstawiaj do `auth.users (id, email)` jako superuser, a `auth.uid()` symuluj przez `set local role authenticated` + `set local request.jwt.claims = '{"sub":"<uuid>","role":"authenticated"}'`.
- Nazwa Workera (`wrangler.jsonc` `name`) i `supabase/config.toml` `project_id` to `al-fiszki`; `package.json` `name` celowo został `10x-astro-starter` (nie ma znaczenia dla deployu). Nie zmieniać `name` Workera — Workers Builds i sekrety są przypięte do tej nazwy.
- ESLint: `react-compiler/react-compiler` jako `error` (kod React musi być zgodny z React Compiler), `no-console` jako `warn`, `astro/no-set-html-directive` jako `error`. Nieużywane zmienne dozwolone tylko z prefiksem `_`.
- Runtime Cloudflare Workers ogranicza czas i API Node — generowanie fiszek przez LLM (limit < 10 s z PRD) planuj jako streaming lub z raportowaniem postępu, nie jako długie blokujące żądanie.
- `.claude/skills/10x-*` i `.claude/.10x-cli-manifest.json` są zarządzane przez `10x-cli` (kurs 10xDevs) i częściowo gitignorowane — nie edytuj ich ręcznie. `CLAUDE.md` również jest gitignorowany i nadpisywany przez CLI przy instalacji kolejnej lekcji; dlatego reguły projektu żyją w tym pliku (`AGENTS.md`), a `CLAUDE.md` tylko go importuje.
- `CLAUDE.md.scaffold` i `README.md.scaffold` to wersje startera pozostawione przez bootstrapper po konflikcie nazw; właściwy opis uruchomienia startera jest w `@README.md.scaffold`.

## Projekt

**10xCards / al-fiszki** — aplikacja web do generowania fiszek przez AI i nauki metodą spaced repetition. Wymagania: `@context/foundation/prd.md` (PRD po polsku, user stories US-xx, wymagania FR-xxx). Decyzja o stacku i jej uzasadnienie: `@context/foundation/tech-stack.md`. Stack: scaffold startera `10x-astro-starter` (Astro 6 SSR + React 19 + Tailwind 4 + Supabase Auth + Cloudflare Workers). Z logiki domenowej istnieje fundament F-01: tabela `flashcards` z RLS (`supabase/migrations/`) i moduł `src/lib/flashcards.ts`; UI fiszek, generowanie AI i algorytm powtórek jeszcze nie istnieją (roadmapa: `@context/foundation/roadmap.md`).

## Architektura

- `output: "server"` — wszystko renderuje się po stronie serwera na każde żądanie; nie ma statycznego prerenderu.
- **Auth flow**: `src/middleware.ts` na każde żądanie tworzy klienta Supabase SSR (sesja w cookies przez `@supabase/ssr`), wpisuje `Astro.locals.user` (typ w `src/env.d.ts`, `App.Locals`) i przekierowuje na `/auth/signin`, gdy ścieżka zaczyna się od elementu `PROTECTED_ROUTES`. Dopasowanie jest prefiksowe (`startsWith`), więc `/dashboard` chroni też `/dashboard-anything`.
- Formularze auth to komponenty React (`src/components/auth/*`) robiące tylko walidację po stronie klienta; submit idzie natywnym `POST` do `src/pages/api/auth/{signin,signup,signout}.ts`, a endpointy odpowiadają `redirect` z komunikatem w `?error=` odczytywanym przez stronę `.astro`. Nowe endpointy trzymaj w tej konwencji (form POST + redirect), zamiast mieszać z fetch/JSON.
- Stan chroniony: `src/pages/dashboard.astro` czyta `Astro.locals.user` — to wzór dla kolejnych stron wymagających logowania.
- Podział komponentów: komponent trafia do React tylko gdy ma stan, handlery zdarzeń lub efekty i jest montowany z dyrektywą `client:*`; wszystko inne (treść statyczna, layout) to `.astro`. Współdzielone helpery w `src/lib/`. shadcn/ui (styl `new-york`, ikony lucide) w `src/components/ui/`, dodawanie: `npx shadcn@latest add <name>`. Klasy Tailwind łącz przez `cn()` z `@/lib/utils`.
- **Warstwa danych**: `src/db/database.types.ts` to plik **generowany** (`npm run db:types`, ignorowany przez ESLint i Prettier) — nigdy nie edytuj go ręcznie, regeneruj po każdej migracji i commituj. `createClient()` zwraca klienta typowanego `Database`; typ `TypedSupabaseClient` z `@/lib/supabase` przyjmują moduły domenowe w `src/lib/` (np. `src/lib/flashcards.ts`: `listFlashcards`, `insertFlashcard`), które **nie tworzą klienta i nie czytają `astro:env/server`** — wywołujący sprawdza `null`. Walidacja wejścia przez `astro/zod` (Zod 4, bez osobnej zależności); limity w Zod muszą być co najmniej tak surowe jak CHECK-i w bazie. Funkcje zapisu nie przyjmują `user_id` — ustawia go baza (`default auth.uid()`).
- Alias `@/*` → `./src/*`.

## Komendy

```bash
npm run dev        # dev server w runtime Cloudflare workerd (nie zwykły Node)
npm run build      # build produkcyjny (SSR przez @astrojs/cloudflare)
npm run preview
npm run lint       # ESLint z regułami type-checked (strictTypeChecked)
npm run lint:fix
npm run format     # Prettier (plugin astro + tailwindcss, printWidth 120, podwójne cudzysłowy)
npx astro sync     # regeneruje .astro/types.d.ts — uruchom przed lintem na świeżym checkoucie (CI robi to samo)
npx wrangler deploy --dry-run                       # walidacja konfiguracji bez mutacji (po build)
npx wrangler versions upload --preview-alias smoke  # preview URL, produkcja nietknięta
npx wrangler deploy                                 # produkcja — ścieżka awaryjna, normalnie robi to Workers Builds
npm run db:start / db:stop                          # lokalny Supabase (Docker); Studio: http://127.0.0.1:54323
npm run db:reset                                    # czysta baza: migracje + seed.sql
npm run db:test                                     # testy pgTAP z supabase/tests/ (na aktualnym stanie bazy)
npm run db:types                                    # regeneruje src/db/database.types.ts z lokalnej bazy — po każdej migracji
npx supabase migration new <nazwa>                  # nowa migracja (tylko addytywne)
npx supabase db lint --local                        # lint schematu
```

- `npx supabase link --project-ref <ref>` i `npx supabase db push` (migracje na hostowany projekt) wykonuje **człowiek**; agent może tylko czytać: `npx supabase migration list --linked`, `npx supabase gen types --linked`. Link żyje w `supabase/.temp` (gitignorowane) — każdy nowy checkout linkuje ponownie.

- Brak runnera testów JS ani skryptu `test`; jedyne testy to pgTAP (`npm run db:test`, wymaga Dockera). CI ich nie uruchamia — tylko lint + build.
- Pre-commit (husky + lint-staged): `eslint --fix` na `*.{ts,tsx,astro}`, `prettier --write` na `*.{json,css,md}`. Commit odrzuci nienaprawialne błędy lintu.
- Node `22.14.0` (`.nvmrc`). CI (`.github/workflows/ci.yml`) na push/PR do `master`: `npm ci` → `astro sync` → `lint` → `build`.
