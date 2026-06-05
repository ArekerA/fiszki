---
project: 10xCards
version: 1
status: draft
created: 2026-06-05
context_type: greenfield
product_type: web-app
target_scale:
  users: small
timeline_budget:
  mvp_weeks: 3
  hard_deadline: null
  after_hours_only: true
---

## Vision & Problem Statement

Ręczne tworzenie wysokiej jakości fiszek edukacyjnych jest czasochłonne i wymaga decyzji co jest warte zapisania — co zniechęca do korzystania z efektywnej metody nauki jaką jest spaced repetition. Uczeń lub student, chcąc przetworzyć materiał tekstowy (notatki, artykuły, podręczniki) w materiał do nauki, spędza czas na żmudnym tworzeniu fiszek (tarcie w procesie) i na decydowaniu, co zapisać (paraliż decyzyjny) — zamiast na samej nauce.

Istniejące narzędzia rozwiązują tylko połowę problemu: generatory fiszek i systemy powtarzania istnieją osobno, nie jako jeden spójny produkt. Insight, który czyni ten PRD wartym napisania, to połączenie automatycznego generowania fiszek z AI z algorytmem powtórek w jednym przepływie — tak, by użytkownik przeszedł od tekstu źródłowego do nauki bez ręcznej pracy pośredniej.

## User & Persona

**Persona główna**: Student / uczeń uczący się konkretnej dziedziny — języki obce, prawo, medycyna, IT, certyfikaty zawodowe. Ma dużo materiału do opanowania w określonym czasie i chce skupić się na nauce, nie na administracji materiałem. Sięga po produkt w momencie, gdy ma tekst źródłowy do przerobienia i chce szybko zamienić go w fiszki do powtórek.

- Zna metodę spaced repetition lub chce ją stosować.
- Ma dostęp do tekstów źródłowych (notatki, podręczniki, artykuły).
- Brakuje mu czasu lub motywacji na ręczne tworzenie setek fiszek.

## Success Criteria

### Primary

Oba poniższe warunki muszą być spełnione jednocześnie:

- ≥ 75% fiszek wygenerowanych przez AI jest akceptowanych przez użytkownika (jakość generowania).
- ≥ 75% fiszek tworzonych przez użytkownika pochodzi z AI (adopcja funkcji).

### Secondary

- Użytkownik wraca na kolejną sesję spaced repetition następnego dnia (sygnał retencji — dowód, że nauka się odbywa).

### Guardrails

- Fiszki użytkownika nie mogą zniknąć — żadna akcja nie powoduje nieodwracalnej utraty danych.
- Aplikacja działa poprawnie w nowoczesnych przeglądarkach: Chrome, Firefox, Safari.

## User Stories

### US-01: Rejestracja i logowanie

- **Given** jestem nowym użytkownikiem bez konta
- **When** rejestruję się podając email i hasło
- **Then** moje konto zostaje utworzone, jestem zalogowany, a moje fiszki będą trwale zapisywane między sesjami

- **Given** mam już konto
- **When** loguję się email i hasłem
- **Then** uzyskuję dostęp wyłącznie do swoich fiszek

### US-02: Generowanie i przegląd fiszek

- **Given** jestem zalogowanym użytkownikiem
- **When** wklejam tekst źródłowy i uruchamiam generowanie
- **Then** otrzymuję zestaw fiszek pytanie–odpowiedź dopasowanych do rodzaju wiedzy w tekście, w czasie < 10 s z widoczną informacją o postępie

#### Acceptance Criteria

- Mogę przejrzeć każdą fiszkę, edytować ją lub usunąć przed akceptacją.
- Akceptuję tylko te fiszki, które chcę zachować.

### US-03: Edycja i usuwanie fiszki

- **Given** mam fiszkę w swoim zestawie
- **When** edytuję treść pytania lub odpowiedzi
- **Then** zmiany zostają zapisane i są widoczne w zestawie

- **Given** chcę usunąć zbędną fiszkę
- **When** usuwam ją
- **Then** fiszka znika z zestawu

#### Acceptance Criteria

- Usunięcie jest świadomą akcją użytkownika — żadna akcja nie powoduje nieodwracalnej utraty pozostałych danych.

### US-04: Ręczne tworzenie fiszki

- **Given** jestem zalogowanym użytkownikiem
- **When** tworzę fiszkę ręcznie, wpisując pytanie i odpowiedź
- **Then** fiszka zostaje dodana do mojego zestawu na równi z fiszkami z AI

### US-05: Sesja spaced repetition

- **Given** jestem zalogowanym użytkownikiem z fiszkami w zestawie
- **When** startuję sesję spaced repetition i odpowiadam na wyświetlane fiszki
- **Then** kolejne powtórki są zaplanowane, a po zakończeniu sesji widzę podsumowanie

## Functional Requirements

### Konta użytkowników

- FR-001: Użytkownik może zarejestrować konto (email + hasło). Priority: must-have
  > Socrates: OAuth komplikuje MVP — wystarczy email/hasło na start. Rozwiązanie: OAuth przeniesiony do nice-to-have / v2.
- FR-002: Użytkownik może zalogować się na swoje konto. Priority: must-have
  > Socrates: Brak kontrargumentu — auth jest warunkiem koniecznym dla persystencji danych.

### Generowanie fiszek

- FR-003: Użytkownik może wkleić tekst źródłowy i wygenerować z niego fiszki przy pomocy AI. Priority: must-have
  > Socrates: Brak kontrargumentu — to core wartość produktu; bez AI produkt nie różni się od ręcznego Anki.
- FR-004: Użytkownik może przejrzeć wygenerowane fiszki przed ich akceptacją. Priority: must-have
  > Socrates: Brak kontrargumentu — bez przeglądu nie można zrealizować KPI ≥75% akceptacji.

### Zarządzanie fiszkami

- FR-005: Użytkownik może edytować fiszkę (treść pytania i odpowiedzi). Priority: must-have
  > Socrates: Brak kontrargumentu — edycja jest niezbędna do korekty błędów AI.
- FR-006: Użytkownik może usunąć fiszkę. Priority: must-have
  > Socrates: Brak kontrargumentu — edycja i usuwanie są kompletnym zestawem zarządzania.
- FR-007: Użytkownik może ręcznie utworzyć fiszkę. Priority: must-have
  > Socrates: Brak kontrargumentu — niektóre fiszki (własne definicje, mnemotechniki) trudno wygenerować automatycznie; użytkownik potrzebuje pełnej kontroli.

### Sesja nauki

- FR-008: Użytkownik może wystartować sesję spaced repetition (algorytm SM-2) i zobaczyć podsumowanie po jej zakończeniu. Priority: must-have
  > Socrates: Brak kontrargumentu — SR jest esencją produktu; bez niego to tylko generator fiszek, nie narzędzie do nauki.

## Non-Functional Requirements

- Czas generowania fiszek postrzegany przez użytkownika < 10 s, z widoczną informacją o postępie podczas oczekiwania.
- Dane fiszek dostępne wyłącznie dla ich właściciela — żaden użytkownik nie widzi fiszek innego użytkownika.
- Aplikacja pozostaje używalna na dwóch ostatnich głównych wersjach Chrome, Firefox i Safari.

## Business Logic

Na podstawie przesłanego tekstu aplikacja klasyfikuje zawartą w nim wiedzę według rodzaju (definicja, procedura, fakt) i generuje fiszki w dopasowanym formacie pytanie–odpowiedź.

- **Wejście**: tekst źródłowy dostarczony przez użytkownika (kopiuj-wklej).
- **Wyjście**: zestaw fiszek z pytaniem i odpowiedzią, gdzie format pary jest dopasowany do rodzaju wiedzy wykrytego w tekście.
- **Jak użytkownik to widzi**: po wklejeniu tekstu i uruchomieniu generowania otrzymuje listę gotowych fiszek do przeglądu — bez konieczności samodzielnego decydowania, co jest warte zapamiętania.

## Access Control

- **Metoda dostępu**: Logowanie — email + hasło. Logowanie federacyjne (OAuth) jest opcją rozważaną na v2, poza zakresem MVP.
- **Model ról**: Płaski — wszyscy użytkownicy mają te same uprawnienia. Każdy użytkownik widzi i zarządza wyłącznie swoimi fiszkami.
- **Brak ról administracyjnych w MVP.**
- Nieuwierzytelniony użytkownik nie ma dostępu do żadnych fiszek ani funkcji generowania — dostęp do danych wymaga zalogowania.

## Non-Goals

- **Własny algorytm SR**: nie budujemy własnego silnika powtórek typu SuperMemo ani Anki — korzystamy z istniejącego, sprawdzonego algorytmu SM-2. Powód: to osobny projekt, który nie jest warunkiem koniecznym dla wartości MVP.
- **Import plików (PDF, DOCX)**: tylko kopiuj-wklej w MVP. Parsowanie różnych formatów to osobna złożoność.
- **Współdzielenie zestawów między użytkownikami**: fiszki są prywatne — brak funkcji społecznościowych w MVP.
- **Aplikacja mobilna i integracje z platformami edukacyjnymi**: tylko web, bez natywnych aplikacji iOS/Android i bez integracji z platformami edukacyjnymi (np. Moodle, Google Classroom).

## Open Questions

1. **Ziarnistość skali (`target_scale.qps`, `target_scale.data_volume`)** — wejście określiło jedynie `users: small`; przepustowość i wolumen danych nie zostały sprecyzowane. Owner: użytkownik. Block: nie (rozsądne domyślne dla skali „small" wystarczą do startu).
2. **Operacyjny pomiar KPI akceptacji (≥ 75%)** — jak technicznie mierzyć odsetek zaakceptowanych fiszek AI i udział fiszek z AI? Owner: użytkownik. Block: nie (dotyczy instrumentacji, nie zakresu MVP).
