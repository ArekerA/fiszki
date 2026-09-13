---
project: 10xCards
version: 1
status: draft
created: 2026-09-13
updated: 2026-09-13
prd_version: 1
main_goal: market-feedback
top_blocker: time
milestone_id: mvp-text-to-review
milestone_seq: 1
milestone_status: open
---

# Roadmap: 10xCards

> Derived from `context/foundation/prd.md` (v1) + auto-researched codebase baseline.
> Edit-in-place; archive when superseded.
> Slices below are listed in dependency order. The "At a glance" table is the index.

## Milestone

**M-1: MVP — od wklejonego tekstu do sesji powtórek** — Status: open

- **Intent:** Udowodnić, że użytkownik przechodzi od tekstu źródłowego do nauki bez ręcznej pracy pośredniej: fiszki generowane przez AI są akceptowane w ≥ 75% i stanowią ≥ 75% wszystkich tworzonych fiszek, a zaakceptowane fiszki trafiają do prywatnego zestawu i do sesji powtórek SM-2.
- **Source materials:** `context/foundation/prd.md` (v1)
- **Done when:** every F-NN and S-NN below is `done`.
- **Scope anchors:** FR-001 … FR-008 (wszystkie wymagania konieczne PRD), US-01 … US-05.

## Vision recap

Ręczne tworzenie fiszek jest czasochłonne i wymaga decyzji, co jest warte zapisania — to zniechęca do spaced repetition. Istniejące narzędzia rozwiązują tylko połowę problemu: generatory fiszek i systemy powtórek żyją osobno. 10xCards łączy generowanie fiszek przez AI z algorytmem powtórek SM-2 w jednym przepływie, tak by student przeszedł od wklejonego tekstu do nauki bez ręcznej pracy pośredniej. Główna hipoteza produktu (twierdzenie, które musi okazać się prawdziwe, żeby produkt miał sens) brzmi: fiszki wygenerowane przez AI z własnego tekstu użytkownika są na tyle dobre, że użytkownik akceptuje większość z nich zamiast pisać własne.

## North star

**S-02: użytkownik wkleja tekst, dostaje w < 10 s zestaw fiszek AI z widocznym postępem, przegląda je, poprawia lub odrzuca i akceptuje wybrane do swojego zestawu** — to jedyny plaster, który mierzy oba główne kryteria sukcesu PRD (odsetek akceptacji i udział fiszek z AI) i jednocześnie testuje najbardziej ryzykowne założenie techniczne (to, którego obalenie najszybciej unieważniłoby produkt): generowanie w limicie czasu na wybranej platformie. Przy celu `market-feedback` sygnał z tego plastra rozstrzyga, czy reszta roadmapy ma sens.

> Gwiazda przewodnia to tutaj najmniejszy przepływ od początku do końca, którego dostarczenie udowadnia główną hipotezę produktu — umieszczony tak wcześnie, jak pozwalają jego wymagania wstępne, bo wszystko inne ma znaczenie tylko wtedy, gdy on działa.

## At a glance

| ID   | Change ID                  | Outcome (user can …)                                                                                      | Prerequisites    | PRD refs                                | Status   |
| ---- | -------------------------- | --------------------------------------------------------------------------------------------------------- | ---------------- | --------------------------------------- | -------- |
| F-01 | private-flashcard-store    | (foundation) trwały zapis fiszki przypisanej do właściciela, z egzekwowaną izolacją per użytkownik        | —                | US-01, NFR (izolacja danych), Guardrail | in-progress |
| F-02 | ai-generation-channel      | (foundation) kanał do dostawcy AI działa z produkcji: odpowiedź dociera przyrostowo w limicie < 10 s      | —                | FR-003, NFR (< 10 s), US-02             | ready    |
| S-01 | account-and-empty-deck     | użytkownik rejestruje się lub loguje i widzi swój własny (na start pusty) zestaw fiszek                   | F-01             | US-01, FR-001, FR-002                   | proposed |
| S-02 | gated-ai-generation        | użytkownik wkleja tekst, dostaje fiszki AI z postępem, przegląda, poprawia, odrzuca i akceptuje wybrane   | F-01, F-02, S-01 | US-02, FR-003, FR-004                   | proposed |
| S-03 | manual-flashcard-create    | użytkownik ręcznie tworzy fiszkę (pytanie + odpowiedź), która ląduje w zestawie na równi z fiszkami z AI  | S-01             | US-04, FR-007                           | proposed |
| S-04 | flashcard-edit-delete      | użytkownik edytuje treść fiszki w zestawie i świadomie usuwa zbędną fiszkę bez utraty pozostałych         | S-01, S-03       | US-03, FR-005, FR-006                   | proposed |
| S-05 | srs-review-session         | użytkownik startuje sesję powtórek SM-2, odpowiada na fiszki, ma zaplanowane kolejne powtórki i podsumowanie | S-01, S-03       | US-05, FR-008                           | proposed |

## Streams

Navigation aid — groups items that share a Prerequisites chain. Canonical ordering still lives in the dependency graph below; this table is the proposed reading order across parallel tracks.

| Stream | Theme                              | Chain                      | Note                                                                                                   |
| ------ | ---------------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------ |
| A      | Prywatny zestaw i generowanie AI   | `F-01` → `S-01` → `S-02`   | Ścieżka do gwiazdy przewodniej; przy celu `market-feedback` ma pierwszeństwo przy każdym remisie.       |
| B      | Kanał do dostawcy AI               | `F-02`                     | Równoległy do F-01; dołącza do Stream A w S-02. Redukuje najbardziej ryzykowne założenie techniczne.    |
| C      | Ręczny zestaw i pętla nauki        | `S-03` → `S-04` → `S-05`   | Dołącza do Stream A w S-01; cały strumień może iść równolegle z S-02 w osobnych uruchomieniach agenta.  |

## Baseline

What's already in place in the codebase as of `2026-09-13` (auto-researched + user-confirmed).
Foundations below assume these are present and do NOT re-scaffold them.

- **Frontend:** partial — scaffold startera (SSR + wyspy React, Tailwind, jeden prymityw UI): formularze auth, strona powitalna, placeholder dashboardu (`src/pages/dashboard.astro`). Zero UI domenowego (fiszki, generowanie, sesja).
- **Backend / API:** partial — endpointy tylko dla auth (`src/pages/api/auth/*`), middleware chroniący prefiks `/dashboard` (`src/middleware.ts`). Brak endpointów domenowych i klienta dostawcy AI (ani w kodzie, ani w zależnościach).
- **Data:** absent — klient bazy użyty wyłącznie do auth; katalog `supabase/` zawiera tylko konfigurację. Brak migracji, danych startowych, typów bazy i tabel domenowych.
- **Auth:** present — rejestracja, logowanie i wylogowanie email + hasło spięte end-to-end, sesja w cookies, użytkownik w `locals` (`src/lib/supabase.ts`, `src/middleware.ts`). Brak resetu hasła i OAuth (OAuth poza MVP per PRD).
- **Deploy / infra:** present — produkcja wdrożona na Cloudflare Workers (`context/deployment/deploy-plan.md`: status `deployed`), auto-deploy z `master` przez Workers Builds, CI lint + build (`.github/workflows/ci.yml`).
- **Observability:** partial — logi platformy włączone (`wrangler.jsonc`, `wrangler tail`); zero logowania aplikacyjnego, brak śledzenia błędów.
- **Testing:** absent — brak runnera testów, skryptu `test` i plików testowych; jedyne bramki jakości to lint, format i build w CI.

## Foundations

### F-01: Prywatny, trwały magazyn fiszek

- **Outcome:** (foundation) pojedyncza fiszka (pytanie, odpowiedź, właściciel, pochodzenie: AI lub ręczne) daje się trwale zapisać i odczytać wyłącznie przez właściciela; izolacja jest egzekwowana po stronie bazy i zweryfikowana testem „użytkownik A nie widzi fiszki użytkownika B”.
- **Change ID:** private-flashcard-store
- **PRD refs:** US-01 (fiszki trwale zapisywane, dostęp wyłącznie do swoich), NFR „dane fiszek dostępne wyłącznie dla właściciela”, Guardrail „fiszki nie mogą zniknąć”, Access Control (model płaski, brak ról).
- **Unlocks:** S-01, S-02, S-03, S-04, S-05 — każdy plaster czyta lub zapisuje fiszki właściciela; oraz ścieżka weryfikacji izolacji per użytkownik, bez której S-01 nie da się bezpiecznie wdrożyć na produkcję.
- **Prerequisites:** —
- **Parallel with:** F-02
- **Blockers:** —
- **Unknowns:** —
- **Risk:** To jedyna warstwa całkowicie nieobecna w bazie kodu, a wymagana przez każdy plaster; sekwencjonowana pierwsza, bo bez niej gwiazda przewodnia nie ma gdzie zapisać zaakceptowanych fiszek. Zakres celowo minimalny: jedna encja i polityka izolacji. Dane o powtórkach (SM-2) NIE wchodzą tutaj — dochodzą w S-05, gdy pierwszy raz są potrzebne.
- **Status:** in-progress

### F-02: Kanał do dostawcy AI działający z produkcji

- **Outcome:** (foundation) żądanie z wdrożonej aplikacji dociera do dostawcy AI wskazanego w `tech-stack.md`, a odpowiedź wraca do przeglądarki przyrostowo (lub z raportowanym postępem) w limicie < 10 s; brak klucza dostawcy jest widoczny w UI tak samo jak brak konfiguracji bazy, zamiast wysypywać stronę.
- **Change ID:** ai-generation-channel
- **PRD refs:** FR-003 (generowanie przez AI), NFR „czas generowania < 10 s z widoczną informacją o postępie”, US-02.
- **Unlocks:** S-02 (gwiazda przewodnia); redukuje niewiadomą „czy limit czasu CPU na darmowym planie platformy wystarczy na strumieniowanie odpowiedzi AI i render strony przeglądu” z rejestru ryzyk `infrastructure.md`.
- **Prerequisites:** —
- **Parallel with:** F-01
- **Blockers:** —
- **Unknowns:**
  - Czy strumieniowanie odpowiedzi AI mieści się w limicie CPU darmowego planu platformy przy realnej długości tekstu źródłowego? — Owner: user. Block: no (ten fundament odpowiada na to pytanie pomiarem z produkcji; jeśli nie — decyzja o planie płatnym jest zapisana jako opcja w `infrastructure.md`).
  - Sekret klucza dostawcy AI musi wpisać człowiek, nie agent (reguła repo). — Owner: user. Block: no (planowanie może ruszyć; weryfikacja końcowa czeka na klucz).
- **Risk:** Najbardziej ryzykowne założenie techniczne całego PRD; wyciągnięte przed S-02, żeby porażka limitu czasu wyszła na małym, mierzalnym kroku, a nie w środku planowania gwiazdy przewodniej. Zakres to wyłącznie „kanał działa i mierzymy czas” — bez logiki klasyfikacji wiedzy, bez UI przeglądu; te należą do S-02.
- **Status:** ready

## Slices

### S-01: Konto i własny, pusty zestaw fiszek

- **Outcome:** użytkownik rejestruje się (email + hasło) lub loguje i trafia do chronionego obszaru aplikacji, w którym widzi wyłącznie swój zestaw fiszek — na start pusty, z jasnym zaproszeniem do wygenerowania lub dodania pierwszej fiszki.
- **Change ID:** account-and-empty-deck
- **PRD refs:** US-01, FR-001, FR-002, Access Control (nieuwierzytelniony użytkownik nie ma dostępu do fiszek ani generowania).
- **Prerequisites:** F-01
- **Parallel with:** F-02
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Auth już istnieje w bazie kodu, więc ten plaster jest celowo cienki: podpina istniejące logowanie do listy własnych fiszek i rozszerza ochronę tras na obszar domenowy. Jest wymagany wstępnie przez wszystko dalej, bo daje miejsce, w którym lądują fiszki z S-02 i S-03.
- **Status:** proposed

### S-02: Generowanie fiszek AI z przeglądem przed akceptacją

- **Outcome:** użytkownik wkleja tekst źródłowy, uruchamia generowanie, widzi postęp i w < 10 s otrzymuje zestaw fiszek pytanie–odpowiedź dopasowanych do rodzaju wiedzy w tekście (definicja, procedura, fakt); każdą kandydującą fiszkę może poprawić lub odrzucić, a akceptuje tylko te, które chce zachować — zaakceptowane pojawiają się w jego zestawie oznaczone jako pochodzące z AI.
- **Change ID:** gated-ai-generation
- **PRD refs:** US-02 (wraz z kryteriami akceptacji), FR-003, FR-004, Business Logic (klasyfikacja rodzaju wiedzy i dopasowany format), NFR „< 10 s z widoczną informacją o postępie”.
- **Prerequisites:** F-01, F-02, S-01
- **Parallel with:** S-03, S-04, S-05
- **Blockers:** —
- **Unknowns:**
  - Jak mierzyć operacyjnie KPI „≥ 75% fiszek AI zaakceptowanych” i „≥ 75% fiszek z AI”? — Owner: user. Block: no (PRD: Otwarte pytanie 2; ten plaster jest naturalnym miejscem, by zapisać liczbę wygenerowanych vs zaakceptowanych fiszek, ale decyzja o zakresie instrumentacji należy do planowania).
- **Risk:** Gwiazda przewodnia. Sekwencjonowana natychmiast po S-01, bo przy celu `market-feedback` sygnał jakości generowania rozstrzyga wartość całego produktu. Ryzyko jakości promptu (format fiszki nie pasuje do rodzaju wiedzy) ujawni się tylko na realnych tekstach użytkownika, stąd nacisk na wczesny deploy tego plastra na produkcję.
- **Status:** proposed

### S-03: Ręczne tworzenie fiszki

- **Outcome:** użytkownik wpisuje pytanie i odpowiedź i zapisuje fiszkę, która ląduje w jego zestawie na równi z fiszkami z AI, oznaczona jako utworzona ręcznie.
- **Change ID:** manual-flashcard-create
- **PRD refs:** US-04, FR-007.
- **Prerequisites:** S-01
- **Parallel with:** S-02
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Najmniejszy plaster domenowy i najtańsze źródło fiszek dla S-04 i S-05, dlatego jest ich wymaganiem wstępnym zamiast S-02 — dzięki temu pętla nauki (Stream C) może być planowana i wdrażana równolegle, gdy S-02 czeka na klucz dostawcy AI lub wyniki pomiaru z F-02. Oznaczenie pochodzenia (ręczne vs AI) jest warunkiem policzenia KPI adopcji.
- **Status:** proposed

### S-04: Edycja i świadome usuwanie fiszki w zestawie

- **Outcome:** użytkownik edytuje treść pytania lub odpowiedzi istniejącej fiszki i widzi zmianę w zestawie; usuwa zbędną fiszkę wyłącznie jawną, świadomą akcją, a żadna operacja nie usuwa ani nie nadpisuje pozostałych fiszek.
- **Change ID:** flashcard-edit-delete
- **PRD refs:** US-03 (wraz z kryterium akceptacji), FR-005, FR-006, Guardrail „żadna akcja nie powoduje nieodwracalnej utraty danych”.
- **Prerequisites:** S-01, S-03
- **Parallel with:** S-02, S-05
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Edycja jest niezbędna do korekty błędów AI po akceptacji, więc domyka wartość S-02, ale nie blokuje jej pomiaru — stąd po S-02 w porządku czytania i równolegle z nim w wykonaniu. Guardrail o utracie danych oznacza, że usuwanie musi być jawnie potwierdzone; jak dokładnie — to decyzja planowania.
- **Status:** proposed

### S-05: Sesja powtórek spaced repetition

- **Outcome:** użytkownik z fiszkami w zestawie startuje sesję powtórek, widzi kolejne fiszki, ocenia swoją odpowiedź, a algorytm SM-2 planuje termin następnej powtórki każdej fiszki; po zakończeniu sesji widzi podsumowanie. Następnego dnia sesja pokazuje fiszki, których termin nadszedł.
- **Change ID:** srs-review-session
- **PRD refs:** US-05, FR-008, Non-Goals (gotowy algorytm SM-2, nie własny silnik), Success Criteria (drugorzędne: powrót następnego dnia).
- **Prerequisites:** S-01, S-03
- **Parallel with:** S-02, S-04
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Domyka pętlę „od tekstu do nauki” i jest jedynym plastrem mierzącym sygnał retencji. Wprowadza dane o stanie powtórek (termin, interwał) dopiero tutaj — celowo nie w F-01, żeby fundament pozostał minimalny. Największe ryzyko to rozjazd między poprawnością SM-2 a wrażeniem użytkownika (za dużo lub za mało fiszek dziennie); ujawni się dopiero po drugim dniu użycia.
- **Status:** proposed

## Backlog Handoff

| Roadmap ID | Change ID               | Suggested issue title                                                  | Ready for `/10x-plan` | Notes                                                                 |
| ---------- | ----------------------- | ---------------------------------------------------------------------- | --------------------- | --------------------------------------------------------------------- |
| F-01       | private-flashcard-store | Fundament: prywatny, trwały magazyn fiszek z izolacją per użytkownik   | yes                   | Run `/10x-plan private-flashcard-store` — odblokowuje gwiazdę S-02   |
| F-02       | ai-generation-channel   | Fundament: kanał do dostawcy AI z produkcji w limicie < 10 s           | yes                   | Równolegle z F-01; wymaga klucza dostawcy wpisanego przez człowieka   |
| S-01       | account-and-empty-deck  | Konto i własny, pusty zestaw fiszek                                    | no                    | Czeka na F-01                                                         |
| S-02       | gated-ai-generation     | Generowanie fiszek AI z przeglądem i akceptacją                        | no                    | Gwiazda przewodnia; czeka na F-01, F-02, S-01                         |
| S-03       | manual-flashcard-create | Ręczne tworzenie fiszki                                                | no                    | Czeka na S-01; potem równolegle z S-02                                |
| S-04       | flashcard-edit-delete   | Edycja i świadome usuwanie fiszki                                      | no                    | Czeka na S-01, S-03                                                   |
| S-05       | srs-review-session      | Sesja powtórek SM-2 z podsumowaniem                                    | no                    | Czeka na S-01, S-03                                                   |

## Open Roadmap Questions

1. **Ziarnistość skali (przepustowość, wolumen danych) przy `users: small`** — Owner: user. Block: `—` (rozsądne domyślne wystarczą; PRD Otwarte pytanie 1).
2. **Operacyjny pomiar KPI akceptacji (≥ 75%) i udziału fiszek z AI (≥ 75%)** — Owner: user. Block: `—` (PRD Otwarte pytanie 2; F-01 przewiduje pole „pochodzenie” fiszki, S-02 jest naturalnym miejscem zliczania wygenerowanych vs zaakceptowanych — zakres instrumentacji do rozstrzygnięcia w planowaniu S-02).
3. **Sposób weryfikacji plastrów bez runnera testów** — baza kodu nie ma żadnego runnera ani testów; PRD tego nie wymaga, więc nie jest to plaster. Owner: user. Block: `—` (każdy `/10x-plan` musi jednak nazwać ścieżkę weryfikacji; jeśli pierwsza migracja i izolacja per użytkownik w F-01 mają być sprawdzone automatycznie, decyzja o runnerze zapadnie tam).

## Parked

- **Logowanie federacyjne (OAuth)** — Why parked: PRD §Access Control i FR-001: „OAuth przeniesiony do nice-to-have / v2”.
- **Własny algorytm powtórek** — Why parked: PRD §Non-Goals: korzystamy z gotowego SM-2, własny silnik to osobny projekt.
- **Import plików (PDF, DOCX)** — Why parked: PRD §Non-Goals: w MVP tylko kopiuj-wklej.
- **Współdzielenie zestawów, funkcje społecznościowe** — Why parked: PRD §Non-Goals: fiszki są prywatne.
- **Aplikacja mobilna i integracje z platformami edukacyjnymi** — Why parked: PRD §Non-Goals: tylko web.
- **Śledzenie błędów i logowanie aplikacyjne** — Why parked: baza kodu ma tylko logi platformy; PRD nie stawia wymagań obserwowalności, a przy głównym ryzyku `time` nie wchodzi do ścieżki koniecznych. Wraca, gdy pierwsi użytkownicy zgłoszą błędy generowania.

## Milestone History

(Append-only. Empty on the very first milestone.)

## Done

(Empty on first generation. `/10x-archive` appends an entry here — and flips that item's `Status` to `done` — when a change whose `Change ID` matches the item is archived. Do NOT pre-populate. Format:)

- **<Slice ID>: <Outcome>** — Archived <YYYY-MM-DD> → `context/archive/<YYYY-MM-DD-change-id>/`. Lesson: <pointer to lessons.md if any, or `—`>.
