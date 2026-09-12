---
project: al-fiszki
platform: cloudflare-workers
plan_approved_at: 2026-09-12
status: deployed
last_workers_builds_version: 404881a3-0661-4aea-86db-5f14482b948e
commits: [debbab2, cc146be]
production_url: https://al-fiszki.arek-ludwikowski.workers.dev
first_version_id: 27b3c82d-483f-4520-8345-8559cd912d95
auto_provisioned_bindings: [SESSION (KV 18c09c8fa4b543c1bf4604179cc365bb), IMAGES (Images), ASSETS (Static Assets)]
---

> Artefakt Plan Mode (Lekcja 5). Źródło decyzji platformowej: `context/foundation/infrastructure.md`. Checkboxy odzwierciedlają rzeczywisty postęp wdrożenia; sekcja **Dziennik wykonania** na końcu zawiera wyniki.

# Plan pierwszego wdrożenia al-fiszki na Cloudflare Workers

## Context

`context/foundation/infrastructure.md` (2026-09-12) rekomenduje **Cloudflare Workers + Static Assets** (nie Pages) dla stacku z `tech-stack.md`: Astro 6.3 SSR + `@astrojs/cloudflare` 13.5 + React 19 + Supabase Auth. Repo to nietknięty scaffold `10x-astro-starter`; adapter, `wrangler.jsonc` (`main`, `assets`, `nodejs_compat`, `observability`) już są. Celem jest pierwszy deploy produkcyjny scaffoldu z działającym auth, z auto-deployem `master` obsługiwanym przez **Cloudflare Workers Builds** (decyzja użytkownika), a nie przez GitHub Actions. Artefakt planu ląduje w `context/deployment/deploy-plan.md`.

Stan wyjściowy (sprawdzony):

- `npx wrangler whoami`: zalogowany OAuth, konto `2ba85b88ded42cae0089371713fe568c`; wrangler 4.90.0 lokalnie.
- Brak `.env` i `.dev.vars`; brak `gh` CLI; remote `origin` = `github.com/ArekerA/fiszki`, gałąź `master`.
- `wrangler.jsonc.name` i `supabase/config.toml.project_id` = `10x-astro-starter` (do ujednolicenia na `al-fiszki`).
- `tech-stack.md` ma nieaktualny `deployment_target: cloudflare-pages`.
- Adapter 13.5 auto-provisionuje KV `SESSION` (opcja `sessionKVBindingName`, brak przełącznika „off") — trzeba to obejrzeć w dry-runie, nie zaskoczyć się.
- Middleware chroni prefiks `/dashboard` (`src/middleware.ts:4`).

Decyzje użytkownika: Workers Builds jako auto-deploy; klucze Supabase są dostępne; `OPENROUTER_API_KEY` **poza zakresem** (dopiero z kodem generowania); plan zapisany w `context/deployment/deploy-plan.md`.

## Podział odpowiedzialności

- **Agent (ja)**: edycje plików w repo, `npm run build`, `wrangler deploy --dry-run`, `wrangler versions upload` (preview), `wrangler tail`, `wrangler deployments/versions list`, commit + push do `master`, zapis `deploy-plan.md`.
- **Człowiek (bramki ręczne)**: wpisanie sekretów (`.dev.vars`, `.env`, `wrangler secret put` — nigdy przez agenta), konfiguracja Supabase Auth URL, jawne „tak" w czacie przed pierwszym `wrangler deploy` na produkcję, podpięcie repo w panelu Cloudflare (Workers Builds, autoryzacja GitHub App), ewentualna rejestracja subdomeny `workers.dev`.

---

## Faza 0 — Prerequisites: CLI i konta

- [x] **wrangler — podbicie 4.90.0 → 4.131.1 (decyzja użytkownika: podbijamy teraz).** Ocena ryzyka: niskie.
  - Ten sam major (4.x) — Cloudflare trzyma semver, breaking changes tylko w majorach; 4.90 → 4.131 to ~40 minorów bugfixów i nowych komend.
  - Peer-dependencies są spełnione: `@astrojs/cloudflare` 13.5.0 wymaga `wrangler ^4.83.0`, `@cloudflare/vite-plugin` 1.36.3 wymaga `^4.90.0`; 4.131.1 mieści się w obu. `engines: node >=22` — mamy 22.14.
  - Jedyny nowy peer to `@cloudflare/workers-types ^5.20260911.1` (opcjonalny; brak w projekcie daje co najwyżej ostrzeżenie `npm`, nie błąd — typy runtime dostarcza adapter).
  - Realne ryzyko to zmiana zachowania auto-provisioningu / komunikatów `deploy`, nie kodu aplikacji — stąd podbicie robimy **przed** Fazą 2, żeby `--dry-run` i preview zweryfikowały nową wersję, a nie starą.
  - Kroki: `npm install -D wrangler@4.131.1` (aktualizuje `package.json` + `package-lock.json`), `npx wrangler --version` → `4.131.1`, `npx wrangler whoami` (sesja OAuth przeżywa update). Jeśli `npm run build` lub `dry-run` zgłosi regresję, cofamy jednym `npm install -D wrangler@4.90.0` i zapisujemy to w `deploy-plan.md` jako pominięte z powodem.
  - Nie instalować wranglera globalnie — zawsze `npx wrangler` z repo, żeby lokalnie, w Workers Builds i w CI działała ta sama wersja z locka.
- [x] **Login**: `npx wrangler whoami` — już zalogowany (OAuth, scopes `account:read`, `user:read`). Jeśli deploy zgłosi brak uprawnień do Workers Scripts, `npx wrangler logout && npx wrangler login` (człowiek, otwiera przeglądarkę).
- [x] **Subdomena workers.dev** — każde konto ma jedną subdomenę `<nazwa>.workers.dev`; każdy Worker dostaje pod nią adres `al-fiszki.<nazwa>.workers.dev`, a preview `smoke-al-fiszki.<nazwa>.workers.dev`. Bez zarejestrowanej subdomeny deploy się uda, ale Worker nie będzie miał publicznego URL. Tutorial:
  1. **Sprawdzenie, czy już istnieje**: zaloguj się na https://dash.cloudflare.com → w lewym menu _Workers & Pages_ → zakładka _Overview_. W prawej kolumnie (sekcja _Account details_) jest pole **Your subdomain**. Jeśli widzisz `xxx.workers.dev` — gotowe, nic nie rób; zanotuj nazwę, bo używamy jej w URL-ach niżej.
  2. **Rejestracja w panelu (zalecana, 30 s)**: w tym samym miejscu kliknij _Change_ / _Set up a subdomain_ → wpisz nazwę (małe litery, cyfry, myślniki; np. `arek-fiszki` — nazwa jest publiczna i widoczna w URL, nie wpisuj maila) → _Save_. Jeśli nazwa jest zajęta, panel od razu to zgłosi. Zmiana subdomeny później jest możliwa, ale unieważnia wszystkie stare URL-e Workerów, więc wybierz raz.
  3. **Alternatywa z terminala**: jeśli subdomeny nie ma, pierwszy `npx wrangler deploy` (Faza 5) sam zapyta „Would you like to register a workers.dev subdomain now?" → `y`, potem nazwa. Prompt jest interaktywny, więc ta ścieżka działa tylko w Twoim terminalu, nie z sesji agenta ani z Workers Builds — dlatego wolimy krok 2 przed Fazą 4.
  4. **Włączenie ruchu na URL**: po pierwszym deployu w panelu Worker `al-fiszki` → _Settings_ → _Domains & Routes_ upewnij się, że wpis `workers.dev` ma status _Enabled_ (domyślnie tak; `preview_urls` też domyślnie włączone — potrzebne dla `versions upload --preview-alias`).
  5. **Weryfikacja**: `npx wrangler deploy --dry-run` nie pokaże URL; dopiero prawdziwy `deploy` wypisuje `https://al-fiszki.<nazwa>.workers.dev`. Jeśli wypisze tylko `Deployed al-fiszki` bez URL — subdomena nie jest zarejestrowana, wróć do kroku 2.
  6. Własna domena (np. `fiszki.example.pl`) jest poza zakresem MVP; dopisać do `deploy-plan.md` jako follow-up (_Domains & Routes_ → _Add_ → _Custom domain_, wymaga strefy DNS na tym koncie).
- [x] **Supabase**: projekt istnieje; potrzebne `Project URL` i `anon public key` (Settings → API). Do smoke-testu auth: Authentication → URL Configuration → _Site URL_ + _Redirect URLs_ muszą zawierać `https://al-fiszki.<subdomena>.workers.dev` (bez tego link potwierdzający z maila trafi na `localhost`). Jeśli e-mail confirmation jest włączone, test signup wymaga skrzynki; alternatywnie wyłączyć „Confirm email" na czas MVP.
- [ ] **GitHub**: repo `ArekerA/fiszki` publiczne lub z dostępem dla Cloudflare GitHub App (instalacja w kroku Fazy 6). `gh` CLI nie jest potrzebne.
- [x] **Node**: `22.14.0` wg `.nvmrc`; Workers Builds czyta `.nvmrc`, więc wersja buildu w chmurze będzie zgodna.

## Faza 1 — Ujednolicenie nazw i hand-offu (edycje w repo)

- [x] `wrangler.jsonc`: `"name": "al-fiszki"`. **Nie zmieniać `main`** (`@astrojs/cloudflare/entrypoints/server` jest poprawne dla 13.x). Dodać `"placement": { "mode": "smart" }` (mitygacja opóźnienia edge → Supabase eu-central-1 z rejestru ryzyk; działa na planie Free).
- [x] `supabase/config.toml`: `project_id = "al-fiszki"`.
- [x] `context/foundation/tech-stack.md`: `deployment_target: cloudflare-workers`, `ci_default_flow` pozostaje `auto-deploy-on-merge` (realizowany przez Workers Builds). Dopisać jedno zdanie w `## Why this stack`: Pages → Workers, bo adapter 13.x nie wspiera Pages.
- [x] `AGENTS.md`: sekcja „Środowisko i sekrety / Deploy" + „Pułapki": usunąć uwagę o niespójnej nazwie (po zmianie), dodać reguły z rejestru ryzyk:
  - deploy = `npx wrangler deploy`, nigdy `wrangler pages deploy`; nie zmieniać `main` w `wrangler.jsonc`;
  - dev = `npm run dev` (workerd przez vite-plugin), nie `wrangler dev`;
  - `compatibility_date` i `@astrojs/cloudflare` pinowane — podbicie tylko świadomym PR-em z changelogiem;
  - auto-deploy `master` robi Workers Builds (nie Actions); rollback `npx wrangler rollback`; sekrety nie cofają się z rollbackiem;
  - procedura rotacji `SUPABASE_KEY`: `secret put` → sprawdzić, czy namespace KV `SESSION` jest używany (patrz Faza 2), jeśli tak — wyczyścić.
- [x] `.github/workflows/ci.yml`: bez zmian (lint + build zostaje źródłem prawdy jakości; deploy przejmuje Workers Builds). Opcjonalnie dopisać komentarz, że deploy jest poza Actions.

## Faza 2 — Weryfikacja bez mutacji

- [x] `npm run build` — musi przejść bez `.env` (zmienne opcjonalne).
- [x] `npx wrangler deploy --dry-run` — potwierdza poprawność `wrangler.jsonc`, nazwę `al-fiszki`, bundluje Workera.
- [x] Obejrzeć `.wrangler/deploy/config.json`: spisać auto-wstrzyknięte bindingi (`SESSION` KV, ewentualnie `IMAGES`). Scaffold nie używa `Astro.session` (sesja auth jest w cookies Supabase), więc KV będzie pusty — akceptujemy provisioning, ale odnotowujemy w `deploy-plan.md` i AGENTS.md, że namespace istnieje i nie jest źródłem prawdy dla sesji.
- [x] Sprawdzić rozmiar bundla i ostrzeżenia wranglera (limit 64 MiB, ale ostrzeżenia o `nodejs_compat` / niekompatybilnych modułach mają zostać puste).

## Faza 3 — Sekrety (człowiek)

- [x] Lokalnie: utworzyć `.dev.vars` (workerd, `npm run dev`) i `.env` (`astro check`) z `SUPABASE_URL`, `SUPABASE_KEY` wg `.env.example`. Oba gitignorowane. Agent nie wpisuje wartości.
- [x] Produkcja, w terminalu użytkownika (wrangler pyta o wartość na stdin):
  ```bash
  npx wrangler secret put SUPABASE_URL
  ```
  ```bash
  npx wrangler secret put SUPABASE_KEY
  ```
  Uwaga: przy pierwszym `secret put`, gdy Worker `al-fiszki` jeszcze nie istnieje, wrangler zapyta, czy utworzyć nowego Workera — odpowiedzieć „tak" (tworzy pusty skrypt-placeholder; nadpisze go deploy). Alternatywnie wykonać Fazę 3 po Fazie 5 (pierwszym deployu) — wtedy smoke-test auth robimy dopiero na produkcji. Preferowana kolejność: sekrety **przed** preview, żeby preview testował pełny flow.
- [x] `npx wrangler secret list` (agent, read-only) — potwierdza obecność obu nazw bez wartości.

## Faza 4 — Preview i smoke-test

- [x] `npx wrangler versions upload --preview-alias smoke` → URL `smoke-al-fiszki.<subdomena>.workers.dev` (preview nie zmienia produkcji; nie ma logów — testujemy przy `wrangler tail` z produkcji dopiero po Fazie 5).
- [x] Testy na preview (agent przez przeglądarkę / curl, człowiek dla logowania):
  - `GET /` → 200, brak banera „Supabase nie jest skonfigurowany" (sekrety czytane przez `astro:env/server`);
  - `GET /dashboard` niezalogowany → 302 na `/auth/signin` (middleware działa w workerd; brak `[object Object]` — astro#15434);
  - signup / signin → `/dashboard` z `Astro.locals.user` (człowiek, z prawdziwym kontem testowym);
  - `POST /api/auth/signout` → redirect i utrata sesji.
- [ ] Edge case: jeśli signin działa w dev, a na preview zwraca 500 / `[object Object]` — to astro#15434; plan awaryjny: sprawdzić, czy błąd znika po usunięciu `nodejs_compat` (nie wolno — `@supabase/ssr` go potrzebuje), więc realny fallback to podbicie Astro do wersji z fixem lub zgłoszenie repro; nie deployować produkcji z uszkodzonym auth.
- [ ] Edge case: błąd 1102 (CPU 10 ms) na preview → rozważyć Paid $5 (decyzja człowieka, zaakceptowana w infrastructure.md).

## Faza 5 — Pierwszy deploy produkcyjny (jawna zgoda człowieka w czacie)

- [x] Po „tak" od użytkownika: `npx wrangler deploy` → `https://al-fiszki.<subdomena>.workers.dev`.
- [x] Równolegle `npx wrangler tail --format json --status error` podczas powtórzenia smoke-testu z Fazy 4 na URL produkcyjnym; zapisać `cpuTime` z Workers Logs dla `/` i `/dashboard` jako baseline (rejestr ryzyk: monitorować od pierwszego deployu).
- [x] `npx wrangler deployments list` i `npx wrangler versions list` — zanotować `VERSION_ID` pierwszej wersji do `deploy-plan.md` (cel rollbacku).
- [x] Test rollbacku „na sucho": `npx wrangler rollback --help` i potwierdzenie, że wersja jest na liście (rejestr: przetestować raz przed incydentem; faktyczny rollback dopiero gdy będą ≥2 wersje).
- [ ] Zaktualizować Supabase Auth _Site URL_/_Redirect URLs_ o URL produkcyjny (człowiek, jeśli nie zrobione w Fazie 0).

## Faza 6 — Workers Builds: auto-deploy z `master` przez Cloudflare

- [x] Najpierw commit + push zmian z Fazy 1 do `master` (nazwa `al-fiszki` w `wrangler.jsonc` musi być w repo, bo Builds deployuje z gita; push uruchomi tylko istniejące CI lint/build — Builds jeszcze nie podpięte). Commit message po polsku, z atrybucją `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- [x] Panel Cloudflare (człowiek): Workers & Pages → `al-fiszki` → Settings → **Build** → _Connect_ → GitHub → autoryzacja Cloudflare GitHub App dla `ArekerA/fiszki` → ustawienia:
  - Production branch: `master`
  - Build command: `npm run build`
  - Deploy command: `npx wrangler deploy`
  - Root directory: `/`
  - Build variables: brak wymaganych (`SUPABASE_*` są runtime secrets, nie build-time; build przechodzi bez nich). `NODE_VERSION` niepotrzebne — `.nvmrc`.
  - Non-production branches: build + preview URL włączone (domyślnie).
- [x] Trigger testowy: pusty commit lub drobna zmiana (np. dopisek w `AGENTS.md`) → push `master` → w panelu _Deployments_ status „Success"; `npx wrangler deployments list` pokazuje nową wersję ze źródłem „Workers Builds"; `npx wrangler builds list` / `builds view` do logów (jeśli komenda dostępna w 4.90.0 — inaczej panel).
- [ ] Edge case: pierwszy build w Builds kończy się „Worker name mismatch" → oznacza, że push z nowym `name` nie dotarł; sprawdzić `git log origin/master`.
- [ ] Edge case: Builds ma 1 równoległy build i 3000 min/mies. (Free) — solo dev OK; fork PR bez preview (akceptowane).
- [x] Zapisać w `AGENTS.md`, że ręczny `wrangler deploy` jest dopuszczalny jako awaryjny, ale domyślna ścieżka to merge do `master`.

## Faza 7 — Bezpieczeństwo dostępu i higiena

- [x] Preview URL (`*-al-fiszki.*.workers.dev`) są publiczne i bez logów: dopóki scaffold nie ma danych użytkowników, akceptujemy; odnotować w `deploy-plan.md`, że przed pierwszą tabelą domenową należy założyć Cloudflare Access na wzorzec preview (rejestr).
- [x] Nie tworzymy API tokena (Workers Builds używa własnego tokena zarządzanego przez Cloudflare; GitHub Actions nie deployuje) — brak sekretu `CLOUDFLARE_API_TOKEN` w repo to celowe. Jeśli w przyszłości Actions ma deployować: token tylko `Workers Scripts:Edit` + `Account Settings:Read`.
- [x] Destrukcyjne operacje (usunięcie Workera, KV, zmiana planu, rotacja klucza Supabase) — wyłącznie człowiek w panelu.

## Faza 8 — Artefakt planu

- [x] Zapisać ten plan (z aktualnymi statusami checkboxów, URL produkcyjnym, `VERSION_ID`, listą auto-provisionowanych bindingów, baseline `cpuTime`) do `context/deployment/deploy-plan.md` (utworzyć katalog `context/deployment/`). Nie pisać do `context/archive/`.
- [x] Dołączyć `deploy-plan.md`, `infrastructure.md` i zmiany z Fazy 1 do drugiego commitu (`m1l5`) i push.

---

## Krytyczne pliki

- `package.json` / `package-lock.json` — `wrangler` → `4.131.1` (Faza 0).
- `wrangler.jsonc` — `name`, `placement`; `main` nietykalny.
- `supabase/config.toml:5` — `project_id`.
- `context/foundation/tech-stack.md:8` — `deployment_target`.
- `AGENTS.md` — reguły deploy/dev/rotacji, usunięcie pułapki o nazwach.
- `context/deployment/deploy-plan.md` — nowy artefakt.
- Bez zmian: `astro.config.mjs` (schemat env wystarcza), `.github/workflows/ci.yml`, `src/**`.

## Weryfikacja end-to-end

1. `npm run build` i `npx wrangler deploy --dry-run` bez błędów; `.wrangler/deploy/config.json` z `name: al-fiszki`.
2. Preview `smoke-al-fiszki.*.workers.dev`: `/` 200 bez banera, `/dashboard` → 302 `/auth/signin`, pełny signin → `/dashboard`, signout.
3. Produkcja `al-fiszki.*.workers.dev`: to samo, przy `wrangler tail --status error` bez wpisów; `wrangler deployments list` pokazuje wersję.
4. Push do `master` → Workers Builds „Success" → nowa wersja w `wrangler versions list`; GitHub Actions CI zielone niezależnie.
5. `context/deployment/deploy-plan.md` istnieje, wszystkie checkboxy odhaczone lub jawnie oznaczone jako pominięte z powodem.

---

## Dziennik wykonania

- **2026-09-12 — Faza 0**: `wrangler` 4.90.0 → 4.131.1 (`npm install -D wrangler@4.131.1`); `npx wrangler --version` = 4.131.1; sesja OAuth zachowana (`whoami` OK, konto `2ba85b88ded42cae0089371713fe568c`). Brak regresji w build/dry-run. Uwaga: komenda `wrangler builds` nie istnieje w 4.131.1 — logi Workers Builds tylko w panelu.
- **2026-09-12 — Faza 1**: `wrangler.jsonc` → `name: al-fiszki`, dodano `placement.mode: smart`; `supabase/config.toml` → `project_id = "al-fiszki"`; `tech-stack.md` → `deployment_target: cloudflare-workers` + korekta zdania o Pages; `AGENTS.md` → nowa sekcja „Deploy (Cloudflare Workers, nie Pages)", rotacja sekretów, usunięta pułapka o nazwach.
- **2026-09-12 — Faza 2**: `npm run build` OK (19.6 s; ostrzeżenie sitemap o braku `site` — nieistotne). `npx wrangler deploy --dry-run` OK: 21 modułów, 1910 KiB / 391 KiB gzip; bindingi `env.SESSION` (KV), `env.IMAGES` (Images), `env.ASSETS`. Wygenerowany `dist/server/wrangler.json` potwierdza `name: al-fiszki`, `placement.mode: smart`, `kv_namespaces: [{binding: SESSION}]`, `images: {binding: IMAGES}` (bez `id` — auto-provisioning przy deployu). `npx wrangler secret list` → Worker jeszcze nie istnieje (oczekiwane).
- **2026-09-12 — Faza 3**: człowiek utworzył `.dev.vars`/`.env` i wgrał `SUPABASE_URL`, `SUPABASE_KEY` przez `wrangler secret put` (Worker `al-fiszki` utworzony jako placeholder). `wrangler secret list` potwierdza obie nazwy. Subdomena: `arek-ludwikowski.workers.dev`.
- **2026-09-12 — Faza 4 (preview `smoke`)**: `versions upload` auto-utworzył KV `SESSION` (id `18c09c8fa4b543c1bf4604179cc365bb`). Pierwsze żądania → `error code: 1042`: trasa `workers.dev` była wyłączona (placeholder z `secret put` nie ma triggerów). Naprawa: `npx wrangler triggers deploy` (włącza workers.dev + preview URL, nie wysyła kodu). Potem preview zwracał puste 500 na każdej ścieżce (także 404); produkcja 1101 (placeholder bez kodu — oczekiwane).
- **Diagnoza**: preview URL nie mają logów, więc (a) `wrangler dev --remote -c dist/server/wrangler.json` — wymagało usunięcia `legacy_env` z konfiguracji i podania `id` KV; (b) tymczasowy try/catch w middleware + `500.astro` wgrane jako alias `diag`. Oba pokazały: `Error: Invalid supabaseUrl: Must be a valid HTTP or HTTPS URL` w `createServerClient` (middleware, każde żądanie). Lokalny `.dev.vars` ma poprawny `https://<ref>.supabase.co`, więc **wadliwa jest wartość sekretu `SUPABASE_URL` w Workers Secrets** (prawdopodobnie znak/cudzysłów/białe znaki z interaktywnego `secret put`). Kod diagnostyczny cofnięty przed dalszymi krokami.
- **Pułapka procesowa**: `astro build` padał cicho na `EPERM dist/client`, bo w tle działał `astro preview` / `wrangler dev` (workerd trzyma `dist`). Dwa uploady preview poszły ze starym bundlem. Reguła: przed `build` zatrzymać wszystkie procesy serwujące `dist`; po buildzie sprawdzać `Complete!`.
- ~~Otwarte~~ (rozwiązane niżej): człowiek ponownie ustawia `SUPABASE_URL` (zalecane `npx wrangler secret bulk .dev.vars` — bierze dokładnie wartości działające lokalnie); potem powtórka smoke-testu na `smoke-al-fiszki.arek-ludwikowski.workers.dev`.
- **2026-09-12 — Faza 3 bis / Faza 4 OK**: człowiek nadpisał sekrety (`wrangler secret bulk .dev.vars`) → powstały wersje `f5d1982f`, `5b59c969`. **Lekcja: sekrety są per wersja** — alias `smoke` wskazywał starą wersję `be456c34` z wadliwym sekretem i dalej zwracał 500; wersja `5b59c969` (utworzona przez zmianę sekretu) działała od razu. Po zmianie sekretu trzeba ponownie zrobić `versions upload`, żeby alias preview dostał nowe wartości (produkcja po `wrangler deploy` dostaje je automatycznie, bo deploy tworzy nową wersję). Nowy alias `smoke` = wersja `69f94c69`. Smoke-test: `/` 200 bez banera Supabase, `/dashboard` → 302 `/auth/signin`, `/auth/signin` 200. Brak objawów astro#15434.
- **2026-09-12 — Faza 5 (produkcja)**: użytkownik potwierdził „tak, deploy". `npm run build` → `npx wrangler deploy` (11.8 s upload, startup 21 ms). URL: `https://al-fiszki.arek-ludwikowski.workers.dev`, **Version ID `27b3c82d-483f-4520-8345-8559cd912d95`** (cel rollbacku; poprzednia aktywna to placeholder `5b59c969` — nie cofać do niej). Smoke-test produkcji: `/` 200 bez banera, `/dashboard` → 302 `/auth/signin`, `/auth/signin` i `/auth/signup` 200, `/nie-istnieje` 404; czasy 0.1–0.2 s. `wrangler rollback [version-id] -y` dostępny (sprawdzono `--help`). Zmiany triggerów (workers.dev, preview URL) wdrożone razem z deployem.
- **2026-09-12 — Baseline `cpuTime` (Workers Logs przez `wrangler tail`, 4 rundy)**: `/` 2–5 ms, `/dashboard` (redirect z middleware, `getUser()` do Supabase) 1 ms, `/auth/signin` **6–30 ms** (SSR wyspy React `SignInForm`; pierwsze trafienia w izolat ~25–30 ms, rozgrzane 6 ms). Wszystkie `outcome: ok` mimo limitu 10 ms w planie Free — Cloudflare toleruje przekroczenia przy zimnym starcie, ale strony z większymi wyspami React (przegląd fiszek, generowanie) mogą trafić w 1102. Wniosek dla rejestru ryzyk: mierzyć `cpuTime` po każdej nowej stronie z `client:*`; budżet $5/mies. na Paid pozostaje w gotowości.
- **2026-09-12 — Faza 6, krok 1**: commit `debbab2` („m1l5: pierwsze wdrożenie na Cloudflare Workers") wypchnięty na `origin/master` → uruchomił tylko CI lint/build w GitHub Actions. Uwaga: w kopii roboczej `.env.example` był skasowany (nie przeze mnie, prawdopodobnie `mv` na `.env`) — przywrócony z gita, nietrafił do commita jako usunięcie.
- **2026-09-12 — Faza 6, krok 2**: użytkownik podpiął repo `ArekerA/fiszki` do Workera `al-fiszki` w panelu (Settings → Builds → Connect; gałąź `master`, build `npm run build`, deploy `npx wrangler deploy`, token API generowany przez Cloudflare). Samo podpięcie nie utworzyło buildu — ten commit (aktualizacja `deploy-plan.md`) jest triggerem testowym.
- **2026-09-12 — Faza 6 OK**: push `cc146be` → Workers Builds zbudował i wdrożył wersję **`404881a3`** po ~60 s (bez udziału agenta; źródło w `deployments list` = deployment z buildu). Produkcja po auto-deployu: `/` 200, `/dashboard` → 302, `/auth/signin` 200, `/nie-istnieje` 404. GitHub Actions CI dla `cc146be`: success (lint + build, bez deployu). Auto-deploy `master` jest w rękach Cloudflare, zgodnie z decyzją użytkownika.
- **Faza 7**: brak tokena API w repo/CI (celowo); preview URL publiczne, bez danych użytkowników na dziś — Cloudflare Access na `*-al-fiszki.*.workers.dev` do założenia przed pierwszą tabelą domenową. Destrukcyjne operacje pozostają ręczne.
- **Pominięte świadomie**: `OPENROUTER_API_KEY` (dopiero z kodem generowania), własna domena, GitHub Actions jako deployer, testy rollbacku na żywo (dwie wersje produkcyjne są już dostępne: `27b3c82d`, `404881a3` — `npx wrangler rollback 27b3c82d -y` to procedura awaryjna). Ręczny test logowania na preview wykonał użytkownik przed „tak, deploy".

## Follow-upy (poza zakresem pierwszego wdrożenia)

- Cloudflare Access na wzorzec preview URL przed pierwszą migracją Supabase z danymi użytkowników.
- Mierzyć `cpuTime` każdej nowej strony z wyspą React; próg alarmowy: rozgrzane > 10 ms → rozważyć Paid ($5/mies.).
- `OPENROUTER_API_KEY`: `envField` w `astro.config.mjs`, wpis w `configStatuses`, `wrangler secret put`, potem `versions upload`, by preview dostał sekret.
- Własna domena (Settings → Domains & Routes → Custom domain) i `site` w `astro.config.mjs` (usuwa ostrzeżenie sitemap).
- Ten plik jest ground truth „co jest wdrożone" dla planowania kolejnych kamieni milowych.
