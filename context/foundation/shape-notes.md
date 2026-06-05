---
project: 10xCards
context_type: greenfield
updated: 2026-06-05
product_type: web-app
target_scale:
  users: small
checkpoint:
  current_phase: 8
  phases_completed: [1, 2, 3, 4, 5, 6, 7]
  frs_drafted: 8
  quality_check_status: accepted
  timeline_budget:
    mvp_weeks: 3
    after_hours_only: true
    hard_deadline: null
---

## Vision & Problem Statement

Ręczne tworzenie wysokiej jakości fiszek edukacyjnych jest czasochłonne i wymaga decyzji co jest warte zapisania — co zniechęca do korzystania z efektywnej metody nauki jaką jest spaced repetition. Istniejące narzędzia nie łączą AI z algorytmem powtórek w jednym spójnym produkcie.

- **Ból**: Ręczne tworzenie fiszek jest żmudne (tarcie w procesie) i wymaga decyzji co zapisać (paraliż decyzyjny).
- **Moment**: Gdy uczeń/student chce przetworzyć materiał tekstowy (np. notatki, artykuły) w materiał do nauki metodą spaced repetition.
- **Koszt dziś**: Czas i wysiłek decyzyjny — zamiast samej nauki użytkownik spędza czas na ręcznym tworzeniu fiszek.
- **Insight**: Istniejące narzędzia (generatory fiszek i systemy powtarzania) istnieją osobno, nie jako jeden spójny produkt.

## User & Persona

**Persona główna**: Student / uczeń uczący się konkretnej dziedziny — języki obce, prawo, medycyna, IT, certyfikaty zawodowe. Ma dużo materiału do opanowania w określonym czasie i chce skupić się na nauce, nie na administracji materiałem.

- Zna metodę spaced repetition lub chce ją stosować.
- Ma dostęp do tekstów źródłowych (notatki, podręczniki, artykuły).
- Brakuje mu czasu lub motywacji na ręczne tworzenie setek fiszek.

## Access Control

- **Metoda dostępu**: Logowanie — email + hasło. OAuth (np. Google) jako opcja v2.
- **Model ról**: Płaski — wszyscy użytkownicy mają te same uprawnienia. Każdy użytkownik widzi i zarządza wyłącznie swoimi fiszkami.
- **Brak ról admina w MVP.**

## Success Criteria

### Primary

Oba poniższe warunki muszą być spełnione jednocześnie:
- ≥ 75% fiszek wygenerowanych przez AI jest akceptowanych przez użytkownika (jakość generowania).
- ≥ 75% fiszek tworzonych przez użytkownika pochodzi z AI (adopcja funkcji).

### Secondary

Użytkownik wraca na kolejną sesję SR następnego dnia (sygnał retencji — dowód, że nauka się odbywa).

### Guardrails

- Fiszki użytkownika nie mogą zniknąć — żadna akcja nie powoduje nieodwracalnej utraty danych.
- Aplikacja działa poprawnie w nowoczesnych przeglądarkach: Chrome, Firefox, Safari.

### MVP Flow

1. Użytkownik rejestruje konto (email + hasło).
2. Wkleja tekst źródłowy.
3. AI generuje zestaw fiszek.
4. Użytkownik przegląda — może edytować lub usunąć każdą fiszkę przed akceptacją.
5. Użytkownik startuje sesję spaced repetition (algorytm SM-2).

## Business Logic

Na podstawie przesłanego tekstu aplikacja klasyfikuje zawartą w nim wiedzę według rodzaju (definicja, procedura, fakt) i generuje fiszki w dopasowanym formacie pytanie–odpowiedź.

- **Wejście**: tekst źródłowy dostarczony przez użytkownika (kopiuj-wklej).
- **Wyjście**: zestaw fiszek z pytaniem i odpowiedzią, gdzie format pary jest dopasowany do rodzaju wiedzy wykrytego w tekście.
- **Jak użytkownik to widzi**: po wklejeniu tekstu i kliknięciu „Generuj" otrzymuje listę gotowych fiszek do przeglądu — bez konieczności samodzielnego decydowania, co jest warte zapamiętania.

## Non-Functional Requirements

- Czas generowania fiszek postrzegany przez użytkownika < 10s (z widocznym wskaźnikiem postępu).
- Dane fiszek dostępne wyłącznie dla ich właściciela — żaden użytkownik nie widzi fiszek innego użytkownika.
- Aplikacja działa poprawnie na dwóch ostatnich wersjach Chrome, Firefox i Safari.

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

## Non-Goals

- **Własny algorytm SR**: nie budujemy własnego SuperMemo ani Anki — używamy gotowej biblioteki SM-2. Powód: to osobny projekt, który nie jest warunkiem koniecznym dla wartości MVP.
- **Import plików (PDF, DOCX)**: tylko kopiuj-wklej w MVP. Parsowanie różnych formatów to osobna złożoność.
- **Współdzielenie zestawów między użytkownikami**: fiszki są prywatne — brak funkcji społecznościowych w MVP.
- **Aplikacja mobilna i integracje z platformami edukacyjnymi**: tylko web, bez natywnych aplikacji iOS/Android i bez integracji z Moodle, Google Classroom itp.

## User Stories

### US-01: Rejestracja i logowanie

Given jestem nowym użytkownikiem bez konta
When rejestruję się podając email i hasło
Then moje konto zostaje utworzone, jestem zalogowany, a moje fiszki będą trwale zapisywane między sesjami

Given mam już konto
When loguję się email i hasłem
Then uzyskuję dostęp wyłącznie do swoich fiszek

### US-02: Generowanie i przegląd fiszek

Given jestem zalogowanym użytkownikiem
When wklejam tekst źródłowy i klikam „Generuj"
Then AI tworzy zestaw fiszek pytanie–odpowiedź dopasowanych do rodzaju wiedzy w tekście, w czasie < 10s z widocznym wskaźnikiem postępu
And mogę przejrzeć każdą fiszkę, edytować ją lub usunąć przed akceptacją
And akceptuję tylko te fiszki, które chcę zachować

### US-03: Edycja i usuwanie fiszki

Given mam fiszkę w swoim zestawie
When edytuję treść pytania lub odpowiedzi
Then zmiany zostają zapisane i są widoczne w zestawie

Given chcę usunąć zbędną fiszkę
When usuwam ją
Then fiszka znika z zestawu (świadoma akcja użytkownika — żadna akcja nie powoduje nieodwracalnej utraty pozostałych danych)

### US-04: Ręczne tworzenie fiszki

Given jestem zalogowanym użytkownikiem
When tworzę fiszkę ręcznie, wpisując pytanie i odpowiedź
Then fiszka zostaje dodana do mojego zestawu na równi z fiszkami z AI

### US-05: Sesja spaced repetition

Given jestem zalogowanym użytkownikiem z fiszkami w zestawie
When startuję sesję spaced repetition (SM-2) i odpowiadam na wyświetlane fiszki
Then algorytm planuje kolejne powtórki, a po zakończeniu sesji widzę podsumowanie
