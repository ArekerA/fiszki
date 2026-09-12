---
project: al-fiszki
researched_at: 2026-09-12
recommended_platform: Cloudflare Workers
runner_up: Vercel
context_type: mvp
tech_stack:
  language: TypeScript
  framework: Astro 6.3 SSR (@astrojs/cloudflare 13.5, React 19 islands)
  runtime: Cloudflare Workers (workerd, nodejs_compat)
---

## Recommendation

**Deploy on Cloudflare Workers** (Workers + Static Assets, **nie** Cloudflare Pages).

To jedyna platforma z 5/5 Pass w macierzy kryteriów agent-friendly, która przy skali „small" z PRD mieści się w planie Free ($0 przy 10k–100k żądań miesięcznie; wywiad: priorytet „minimalny koszt") i nie wymaga żadnej zmiany w stacku — adapter `@astrojs/cloudflare` 13.5 i `wrangler.jsonc` już są w repo, a `astro dev` działa w workerd. Brak wymagania trwałych połączeń (wywiad Q1 = nie) oznacza, że model serverless nie jest ograniczeniem; streaming odpowiedzi OpenRouter w ramach jednego żądania mieści się w limitach, bo czas oczekiwania na `fetch()` nie liczy się do CPU. Supabase i OpenRouter zostają zewnętrzne (wywiad Q5), więc brak co-lokowanej bazy na Cloudflare nie ma znaczenia. Jedna korekta względem hand-offu z `tech-stack.md`: `deployment_target: cloudflare-pages` jest nieaktualny — adapter 13.x usunął wsparcie dla Pages i poprawną komendą jest `wrangler deploy`.

Użytkownik zaakceptował ryzyka z cross-checku (opcja „proceed — risks noted"); trafiły do rejestru poniżej.

## Platform Comparison

Wagi z wywiadu (2026-09-12): trwałe połączenia — nie (brak twardego filtra); priorytet — minimalny koszt (kara za płatne tiery bazowe); znajomość platform — brak (bez bonusu); zasięg — jeden region (edge nie premiowany); co-lokacja — nie, Supabase + OpenRouter zewnętrznie (zintegrowana baza nie premiowana). Twardy filtr runtime: każda z sześciu platform uruchomi Astro 6 SSR na Node 22 lub workerd, więc nikt nie odpadł przed oceną; różnica to koszt migracji adaptera.

| Platform | CLI-first | Managed/Serverless | Agent-readable docs | Stable deploy API | MCP / Integration | Total |
|---|---|---|---|---|---|---|
| Cloudflare Workers | Pass | Pass | Pass | Pass | Pass (GA) | 5 Pass |
| Vercel | Pass | Pass | Pass | Pass | Partial (beta) | 4 Pass, 1 Partial |
| Render | Partial | Pass | Pass | Pass | Pass (GA) | 4 Pass, 1 Partial |
| Netlify | Partial | Pass | Pass | Partial | Pass (GA) | 3 Pass, 2 Partial |
| Fly.io | Pass | Partial | Pass | Pass | Partial (experimental) | 3 Pass, 2 Partial |
| Railway | Partial | Pass | Pass | Partial | Partial (bez etykiety GA) | 2 Pass, 3 Partial |

Koszt szacowany dla 10k–100k żądań/miesiąc, sam hosting SSR (baza w Supabase):

| Platform | Koszt / mies. | Uwaga |
|---|---|---|
| Cloudflare Workers | $0 (Paid $5 w razie limitu CPU) | Free: 100k req/dzień, 10 ms CPU/req |
| Vercel | $0 Hobby / $20 Pro | Hobby tylko do użytku niekomercyjnego |
| Netlify | $0 w 300 kredytach | twardy limit, strona pauzuje; 15 kredytów za deploy prod |
| Fly.io | ~$0.5–2 | brak free tier, maszyna suspend |
| Railway | ~$5 Hobby | Free: 0.5 GB RAM, 502 po uśpieniu |
| Render | $7 Starter | Free: cold start ~1 min łamie cel < 10 s |

**Cloudflare Workers** — `wrangler deploy`, `wrangler rollback` (100 ostatnich wersji), `wrangler tail`, `wrangler secret put` pokrywają całą pętlę operacyjną. Docs jako `developers.cloudflare.com/llms.txt` i każda strona z `Accept: text/markdown`. MCP Cloudflare API GA z OAuth. Adapter i konfiguracja już w repo.

**Vercel** — CLI kompletne (`vercel --prod`, `vercel rollback`, `vercel logs`, `vercel env`), najlepsze doki dla agentów (`llms-full.txt`, `.md` na każdej stronie), Fluid compute GA. MCP `mcp.vercel.com` nadal Public Beta (sprawdzono 2026-09-12), bez narzędzi do env/rollback. Wymaga `@astrojs/vercel@^10` (nie `@latest`, bo 11.x wymaga Astro 7). Hobby: rollback tylko do poprzedniego deployu, logi 1 h, tylko niekomercyjnie, domyślny region iad1.

**Render** — CLI 2.28 (`deploys create --wait`, `logs --tail`, `-o json`), ale rollback tylko przez REST API lub Dashboard. MCP GA od 08/2025. Frankfurt blisko Supabase eu-central-1. Kara kosztowa: sensowne wdrożenie to $7/mies. (Starter), a Free ma ~1-minutowy cold start. Wymaga `@astrojs/node@10`.

**Netlify** — `netlify deploy --prod`, `netlify env:*`, `netlify logs`; rollback bez komendy CLI (`netlify api restoreSiteDeploy`). Funkcje na Lambdzie: 60 s sync, streaming OK, ale cold starty. MCP GA. Kredyty: 300/mies. z twardym limitem, przy auto-deployu po każdym merge 15 kredytów za deploy może zjeść budżet. Wymaga `@astrojs/netlify@7.x` (8.x wymaga Astro 7).

**Fly.io** — `fly deploy`, `fly releases` + `fly deploy --image` do rollbacku, `fly logs`, `fly secrets set`. Dokumentacja w MDX na GitHub, brak `llms.txt`. Managed tylko częściowo: Dockerfile, VM, health checki, brak regionu waw (ams/fra). `fly mcp` w całości oznaczone experimental. Brak free tier, choć suspend daje ~$1–2/mies.

**Railway** — `railway up`, `railway logs`, `railway variable set`; rollback tylko w dashboardzie, ograniczony retencją obrazów (24–72 h). Docs `llms-full.txt`. MCP w CLI bez etykiety GA. Serverless/sleep: pierwsze żądanie może dostać 502. ~$5/mies. Hobby.

### Shortlisted Platforms

#### 1. Cloudflare Workers (Recommended)

Wygrywa na wszystkich pięciu kryteriach i na koszcie ($0 przy tej skali), a przede wszystkim zerowym koszcie migracji: adapter 13.5, `wrangler.jsonc` z `main` + `assets`, `nodejs_compat` i `observability.enabled` już są. `astro dev` działa w workerd przez `@cloudflare/vite-plugin`, więc pętla lokalna ma fidelity produkcji. Sekrety z `wrangler secret put` czyta `astro:env/server` bez zmian w kodzie. Workers Builds (GitHub, 3000 min/mies. free) dają preview URL per branch i mogą zastąpić deploy w GitHub Actions albo z nim współistnieć.

#### 2. Vercel

Drugie miejsce dzięki równie kompletnemu CLI i najlepszym dokom dla agenta; przegrywa MCP w becie, koniecznością swapu adaptera oraz warunkiem: Hobby jest darmowy tylko niekomercyjnie, a ten projekt może w przyszłości przestać taki być. Jeśli Cloudflare zawiedzie (np. limit CPU okaże się nie do obejścia bez Paid), przejście to `npx astro add vercel@^10`, `vercel.json` z `"regions": ["fra1"]` i przeniesienie sekretów do `vercel env`.

#### 3. Netlify

Trzecie miejsce: w pełni serverless, MCP GA, mieści się w darmowych kredytach przy tym ruchu. Luka wobec lidera to brak rollbacku w CLI, cold starty Lambdy przy stronach SSR i twardy limit kredytowy, który przy `auto-deploy-on-merge` stanowi realne ryzyko wyłączenia strony w trakcie MVP. Render byłby równorzędny jakościowo, ale kara kosztowa ($7 albo cold start ~1 min) przy priorytecie „minimalny koszt" zepchnęła go poza podium.

## Anti-Bias Cross-Check: Cloudflare Workers

### Devil's Advocate — Weaknesses

1. **10 ms CPU na żądanie w planie Free.** Oczekiwanie na `fetch()` do OpenRouter nie liczy się do CPU, ale renderowanie SSR z wyspami React 19, parsowanie strumienia tokenów i walidacja Zod już tak. Ciężka strona przeglądu fiszek może kończyć się błędem 1102 widocznym dopiero w produkcji, bo `astro dev` limitu nie egzekwuje. Plan Paid ($5/mies.) podnosi limit do 30 s.
2. **Hand-off mówi `cloudflare-pages`, a Pages jest w de facto trybie utrzymania.** Adapter 13.x nie wspiera Pages; `wrangler pages deploy` na tym repo się nie uda. Oficjalny przewodnik Cloudflare dla Astro nadal pokazuje `main: ./dist/_worker.js/index.js` z adaptera ≤12 — agent kopiujący z docs zepsuje konfigurację.
3. **Adapter auto-wstrzykuje bindingi `SESSION` (KV) i `IMAGES`** i polega na auto-provisioningu wranglera (beta od 10/2025). Pierwszy deploy utworzy zasoby, których nikt nie zaplanował; rollback nie usuwa bindingów.
4. **Otwarty problem withastro/astro#15434** (`[object Object]` w SSR z middleware + `nodejs_compat`, tylko w preview/prod), zamknięty „not planned" na becie 6.0. Auth w tym projekcie opiera się dokładnie na middleware.
5. **Supabase przez `@supabase/ssr` z izolatu edge**: każde żądanie odpytuje Supabase w `eu-central-1` z węzła, na który trafił użytkownik. Bez Smart Placement lub Hyperdrive opóźnienie może być większe niż z serwera w Frankfurcie.

### Pre-Mortem — How This Could Fail

Zespół wdrożył z `wrangler deploy` w piętnaście minut i uznał temat za zamknięty. Pierwszy zgrzyt przyszedł tydzień później, gdy strona przeglądu fiszek zaczęła losowo zwracać błąd 1102: renderowanie SSR z wyspami React i walidacja odpowiedzi LLM zjadały ponad 10 ms CPU, a nikt nie mierzył tego lokalnie, bo `astro dev` limitu nie egzekwuje. Zamiast przejść na Paid, deweloper zaczął odchudzać strony, tracąc dwa wieczory z trzytygodniowego budżetu. Potem okazało się, że auth w middleware działa w dev, a w produkcji przy pewnych ścieżkach oddaje `[object Object]`. Debugowanie było ślepe: logi w Free trzymają się trzy dni, a preview URL nie mają logów wcale. W międzyczasie agent, ucząc się z oficjalnego przewodnika Astro na developers.cloudflare.com, nadpisał `main` w `wrangler.jsonc` wartością z adaptera 12 i deploy przestał działać. Ostatni cios: nikt nie zauważył, że pierwszy deploy utworzył namespace KV `SESSION`, więc gdy Supabase wymusiło rotację klucza, sekrety obróciły się w Workerze, ale sesje w KV pozostały stare i użytkownicy wylogowywali się losowo. Aplikacja działała, ale zaufanie do stacku wyparowało.

### Unknown Unknowns

- `astro dev` działa już w workerd przez `@cloudflare/vite-plugin`; osobny `wrangler dev` jest legacy. Poradniki, które go zalecają, wprowadzą agenta w błąd. `astro preview` wymaga wcześniejszego `astro build` (czyta `.wrangler/deploy/config.json`).
- `Astro.locals.runtime.env` rzuca wyjątek w adapterze 13; działa tylko `astro:env/server` albo `import { env } from "cloudflare:workers"`. AGENTS.md już to egzekwuje.
- `compatibility_date` 2026-05-08 wymaga jawnej flagi `nodejs_compat`; od 2026-08-04 flaga jest domyślna. Podbicie daty zmieni zachowanie runtime bez zmiany kodu.
- Adapter 14.3.1 już istnieje, repo jest na 13.5.0. Migracja major w środku MVP to koszt, którego hand-off nie przewidział; nie podbijać `@latest` bez czytania changelogu.
- Limit skompresowanego bundla 3/10 MB zniknął 2026-09-04 (teraz 64 MiB na każdym planie); starsze ostrzeżenia są nieaktualne. Za to Workers Logs w Free mają 200k zdarzeń/dzień i 3 dni retencji.
- `wrangler rollback` nie cofa sekretów ani stanu KV; źródła są sprzeczne co do bindingów. Rollback jest blokowany, gdy wersja odwołuje się do usuniętego zasobu.

## Operational Story

- **Preview deploys**: każdy `wrangler versions upload --preview-alias <nazwa>` daje `<prefix>-al-fiszki.<subdomena>.workers.dev` (GA); Workers Builds podpięte do GitHuba tworzą preview URL dla gałęzi nieprodukcyjnych (limit 1 równoległy build, 3000 min/mies. free; status GA nie jest jawnie podany na stronie, sprawdzono 2026-09-12). Preview URL są publiczne i **nie mają logów** — dla stron z danymi użytkownika założyć Cloudflare Access na wzorzec `*-al-fiszki.*.workers.dev`. Fork PR-y nie dostają preview z Builds.
- **Secrets**: `SUPABASE_URL`, `SUPABASE_KEY`, `OPENROUTER_API_KEY` żyją w Workers Secrets (`npx wrangler secret put NAME`), lokalnie w `.dev.vars` (gitignored), w CI jako GitHub repository secrets (`CLOUDFLARE_API_TOKEN` z zakresem tylko Workers Scripts:Edit dla tego konta, bez DNS i billingu). Sekrety czyta tylko kod serwerowy przez `astro:env/server`. Rotacja: `wrangler secret put` nadpisuje w locie bez nowego deployu kodu, ale zmiana klucza Supabase wymaga też unieważnienia sesji (KV `SESSION`, jeśli używane).
- **Rollback**: `npx wrangler rollback [VERSION_ID] -y` — do 100 ostatnich wersji, typowo poniżej minuty. Migracje Supabase nie cofają się automatycznie; przed każdym deployem z migracją sprawdzić, czy poprzednia wersja kodu działa z nowym schematem (migracje addytywne). Sekrety i KV pozostają w stanie „po".
- **Approval**: człowiek: pierwszy `wrangler deploy` na produkcję, `wrangler rollback`, rotacja `SUPABASE_KEY` / `OPENROUTER_API_KEY`, usunięcie Workera lub namespace KV, zmiana planu Free → Paid, wszystko w panelu Supabase (drop tabeli, reset bazy). Agent bez nadzoru: `wrangler versions upload` (preview), `wrangler tail`, `wrangler deployments list`, `wrangler versions list`, `wrangler deploy --dry-run`, deploy przez CI po merge do `master` (bo ten merge sam jest ludzką bramką).
- **Logs**: runtime: `npx wrangler tail --format json --status error` (próbkowane przy dużym ruchu, max 10 klientów) oraz Workers Logs w dashboardzie (Free: 200k zdarzeń/dzień, 3 dni retencji; Paid: 7 dni) — `observability.enabled: true` już w `wrangler.jsonc`. Pipeline: `gh run view <id> --log` dla GitHub Actions; `wrangler builds` dla Workers Builds. Read-only MCP: Cloudflare Observability MCP (OAuth, GA) do zapytań o logi ze stanu na żywo, opcjonalnie później.

## Risk Register

| Risk | Source | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| Limit 10 ms CPU (Free) przekraczany przez SSR + React + parsowanie strumienia LLM → błędy 1102 | Devil's advocate | M | H | Mierzyć `cpuTime` w Workers Logs od pierwszego deployu; strumieniować odpowiedź LLM do przeglądarki zamiast parsować na serwerze; budżet $5/mies. na Paid zaakceptowany z góry |
| Hand-off `deployment_target: cloudflare-pages` i przewodnik Cloudflare (adapter ≤12) prowadzą do złej komendy / złego `main` | Devil's advocate | H | M | Poprawić `tech-stack.md` na `cloudflare-workers`; w AGENTS.md: „deploy = `wrangler deploy`, nigdy `pages deploy`; nie zmieniać `main` w `wrangler.jsonc`" |
| Auto-provisioning KV `SESSION` / `IMAGES` (beta, sprawdzono 2026-09-12) tworzy zasoby poza kontrolą | Devil's advocate | H | L | Po pierwszym `wrangler deploy --dry-run` obejrzeć `.wrangler/deploy/config.json`; jeśli sesje Astro nie są używane, ustawić `session: false` w adapterze |
| astro#15434: middleware + `nodejs_compat` zwraca `[object Object]` tylko w prod | Devil's advocate | L | H | Pierwszy deploy = sam scaffold ze stroną `/dashboard` chronioną middleware; test ręczny na preview URL przed pisaniem domeny |
| Opóźnienie edge → Supabase eu-central-1 przy wielu zapytaniach na żądanie | Devil's advocate | M | M | Włączyć Smart Placement w `wrangler.jsonc` (`placement: { mode: "smart" }`); jedno zapytanie na stronę; Hyperdrive dopiero, gdy pomiary tego wymagają |
| Ślepe debugowanie: 3 dni retencji, brak logów na preview URL | Pre-mortem | M | M | `wrangler tail` w trakcie testów ręcznych; zapisywać błędy 5xx w tabeli Supabase `error_log` z RLS tylko dla właściciela projektu |
| Rotacja sekretów nie unieważnia sesji w KV → losowe wylogowania | Pre-mortem | L | M | Procedura rotacji w AGENTS.md: `secret put` → wyczyszczenie namespace KV lub `session: false` |
| Agent podbija `compatibility_date` lub adapter do 14.x i zmienia runtime bez świadomości | Unknown unknowns | M | M | Pinować `compatibility_date` w `wrangler.jsonc` i `@astrojs/cloudflare` bez `^` do końca MVP; podbicie tylko przez świadomy PR z changelogiem |
| Poradniki zalecają `wrangler dev` / `Astro.locals.runtime.env` (legacy w 13.x) | Unknown unknowns | H | L | Reguła w AGENTS.md już istnieje (tylko `astro:env/server`); dodać „dev = `npm run dev`, nie `wrangler dev`" |
| `wrangler rollback` zablokowany przez usunięty binding lub nie cofa sekretów | Unknown unknowns | L | M | Nie usuwać zasobów KV/bindingów bez sprawdzenia `wrangler versions list`; rollback zawsze przetestować raz na preview przed incydentem |
| Workers Builds: 1 równoległy build, brak preview dla fork PR | Research finding | L | L | Solo dev — akceptowalne; CI w GitHub Actions pozostaje źródłem prawdy dla lint/build |
| Token API w CI z za szerokim zakresem | Research finding | M | H | Token tylko `Workers Scripts:Edit` + `Account Settings:Read` dla jednego konta; bez DNS, bez Workers KV Storage poza projektem, bez billingu |

## Getting Started

Komendy zweryfikowane dla wersji z repo (astro 6.3.1, `@astrojs/cloudflare` 13.5.0, wrangler 4.90.0; sprawdzono 2026-09-12).

1. **Ujednolicić nazwę i hand-off.** W `wrangler.jsonc` zmienić `name` z `10x-astro-starter` na `al-fiszki` (to samo w `supabase/config.toml` `project_id`). W `context/foundation/tech-stack.md` poprawić `deployment_target` na `cloudflare-workers`. Nie zmieniać `main` (`@astrojs/cloudflare/entrypoints/server` jest poprawne dla 13.x).
2. **Zalogować się i zweryfikować konfigurację bez mutacji.**
   ```bash
   npx wrangler login
   npm run build
   npx wrangler deploy --dry-run
   ```
   Obejrzeć `.wrangler/deploy/config.json` — tam widać auto-wstrzyknięte bindingi `SESSION` / `IMAGES`.
3. **Ustawić sekrety w Workers Secrets** (ręcznie, człowiek):
   ```bash
   npx wrangler secret put SUPABASE_URL
   npx wrangler secret put SUPABASE_KEY
   npx wrangler secret put OPENROUTER_API_KEY
   ```
   Lokalnie te same klucze w `.dev.vars` (workerd w `npm run dev`) i `.env` (`astro check`). Nowy klucz OpenRouter dopisać do `env.schema` w `astro.config.mjs` (`context: "server", access: "secret", optional: true`) i do `configStatuses`.
4. **Pierwszy deploy jako preview, potem produkcja** (człowiek zatwierdza drugi krok):
   ```bash
   npx wrangler versions upload --preview-alias smoke
   npx wrangler deploy
   npx wrangler tail --format json --status error
   ```
   Na preview URL przetestować `/auth/signin` → `/dashboard` (middleware) przed deployem produkcyjnym.
5. **Podpiąć CI.** Do `.github/workflows/ci.yml` dodać job `deploy` po `build`, tylko na push do `master`, z `cloudflare/wrangler-action@v3` i sekretami `CLOUDFLARE_API_TOKEN` (zakres: Workers Scripts:Edit) oraz `CLOUDFLARE_ACCOUNT_ID`. Alternatywnie Workers Builds w panelu (preview per branch), zostawiając Actions dla lint/build.

## Out of Scope

The following were not evaluated in this research:
- Docker image configuration
- CI/CD pipeline setup
- Production-scale architecture (multi-region, HA, DR)
