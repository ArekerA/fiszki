---
starter_id: 10x-astro-starter
package_manager: npm
project_name: al-fiszki
hints:
  language_family: js
  team_size: solo
  deployment_target: cloudflare-pages
  ci_provider: github-actions
  ci_default_flow: auto-deploy-on-merge
  bootstrapper_confidence: first-class
  path_taken: standard
  quality_override: false
  self_check_answers: null
  has_auth: true
  has_payments: false
  has_realtime: false
  has_ai: true
  has_background_jobs: false
---

## Why this stack

Solo deweloper buduje po godzinach MVP aplikacji web 10xCards (generowanie fiszek przez AI plus sesje spaced repetition SM-2) w trzy tygodnie, dla małej skali użytkowników. PRD wymaga kont email + hasło (FR-001, FR-002), trwałej izolacji danych per użytkownik oraz wywołań LLM przy generowaniu fiszek (FR-003); płatności, realtime i zadania w tle są poza zakresem. Wybrano ścieżkę standardową: `10x-astro-starter` jest rekomendowanym domyślnym starterem dla komórki `(web, js)` i przechodzi wszystkie cztery bramki agent-friendly (typowany TypeScript + Zod, silne konwencje Astro, popularny w danych treningowych, aktualna dokumentacja). Supabase dostarcza Postgres, auth i RLS z pudła, co bezpośrednio pokrywa wymagania kont i izolacji danych bez własnej implementacji. Pewność scaffoldowania to `first-class`, więc bootstrapper powinien działać płynnie z okazjonalnymi krokami ręcznymi. Wdrożenie na Cloudflare Pages (domyślne dla startera), CI na GitHub Actions z auto-deployem po merge do main. Uwaga operacyjna: edge runtime ogranicza długie zadania, więc generowanie fiszek (limit < 10 s z PRD) powinno strumieniować odpowiedź LLM lub raportować postęp.
