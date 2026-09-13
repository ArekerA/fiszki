---
change_id: private-flashcard-store
title: Fundament F-01: prywatny, trwały magazyn fiszek z izolacją per użytkownik
status: archived
created: 2026-09-13
updated: 2026-09-13
archived_at: 2026-09-13T20:49:39Z
---

## Notes

F-01 z `context/foundation/roadmap.md` (milestone M-1 `mvp-text-to-review`, Stream A, status `ready`).

- **Outcome:** pojedyncza fiszka (pytanie, odpowiedź, właściciel, pochodzenie: AI lub ręczne) daje się trwale zapisać i odczytać wyłącznie przez właściciela; izolacja egzekwowana po stronie bazy (RLS) i zweryfikowana testem „użytkownik A nie widzi fiszki użytkownika B”.
- **PRD refs:** US-01, NFR „dane fiszek dostępne wyłącznie dla właściciela”, Guardrail „fiszki nie mogą zniknąć”, Access Control (model płaski, brak ról).
- **Unlocks:** S-01, S-02, S-03, S-04, S-05.
- **Zakres celowo minimalny:** jedna encja + polityka izolacji. Dane SM-2 (termin, interwał) NIE wchodzą tutaj — dochodzą w S-05.
- **Do rozstrzygnięcia w planie:** pierwsza migracja w `supabase/migrations/` (dziś katalog ma tylko `config.toml`); sposób weryfikacji izolacji bez runnera testów (Open Roadmap Question 3).
