---
bootstrapped_at: 2026-09-04T15:10:53Z
starter_id: 10x-astro-starter
starter_name: "10x Astro Starter (Astro + Supabase + Cloudflare)"
project_name: al-fiszki
language_family: js
package_manager: npm
cwd_strategy: git-clone
bootstrapper_confidence: first-class
phase_3_status: ok
audit_command: "npm audit --json"
---

## Hand-off

Source: `context/foundation/tech-stack.md` (written by `/10x-tech-stack-selector`).

Frontmatter, verbatim:

```yaml
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
```

### Why this stack

Solo deweloper buduje po godzinach MVP aplikacji web 10xCards (generowanie fiszek przez AI plus sesje spaced repetition SM-2) w trzy tygodnie, dla małej skali użytkowników. PRD wymaga kont email + hasło (FR-001, FR-002), trwałej izolacji danych per użytkownik oraz wywołań LLM przy generowaniu fiszek (FR-003); płatności, realtime i zadania w tle są poza zakresem. Wybrano ścieżkę standardową: `10x-astro-starter` jest rekomendowanym domyślnym starterem dla komórki `(web, js)` i przechodzi wszystkie cztery bramki agent-friendly (typowany TypeScript + Zod, silne konwencje Astro, popularny w danych treningowych, aktualna dokumentacja). Supabase dostarcza Postgres, auth i RLS z pudła, co bezpośrednio pokrywa wymagania kont i izolacji danych bez własnej implementacji. Pewność scaffoldowania to `first-class`, więc bootstrapper powinien działać płynnie z okazjonalnymi krokami ręcznymi. Wdrożenie na Cloudflare Pages (domyślne dla startera), CI na GitHub Actions z auto-deployem po merge do main. Uwaga operacyjna: edge runtime ogranicza długie zadania, więc generowanie fiszek (limit < 10 s z PRD) powinno strumieniować odpowiedź LLM lub raportować postęp.

## Pre-scaffold verification

| Signal      | Value                                                              | Severity | Notes                                                                                             |
| ----------- | ------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------- |
| npm package | not run                                                            | n/a      | `cmd_template` starts with `git clone`; no `create-*` CLI to resolve from the template            |
| GitHub repo | `przeprogramowani/10x-astro-starter` last pushed 2026-08-22T21:44:30Z | fresh    | from `card.docs_url`; `gh` CLI unavailable on this machine, fell back to `api.github.com` REST call |

No stale signal. Proceeded without warning.

## Scaffold log

**Resolved invocation**: `git clone https://github.com/przeprogramowani/10x-astro-starter .bootstrap-scaffold && cd .bootstrap-scaffold && npm install`
**Strategy**: git-clone
**Exit code**: 0
**Files moved**: 31533 total (46 excluding `node_modules/`)
**Conflicts (.scaffold siblings)**: `CLAUDE.md.scaffold`, `README.md.scaffold`
**.gitignore handling**: append-merged — 6 existing lines kept in order, then a `# from 10x-astro-starter` separator and 28 scaffold lines appended (0 exact-line duplicates dropped)
**.bootstrap-scaffold cleanup**: deleted (upstream `.git/` removed before move-up, so no starter history leaked into this repo)

### Move detail

| Path                  | Resolution                        |
| --------------------- | --------------------------------- |
| `.env.example`        | moved (1 file)                    |
| `.github/`            | moved (1 file)                    |
| `.husky/`             | moved (1 file)                    |
| `.nvmrc`              | moved (1 file)                    |
| `.prettierrc.json`    | moved (1 file)                    |
| `.vscode/`            | moved (3 files)                   |
| `astro.config.mjs`    | moved (1 file)                    |
| `components.json`     | moved (1 file)                    |
| `eslint.config.js`    | moved (1 file)                    |
| `node_modules/`       | moved (31487 files)               |
| `package-lock.json`   | moved (1 file)                    |
| `package.json`        | moved (1 file)                    |
| `public/`             | moved (3 files)                   |
| `src/`                | moved (26 files)                  |
| `supabase/`           | moved (2 files)                   |
| `tsconfig.json`       | moved (1 file)                    |
| `wrangler.jsonc`      | moved (1 file)                    |
| `.gitignore`          | append-merged into existing       |
| `CLAUDE.md`           | existing won -> `CLAUDE.md.scaffold` |
| `README.md`           | existing won -> `README.md.scaffold` |
| `context/**`          | not present in scaffold; existing `context/` untouched |

## Post-scaffold audit

**Tool**: `npm audit --json` (exit code 1 — informational only; non-zero exit is expected when advisories exist and does not halt bootstrapper)
**Summary**: 1 CRITICAL, 14 HIGH, 7 MODERATE, 3 LOW (25 total across 895 dependencies: 449 prod / 316 dev / 131 optional)
**Direct vs transitive**: 0/1/2/0 direct of total 1/14/7/3 (CRITICAL/HIGH/MODERATE/LOW). The single CRITICAL is transitive (`tar`, pulled in by `supabase`); the one direct HIGH is `astro` itself.

#### CRITICAL findings

- **tar** `<=7.5.20` — transitive. node-tar applies PAX size override to intermediary GNU long-name/long-link headers, causing tar parser interpretation differential (file smuggling); node-tar: Process crash via PAX numeric path type confusion; node-tar: Decompression/parse DoS via unlimited input; node-tar: Negative tar entry size causes infinite loop in archive replace; node-tar: Uncaught Exception DoS via NUL byte in PAX path/linkpath records; node-tar: Uncontrolled recursion in mapHas/filesFilter allows uncatchable stack-overflow DoS via crafted long-path tar with member selection. Advisories: GHSA-vmf3-w455-68vh, GHSA-w8wr-v893-vjvp, GHSA-23hp-3jrh-7fpw, GHSA-8x88-c5mf-7j5w, GHSA-gvwx-54wh-qm9j, GHSA-r292-9mhp-454m. Fix: available via npm audit fix.

#### HIGH findings

- **astro** `<=7.0.9` — DIRECT. Astro: XSS via Unescaped Attribute Names in Spread Props; Astro: XSS via unescaped spread attribute names in renderHTMLElement (incomplete fix for CVE-2026-54298); Astro: Cross-site scripting via unescaped transition:* directive values on hydrated islands; Astro: Reflected XSS via unescaped View Transition animation properties; Astro: Host header SSRF in prerendered error page fetch; Astro: Reflected XSS via unescaped slot name. Advisories: GHSA-jrpj-wcv7-9fh9, GHSA-f48w-9m4c-m7f5, GHSA-7pw4-f3q4-r2p2, GHSA-4g3v-8h47-v7g6, GHSA-2pvr-wf23-7pc7, GHSA-8hv8-536x-4wqp. Fix: available via npm audit fix.
- **brace-expansion** `<=1.1.17 || 3.0.0 - 5.0.8` — transitive. brace-expansion: DoS via exponential-time expansion of consecutive non-expanding {} groups; brace-expansion: DoS via exponential-time expansion of consecutive non-expanding {} groups; brace-expansion: DoS via unbounded expansion length causing an out-of-memory process crash; brace-expansion: DoS via unbounded expansion length causing an out-of-memory process crash; brace-expansion: DoS via unbounded intermediate arrays, bypassing the CVE-2026-14257 mitigation; brace-expansion: DoS via unbounded intermediate arrays, bypassing the CVE-2026-14257 mitigation. Advisories: GHSA-3jxr-9vmj-r5cp, GHSA-3jxr-9vmj-r5cp, GHSA-mh99-v99m-4gvg, GHSA-mh99-v99m-4gvg, GHSA-rgw5-rvv9-x895, GHSA-rgw5-rvv9-x895. Fix: available via npm audit fix.
- **browserslist** `<=4.28.6` — transitive. Browserslist: Unbounded memory growth (no cache eviction) via distinct query results, leading to eventual OOM; Browserslist: Uncaught crash / prototype write via untrusted browserslist-stats.json custom stats (normalizeStats). Advisories: GHSA-c83g-rgw3-j3cx, GHSA-73wf-gq98-2v4g. Fix: available via npm audit fix.
- **devalue** `5.6.3 - 5.8.0` — transitive. Svelte devalue: DoS via sparse array deserialization. Advisories: GHSA-77vg-94rm-hx3p. Fix: available via npm audit fix.
- **fast-uri** `3.0.0 - 3.1.5` — transitive. fast-uri vulnerable to host confusion via literal backslash authority delimiter; fast-uri vulnerable to host confusion via backslash authority introducer; fast-uri vulnerable to host confusion via failed IDN canonicalization; fast-uri vulnerable to server-side request forgery via malformed IPv6 normalization; fast-uri vulnerable to server-side request forgery via repeated hostname percent-decoding; fast-uri vulnerable to host confusion via percent-encoded scheme normalization. Advisories: GHSA-v2hh-gcrm-f6hx, GHSA-7p8r-x3mc-p8w7, GHSA-4c8g-83qw-93j6, GHSA-f65p-4m7j-42xc, GHSA-fph4-wmhf-6fwf, GHSA-jqff-g426-hqxp. Fix: available via npm audit fix.
- **js-yaml** `4.0.0 - 4.3.0` — transitive. JS-YAML: Quadratic-complexity DoS in merge key handling via repeated aliases; js-yaml: YAML merge-key chains can force quadratic CPU consumption; JS-YAML: Quadratic CPU consumption in !!omap resolution (3.x and 4.x) — CVE-2026-59870 fix not backported. Advisories: GHSA-h67p-54hq-rp68, GHSA-52cp-r559-cp3m, GHSA-5p4m-2wfm-xmqj. Fix: available via npm audit fix.
- **miniflare** `<=0.0.0-fff677e35 || 3.20250204.0 - 5.20260801.0-alpha` — transitive. vulnerable dependency chain: sharp -> undici -> ws. Advisories: n/a. Fix: available via npm audit fix.
- **nanoid** `<=3.3.17` — transitive. nanoid: non-secure generators can loop indefinitely with negative size; nanoid: custom generators can loop indefinitely when size is zero. Advisories: GHSA-28wg-ghj8-5hjv, GHSA-2v37-7h3g-55p8. Fix: available via npm audit fix.
- **postcss** `<=8.5.22` — transitive. PostCSS: incomplete fix of GHSA-6g55-p6wh-862q — attacker-controlled sourceMappingURL reads arbitrary .map files when `from` is unset; PostCSS: Path Traversal in Previous Source Map Auto-Loading (sourceMappingURL) leads to Arbitrary .map File Disclosure. Advisories: GHSA-fxqj-rqcc-2cmp, GHSA-r28c-9q8g-f849. Fix: available via npm audit fix.
- **sharp** `<0.35.0` — transitive. sharp inherited vulnerabilities in libvips: CVE-2026-33327, CVE-2026-33328, CVE-2026-35590, CVE-2026-35591. Advisories: GHSA-f88m-g3jw-g9cj. Fix: available via npm audit fix.
- **svgo** `4.0.0 - 4.0.1` — transitive. SVGO removeScripts plugin leaves some executable scripts intact. Advisories: GHSA-2p49-hgcm-8545. Fix: available via npm audit fix.
- **undici** `7.0.0 - 7.28.0` — transitive. undici vulnerable to TLS certificate validation bypass via dropped requestTls in SOCKS5 ProxyAgent; undici vulnerable to HTTP header injection via Set-Cookie percent-decoding; undici WebSocket client vulnerable to denial of service via fragment count bypass; undici vulnerable to cross-origin request routing via SOCKS5 proxy pool reuse; undici vulnerable to Set-Cookie SameSite attribute downgrade via permissive substring matching; undici vulnerable to cross-user information disclosure via shared cache whitespace bypass; undici vulnerable to downstream response desynchronization via retry interceptor; undici vulnerable to cross-user information disclosure and parse-time crash via degenerate private cache directives; undici vulnerable to CRLF Injection via blob-like body 'type' property; undici vulnerable to cross-user information disclosure via whitespace around equals in Cache-Control directives; undici vulnerable to cookie attribute injection via unsanitized domain and unparsed setCookie fields; undici vulnerable to HTTP response queue poisoning via keep-alive socket reuse. Advisories: GHSA-vmh5-mc38-953g, GHSA-p88m-4jfj-68fv, GHSA-vxpw-j846-p89q, GHSA-hm92-r4w5-c3mj, GHSA-g8m3-5g58-fq7m, GHSA-pr7r-676h-xcf6, GHSA-8xcm-r25x-g524, GHSA-4cwx-7wf7-3272, GHSA-m8rv-5g2x-5cg5, GHSA-jr45-8vmc-qm54, GHSA-v3r7-h72x-cjcm, GHSA-35p6-xmwp-9g52. Fix: available via npm audit fix.
- **vite** `7.0.0 - 7.3.3` — transitive. launch-editor: NTLMv2 hash disclosure via UNC path handling on Windows; vite: `server.fs.deny` bypass on Windows alternate paths. Advisories: GHSA-v6wh-96g9-6wx3, GHSA-fx2h-pf6j-xcff. Fix: available via npm audit fix.
- **ws** `8.0.0 - 8.20.1` — transitive. ws: Uninitialized memory disclosure; ws: Memory exhaustion DoS from tiny fragments and data chunks. Advisories: GHSA-58qx-3vcg-4xpx, GHSA-96hv-2xvq-fx4p. Fix: available via npm audit fix.

#### MODERATE findings

- **@astrojs/language-server** `2.14.0 - 2.16.10` — transitive. vulnerable dependency chain: volar-service-yaml. Advisories: n/a. Fix: available via npm audit fix.
- **@cloudflare/vite-plugin** `<=0.0.0-fff677e35 || 0.0.7 - 1.41.0` — transitive. vulnerable dependency chain: miniflare -> wrangler -> ws. Advisories: n/a. Fix: available via npm audit fix.
- **supabase** `1.1.6 - 2.98.2` — DIRECT. vulnerable dependency chain: tar. Advisories: n/a. Fix: available via npm audit fix.
- **volar-service-yaml** `<=0.0.70` — transitive. vulnerable dependency chain: yaml-language-server. Advisories: n/a. Fix: available via npm audit fix.
- **wrangler** `<=0.0.0-kickoff-demo || 3.108.0 - 4.101.0` — DIRECT. vulnerable dependency chain: esbuild -> miniflare. Advisories: n/a. Fix: available via npm audit fix.
- **yaml** `2.0.0 - 2.8.2` — transitive. yaml is vulnerable to Stack Overflow via deeply nested YAML collections. Advisories: GHSA-48c2-rrv3-qjmp. Fix: available via npm audit fix.
- **yaml-language-server** `1.11.1-08d5f7b.0 - 1.21.1-f1f5a94.0 || 1.22.1-0ae5603.0 - 1.22.1-fc5f874.0` — transitive. vulnerable dependency chain: yaml. Advisories: n/a. Fix: available via npm audit fix.

#### LOW / INFO findings

- **@babel/core** `<=7.29.0` — transitive. @babel/core: Arbitrary File Read via sourceMappingURL Comment. Advisories: GHSA-4x5r-pxfx-6jf8. Fix: available via npm audit fix.
- **esbuild** `0.27.3 - 0.28.0` — transitive. esbuild allows arbitrary file read when running the development server on Windows. Advisories: GHSA-g7r4-m6w7-qqqr. Fix: available via npm audit fix.
- **postcss-selector-parser** `7.1.0 - 7.1.2` — transitive. postcss-selector-parser allows denial of service through uncontrolled AST recursion. Advisories: GHSA-w9m9-85wc-3x92. Fix: available via npm audit fix.
## Hints recorded but not acted on

| Hint                    | Value                 |
| ----------------------- | --------------------- |
| bootstrapper_confidence | first-class           |
| quality_override        | false                 |
| path_taken              | standard              |
| self_check_answers      | null                  |
| team_size               | solo                  |
| deployment_target       | cloudflare-pages      |
| ci_provider             | github-actions        |
| ci_default_flow         | auto-deploy-on-merge  |
| has_auth                | true                  |
| has_payments            | false                 |
| has_realtime            | false                 |
| has_ai                  | true                  |
| has_background_jobs     | false                 |

v1 reads these fields and preserves them here, but takes no automated action on any of them: no CI workflow generation, no auth/AI wiring, no deployment configuration beyond what the starter itself ships (`wrangler.jsonc`, `.github/`). The starter's own `deployment_defaults` already lead with `cloudflare-pages`, which matches the recorded target.

## Next steps

Next: a future skill will set up agent context (CLAUDE.md, AGENTS.md). For now, your project is scaffolded and verified — happy hacking.

Useful manual steps in the meantime:
- `git init` (if you have not already) to start your own repo history. This repo already had a `.git/`, which the conflict policy left untouched; the cloned starter history was deleted before move-up.
- Review the `.scaffold` siblings the conflict policy created and decide which version of each file to keep:
  - `diff CLAUDE.md CLAUDE.md.scaffold` — the starter ships its own agent-context file; the existing lesson-scoped `CLAUDE.md` won.
  - `diff README.md README.md.scaffold` — the starter's README documents the Astro/Supabase/Cloudflare layout.
- Copy `.env.example` to `.env` and fill in the Supabase and LLM provider credentials before running `npm run dev`.
- Address audit findings per your project's risk tolerance — the full breakdown is above. The direct `astro` HIGH advisories and the transitive `tar` CRITICAL both report a fix as available; `npm audit fix` is the starting point, but verify the Astro upgrade against the starter's pinned config before committing.
