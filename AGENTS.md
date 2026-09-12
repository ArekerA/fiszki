# Repository Guidelines

## Środowisko i sekrety

- Dwa pliki na te same zmienne: `.env` czyta Node/Astro (np. `astro check`), `.dev.vars` czyta workerd przy `npm run dev`. Oba gitignorowane; wzór w `.env.example`.
- `SUPABASE_URL` i `SUPABASE_KEY` są zadeklarowane w `astro.config.mjs` jako `context: "server", access: "secret", optional: true`. Importuj je **wyłącznie** z `astro:env/server` i wyłącznie w kodzie serwerowym (middleware, `src/pages/api/**`, frontmatter `.astro`, `src/lib/**`). Import w komponencie React zbuduje się błędnie lub wycieknie sekret.
- Ponieważ zmienne są opcjonalne, aplikacja **musi działać bez Supabase**: `createClient()` z `@/lib/supabase` zwraca `null`, a `Layout.astro` pokazuje baner z `missingConfigs` (`src/lib/config-status.ts`). Każde nowe użycie klienta ma sprawdzać `null`; nową zewnętrzną integrację (np. dostawcę LLM) dopisz do `configStatuses`, żeby brak klucza był widoczny w UI zamiast wysypywać stronę.
- Deploy: sekrety przez `npx wrangler secret put`, w CI jako repository secrets.

## Pułapki

- `supabase/` zawiera tylko `config.toml` — żadnych migracji ani `seed.sql` (choć `config.toml` na niego wskazuje). Lokalny stack: `npx supabase start` (Docker). Pierwsza tabela domenowa (fiszki) będzie pierwszą migracją w `supabase/migrations/` i musi mieć RLS per użytkownik (PRD: izolacja danych).
- Nazwy w `wrangler.jsonc` (`name`) i `supabase/config.toml` (`project_id`) to wciąż `10x-astro-starter`, a nazwa projektu w hand-offie to `al-fiszki` — ujednolić przed pierwszym deployem.
- ESLint: `react-compiler/react-compiler` jako `error` (kod React musi być zgodny z React Compiler), `no-console` jako `warn`, `astro/no-set-html-directive` jako `error`. Nieużywane zmienne dozwolone tylko z prefiksem `_`.
- Runtime Cloudflare Workers ogranicza czas i API Node — generowanie fiszek przez LLM (limit < 10 s z PRD) planuj jako streaming lub z raportowaniem postępu, nie jako długie blokujące żądanie.
- `.claude/skills/10x-*` i `.claude/.10x-cli-manifest.json` są zarządzane przez `10x-cli` (kurs 10xDevs) i częściowo gitignorowane — nie edytuj ich ręcznie. `CLAUDE.md` również jest gitignorowany i nadpisywany przez CLI przy instalacji kolejnej lekcji; dlatego reguły projektu żyją w tym pliku (`AGENTS.md`), a `CLAUDE.md` tylko go importuje.
- `CLAUDE.md.scaffold` i `README.md.scaffold` to wersje startera pozostawione przez bootstrapper po konflikcie nazw; właściwy opis uruchomienia startera jest w `@README.md.scaffold`.

## Projekt

**10xCards / al-fiszki** — aplikacja web do generowania fiszek przez AI i nauki metodą spaced repetition. Wymagania: `@context/foundation/prd.md` (PRD po polsku, user stories US-xx, wymagania FR-xxx). Decyzja o stacku i jej uzasadnienie: `@context/foundation/tech-stack.md`. Kod to na dziś nietknięty scaffold startera `10x-astro-starter` (Astro 6 SSR + React 19 + Tailwind 4 + Supabase Auth + Cloudflare Workers); logika domenowa (fiszki, generowanie AI, algorytm powtórek) jeszcze nie istnieje.

## Architektura

- `output: "server"` — wszystko renderuje się po stronie serwera na każde żądanie; nie ma statycznego prerenderu.
- **Auth flow**: `src/middleware.ts` na każde żądanie tworzy klienta Supabase SSR (sesja w cookies przez `@supabase/ssr`), wpisuje `Astro.locals.user` (typ w `src/env.d.ts`, `App.Locals`) i przekierowuje na `/auth/signin`, gdy ścieżka zaczyna się od elementu `PROTECTED_ROUTES`. Dopasowanie jest prefiksowe (`startsWith`), więc `/dashboard` chroni też `/dashboard-anything`.
- Formularze auth to komponenty React (`src/components/auth/*`) robiące tylko walidację po stronie klienta; submit idzie natywnym `POST` do `src/pages/api/auth/{signin,signup,signout}.ts`, a endpointy odpowiadają `redirect` z komunikatem w `?error=` odczytywanym przez stronę `.astro`. Nowe endpointy trzymaj w tej konwencji (form POST + redirect), zamiast mieszać z fetch/JSON.
- Stan chroniony: `src/pages/dashboard.astro` czyta `Astro.locals.user` — to wzór dla kolejnych stron wymagających logowania.
- Podział komponentów: komponent trafia do React tylko gdy ma stan, handlery zdarzeń lub efekty i jest montowany z dyrektywą `client:*`; wszystko inne (treść statyczna, layout) to `.astro`. Współdzielone helpery w `src/lib/`. shadcn/ui (styl `new-york`, ikony lucide) w `src/components/ui/`, dodawanie: `npx shadcn@latest add <name>`. Klasy Tailwind łącz przez `cn()` z `@/lib/utils`.
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
npx wrangler deploy
```

- Brak skonfigurowanego test runnera — w repo nie ma testów ani skryptu `test`.
- Pre-commit (husky + lint-staged): `eslint --fix` na `*.{ts,tsx,astro}`, `prettier --write` na `*.{json,css,md}`. Commit odrzuci nienaprawialne błędy lintu.
- Node `22.14.0` (`.nvmrc`). CI (`.github/workflows/ci.yml`) na push/PR do `master`: `npm ci` → `astro sync` → `lint` → `build`.
