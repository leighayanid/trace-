# TRACE — Implementation Plan

> Build. Read. Explore. Live.
> Stack: Flutter 3.47.x · Drift (local SQLite, source of truth) · Neon Postgres (sync target)

---

## 0. Environment reality check

| Item | Status |
|---|---|
| `C:\Users\leigh\Web\trace` | empty except `CLAUDE.md` — greenfield |
| Flutter SDK | installed at `C:\Users\leigh\flutter\flutter\bin` — **not on PATH** |
| Flutter version | **3.44.6** stable (Dart 3.12.2) — three releases behind |
| Target version | **3.47.2** stable (Dart 3.13.x) |
| Git repo | not initialised |

**First actions:**

1. Add `C:\Users\leigh\flutter\flutter\bin` to the user PATH — it is currently absent from the
   user, machine, and session scopes, so `flutter` resolves in no shell.
2. `flutter upgrade` on the stable channel: 3.44.6 → 3.47.2. Required, because the pinned
   `sdk: ^3.13.0` constraint below is not satisfiable on Dart 3.12.2.
3. `flutter doctor` — confirm the Android toolchain and licences.
4. `git init`.

---

## 1. The one architectural decision that matters

**A Flutter app cannot hold Neon Postgres credentials.** An APK is trivially decompiled; a
`postgresql://user:password@ep-xxx.neon.tech/neondb` string inside the binary is a public
credential. The `postgres` Dart package over raw TCP is therefore off the table for anything
beyond a throwaway single-device build.

Neon's answer is the **Data API** — a PostgREST-compatible HTTPS endpoint sitting in front of
your database, where every request carries a user JWT and **Row Level Security** decides what
that user can see. Dart talks to it with the `postgrest` package (PostgREST is a wire protocol,
not a JS thing).

### Chosen architecture: local-first, sync-on-top

```
┌─────────────────────────── Flutter app ───────────────────────────┐
│                                                                   │
│  UI (Riverpod)  ─reads/writes─▶  Repository  ─▶  Drift / SQLite   │
│                                                     │  (truth)    │
│                                                     ▼             │
│                                              Outbox + cursor      │
└─────────────────────────────────────────────────────┼─────────────┘
                                                      │ HTTPS + JWT
                                                      ▼
                                         Neon Data API (PostgREST)
                                                      │  RLS
                                                      ▼
                                            Neon Postgres
```

**The UI never awaits the network.** Every write lands in SQLite and returns immediately; a
background sync worker reconciles with Neon when connectivity allows. This is what makes
CLAUDE.md's "view today, add, edit, timeline, reading, projects — all offline" true rather than
aspirational, and it is why reads feel instant.

### Rejected alternatives

| Option | Why not |
|---|---|
| `postgres` package direct from device | ships DB credentials in the binary |
| Custom Dart Frog / Serverpod API | a whole second service to write, deploy and pay for; the Data API already is that service |
| Cloud-only (no local DB) | breaks the offline requirement; every screen becomes a spinner |

### Auth staging

**TRACE has exactly one user: Leigh.** This is not a multi-tenant product and never will be.
That removes a whole category of work — there is no sign-up flow, no password reset, no email
verification, no account settings, no user management. One account, created once out-of-band,
signed into once per device.

What it does *not* remove is auth itself. The Data API URL is a public internet endpoint; the
JWT is the only thing standing between a stranger and your data, and RLS is what makes a leaked
or expired token useless. Single-user means *less UI*, not *less security*.

CLAUDE.md: *"Never require an account merely to use basic tracking."* So:

- **Phase 1–3 — no account at all.** Pure local Drift. The app is fully usable and ships.
- **Phase 4 — sign-in is opt-in**, presented as "turn on sync", not as a gate. One screen: email,
  password, done.

**Decided: Neon Auth (managed Better Auth).** One vendor, one dashboard, no Firebase. The
`neon.ts` config stays minimal:

```ts
// neon.ts
import { defineConfig } from "@neondatabase/config/v1";
export default defineConfig({ auth: true, dataApi: true });
```

The cost of this choice is that **there is no Dart SDK**, so `core/auth/` is code we own. It is
a small, well-understood surface — roughly:

| Piece | What it does |
|---|---|
| `NeonAuthClient` | `http` calls to the Better Auth email sign-up / sign-in endpoints |
| Token exchange | trades the session for the JWT the Data API validates |
| `TokenStore` | persists tokens in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) |
| Refresh guard | decodes `exp` with `jose`, refreshes ahead of expiry, single-flights concurrent refreshes |
| Interceptor | injects `Authorization: Bearer <jwt>` into every `postgrest` request |

Budget ~250 lines plus tests. **Exact endpoint paths and the session→JWT exchange must be read
off the live Neon Auth docs at the start of Phase 4** — they are not pinned here, because
guessing them now would bake in something plausible and wrong.

Because this is hand-rolled, two rules are not optional: never log a token, and never persist
one outside `flutter_secure_storage`.

---

## 2. Stack and pinned versions

**Empirically resolved, not guessed.** Every version below came from a throwaway probe project
built against the actual installed SDK (Flutter 3.44.6 / Dart 3.12.2); `flutter analyze` reports
no issues on the result. No prereleases.

```yaml
environment:
  sdk: ^3.12.2                 # matches installed Dart; NOT ^3.13.0

dependencies:
  flutter: { sdk: flutter }

  # state
  flutter_riverpod: ^3.4.3
  riverpod_annotation: ^4.0.7

  # persistence (local source of truth)
  drift: ^2.35.0
  drift_flutter: ^0.3.1        # pulls sqlite3_flutter_libs itself — do not declare it directly
  path_provider: ^2.1.6

  # navigation
  go_router: ^18.0.1

  # motion
  flutter_animate: ^4.5.2
  animations: ^3.0.0           # official Material motion: shared axis, fade-through

  # serialisation
  json_annotation: ^4.12.0

  # sync + auth (phase 4)
  postgrest: ^2.9.1            # speaks to the Neon Data API
  http: ^1.6.0                 # hand-rolled Neon Auth client
  jose: ^0.3.5+2               # decode JWT `exp` for refresh-ahead
  connectivity_plus: ^7.3.1
  flutter_secure_storage: ^11.1.0

  # misc
  uuid: ^4.6.0
  intl: ^0.20.2

dev_dependencies:
  flutter_test: { sdk: flutter }
  build_runner: ^2.15.1
  drift_dev: ^2.35.0
  riverpod_generator: ^4.0.9
  json_serializable: ^6.14.1
  flutter_lints: ^6.0.0
```

### Three consequences of staying on Flutter 3.44.6

**1. No `riverpod_lint`, no `custom_lint`.** `riverpod_lint >=3.1.9` requires Dart `>=3.13.0`;
every older version demands `freezed_annotation ^2.2.0`, and `custom_lint` on this SDK pins
`analyzer ^8`, while `riverpod_generator 4.0.9` needs `analyzer >=13 <15`. The two cannot
coexist here. **Codegen is unaffected** — `riverpod_generator` works fine. What is lost is the
Riverpod-specific lint rules. `flutter_lints ^6.0.0` still applies. This is the real price of
the decision, and it is a modest one.

**2. `freezed` is dropped entirely** — and this is an improvement, not a concession. On this SDK
`freezed_annotation ^3.1.0` resolves only to the prerelease `freezed 4.0.0-dev.3`, while stable
`freezed 3.x` needs `source_gen ^2` against `json_serializable`'s `source_gen ^4`. Rather than
ship a dev-channel code generator, cut the package: **Drift already generates immutable data
classes** with `copyWith`, `==` and `hashCode`, and Dart 3 has native `sealed` classes with
exhaustive pattern matching for the handful of unions this app needs (`ParsedEntry`,
`SyncStatus`). That is one fewer codegen step and less ceremony — exactly what CLAUDE.md asks
for.

**3. Upgrading later is cheap.** Nothing above is a dead end. When you move to 3.47.x, bump
`sdk` to `^3.13.0` and add `riverpod_lint` + `custom_lint` back. No application code changes.

**Fonts are bundled as assets, not fetched via `google_fonts`.** An offline-first app must not
wait on a CDN to render its first frame. Ship Inter (Regular/Medium/SemiBold) and IBM Plex Mono
(Regular/Medium) in `assets/fonts/`.

**Deliberately excluded:** Lottie, Rive, confetti, any charting library. The two charts in the
design (donut, consistency dots) are ~120 lines of `CustomPainter` each, and a dependency would
impose its own visual language on a design system this specific.

---

## 3. Project structure

Feature-first, per CLAUDE.md.

```
lib/
  main.dart
  app/
    app.dart                    # MaterialApp.router + theme wiring
    router.dart                 # GoRouter, StatefulShellRoute for the 5-tab shell
    theme/
      colors.dart               # TraceColors — light + dark token sets
      typography.dart           # TraceText — the full type scale
      spacing.dart              # TraceSpace — 4pt grid
      theme.dart                # ThemeData assembly + ThemeExtension
      motion.dart               # TraceMotion — durations + curves, single source

  core/
    database/
      database.dart             # @DriftDatabase
      tables/                   # entries, projects, books, notes, proofs, sync_state
      daos/
      converters/
    auth/
      neon_auth_client.dart     # hand-rolled Better Auth HTTP client
      token_store.dart          # flutter_secure_storage persistence
      session_controller.dart   # refresh-ahead + single-flight guard
    sync/
      sync_engine.dart          # push outbox → pull cursor → resolve
      data_api_client.dart      # PostgrestClient wrapper + JWT injection
      sync_status.dart          # sealed class, not freezed
    parser/
      entry_parser.dart         # natural language → ParsedEntry
      duration_grammar.dart
      quantity_grammar.dart
    utils/

  features/
    splash/
    today/
    entries/                    # quick add sheet + add/edit entry form
    timeline/
    projects/
    reading/
    insights/
    settings/

  shared/
    widgets/
      trace_scaffold.dart
      category_glyph.dart       # the rounded icon tile
      entry_row.dart            # used by Today AND Timeline — build it once
      progress_track.dart       # used by Presence, Project, Reading
      section_label.dart        # the tiny letterspaced caps label
      trace_button.dart         # filled / outlined / text
      mono_duration.dart        # 02:34 with the tween ticker
      trace_nav_bar.dart
    models/

assets/
  fonts/
  images/splash.jpg
```

`entry_row.dart` and `progress_track.dart` each appear on three or more screens in the mockup.
Getting those two widgets exactly right is most of the visual work.

---

## 4. Data model

### Drift tables (local)

Every syncable table carries the same sync tail.

```dart
// Shared by entries, projects, books, notes
TextColumn     get id        => text()();                   // UUID v7, client-generated
DateTimeColumn get createdAt => dateTime()();
DateTimeColumn get updatedAt => dateTime()();               // drives last-write-wins
DateTimeColumn get deletedAt => dateTime().nullable()();    // tombstone, never hard-delete
BoolColumn     get dirty     => boolean().withDefault(const Constant(true))();
DateTimeColumn get syncedAt  => dateTime().nullable()();
```

**Entries**

```
category      TEXT     -- build | read | explore | life
title         TEXT
description   TEXT?
date          DATE     -- the day it belongs to (local), separate from createdAt
startedAt     DATETIME?
endedAt       DATETIME?
durationSecs  INT?
quantity      REAL?
quantityUnit  TEXT?    -- minutes|hours|pages|km|sessions|items|custom
projectId     TEXT?    -> projects.id
bookId        TEXT?    -> books.id
tags          TEXT     -- JSON array
```

Duration and quantity are both nullable and independent — CLAUDE.md: *"An entry may use
duration, quantity, or neither. Do not force every entry into a duration."*

**Projects** — `name, description, status(active|paused|done|archived), startedAt, endedAt`.
No `totalTrackedTime` column: total time is a `SUM(durationSecs)` view over entries. Storing it
would be the duplicated-derived-data mistake CLAUDE.md calls out.

**Books** — `title, author, coverPath, currentPage, totalPages, status, startedAt, finishedAt`.

**Notes** — `body, dayDate?, entryId?, projectId?, bookId?, kind(one_line|thought|quote|note)`.
The ONE LINE on Today is a Note with `kind: one_line` and a `dayDate` — not a separate table.

**Proofs** — `entryId, kind(git|screenshot|note|link|file), label, uri`.

**SyncState** — single row: `lastPullCursor, lastPushAt, lastError`.

### Postgres (Neon) — phase 4

Mirrors the Drift schema, plus `user_id`, minus the local-only `dirty` / `synced_at` columns.

```sql
create table entries (
  id            uuid primary key,
  user_id       uuid not null,
  category      text not null check (category in ('build','read','explore','life')),
  title         text not null,
  description   text,
  date          date not null,
  started_at    timestamptz,
  ended_at      timestamptz,
  duration_secs integer,
  quantity      numeric,
  quantity_unit text,
  project_id    uuid references projects(id) on delete set null,
  book_id       uuid references books(id) on delete set null,
  tags          jsonb not null default '[]',
  created_at    timestamptz not null,
  updated_at    timestamptz not null,   -- client-supplied; do NOT override with a trigger
  deleted_at    timestamptz
);

alter table entries enable row level security;

create policy entries_owner on entries
  for all
  using      (user_id = auth.user_id())
  with check (user_id = auth.user_id());

create index entries_sync_idx on entries (user_id, updated_at);
create index entries_date_idx on entries (user_id, date desc);
```

`updated_at` is **written by the client, never by a database trigger**. Last-write-wins needs the
timestamp to represent when the user made the edit on their device, not when the row happened to
reach the server.

---

## 5. Sync protocol

Per-row last-write-wins reconciliation. For one user across two or three of their own devices
this is correct and boring, which is what you want; CRDTs would be ceremony.

**Push** — `where dirty = 1`, batched 200 rows, `POST` with
`Prefer: resolution=merge-duplicates` (PostgREST upsert). On 2xx, set `dirty = 0,
syncedAt = now()`.

**Pull** — `GET /entries?updated_at=gt.<cursor>&order=updated_at.asc&limit=500`, paging until
short. For each remote row: if a local row is `dirty` and its `updatedAt` is newer, **keep local**
and leave it queued; otherwise upsert remote. Advance the cursor to the last `updated_at`
received.

**Deletes** are tombstones. `deleted_at` propagates like any other field; the UI filters on
`deleted_at IS NULL`. A local vacuum purges tombstones older than 90 days once they have synced.

**Triggers** — on app resume, on connectivity regained, after a write settles (debounced 5s), and
on manual pull-to-refresh in Settings.

**Failure is silent by design.** A sync error sets `SyncState.lastError` and surfaces only as a
muted line in Settings. No red banners, no retry modals — CLAUDE.md's "quiet" applies to error
states too.

**Clock skew** is the known weakness of LWW. Mitigate by clamping any client `updated_at` more
than 5 minutes ahead of server time.

---

## 6. Design system

Exact tokens from CLAUDE.md, read against the mockup.

```
              Light        Dark
bg            #F8F8F6      #0B0D10
surface       #FFFFFF      #14171C
textPrimary   #111111      #F5F5F2
textSecond    #6B6B6B      #858991
border        #E4E4E1      #242830
navy          #0B1F3A      #18365A
navyLight     #E8EDF3      #16233A
```

Navy is load-bearing in exactly four places in the mockup: the primary button fill, the nav bar's
centre `+`, progress-track fills, and the category glyph tiles. Everywhere else is monochrome.
Resist adding a fifth.

### Type scale

| Role | Font | Size / weight / tracking |
|---|---|---|
| Splash wordmark | Inter | 28 · w300 · **+12 tracking** |
| Screen title (`Add Entry`, `Timeline`) | Inter | 28 · w600 · −0.5 |
| Greeting name (`Leigh.`) | Inter | 32 · w600 · −0.8 |
| Greeting line (`Good evening,`) | Inter | 17 · w400 · secondary |
| Section label (`TODAY`, `PRESENCE`) | Inter | 11 · w600 · **+1.6** · uppercase · secondary |
| Category label (`BUILD`) | Inter | 12 · w600 · +0.8 · uppercase |
| Row subtitle | Inter | 13 · w400 · secondary |
| **Duration / stat** | **IBM Plex Mono** | 13 · w500 · tabular figures |
| Book title (Reading) | Inter | 20 · w600 · −0.4 |
| Quote | Inter | 15 · w400 · *italic* |
| Body | Inter | 15 · w400 · 1.5 line height |

The mono/sans split is the whole visual identity: **every number is mono, every word is sans.**
Enable `FontFeature.tabularFigures()` on the mono style so `02:34` does not jitter when it
animates.

### Space and shape

4pt grid. Screen gutter 20. Section gap 28. Row vertical padding 14. Card radius 12, button
radius 10, glyph tile radius 8, chip radius 999. Hairlines are 1 physical pixel in `border`.

**No elevation anywhere.** The mockup has no shadows; separation comes from hairlines and
whitespace. A single stray `Card` default elevation will read as a different app.

---

## 7. Screen build order and specs

Matched line-by-line to the mockup.

### 7.1 Splash
Full-bleed dark mountain photograph. `T R A C E` centre-left with wide tracking, `Build. Read.
Explore. Live.` beneath in muted white. Bottom-left: a short 24pt rule, then *A quiet record / of
what you do.* over two lines. Holds ~1.2s, then fade-through to Today.

### 7.2 Today  *(the most important screen)*
`T R A C E` tracked caps top-left; `Thu, Sep 10` + calendar glyph top-right. `Good evening,` /
`Leigh.` — greeting switches on hour. `TODAY` label. Then four `EntryRow`s: rounded navy-tint
glyph tile (`</>`, book, globe, life mark), category caps, subtitle in grey, mono duration
right-aligned, chevron. Full-width navy `+ Add entry`. `PRESENCE` label with `78%` right, over a
3pt track. `ONE LINE` label and the sentence with a chevron.

> **Define Presence before building it.** CLAUDE.md forbids fake productivity scores. Presence
> must be an honest, explainable ratio — proposal: *categories touched today ÷ 4*, so four entries
> across four categories = 100%. It measures the breadth of a day, not achievement. If it cannot
> be stated in one sentence on the Settings screen, cut it. **Your call (§11).**

### 7.3 Quick Add
Full-screen navy sheet. `×` top-left. `What did you do?` / `Just type it. I'll figure it out.`
Rounded input, placeholder `e.g. coded for 2 hours on pds express`. `QUICK SUGGESTIONS` and six
outlined pills: Coded on a project · Read a book · Browsed the web · Went for a walk · Slept ·
Other. White `Continue`. Keyboard-first: autofocus, `TextInputAction.done` submits.

**The parser is on-device and deterministic** — regex grammars for duration (`2 hours`, `2h`,
`34m`, `1h30`), quantity (`27 pages`, `3.2 km`), category keywords, and a fuzzy match of the
remainder against known project and book names. No network, no LLM, works offline, and CLAUDE.md
wants AI invisible. A cloud fallback for unparsed input can come much later, if ever.

### 7.4 Add Entry (confirmation)
`<` back, `Save` navy right. `Add Entry`. Category row (`</> Build` + chevron). Then labelled
rows: `Project` → PDS Express, `Duration` → 2h 34m. `Note (optional)` multiline box. `Proof
(optional)`: Git commit · Screenshot · Note, each icon + chevron. Every parsed field is editable
before saving — the parser proposes, it never decides.

### 7.5 Timeline
`Timeline` title + calendar glyph. `< September 2026 >` stepper. Day blocks with a left gutter
carrying the day number over the weekday (`10` / `Thu`), and the day's entry rows to the right.
Lazy `SliverList` grouped by day, paging backwards.

### 7.6 Project detail
`<` and `…`. `PDS Express` / `Personal Data Sheet Generator`. `Active` pill on navy-light.
Progress track + `78%`, `47h 31m total time`. `Recent Sessions` — four dated rows with mono
durations, then `View all sessions`. Navy `Open Project`. Footer: `</>` and the description.

> Show the 78% only when the project has a user-defined target. Otherwise show tracked time alone
> — CLAUDE.md is explicit that invented percentages are not to be presented as meaningful.

### 7.7 Reading detail
`READING` label. Cover thumbnail left, `The Design of Everyday Things` / `Don Norman` right.
Progress track + `58%`. `214 / 368 pages`. `Last read` → `Today · 21:15`. `Current thought` →
italic quote. `Today` → `27 pages`. Outlined `View notes`.

### 7.8 Insights
`Insights`. Segmented `This Month | This Year`, navy pill on a grey track. `CONSISTENCY` /
`September`: four rows (Build/Read/Explore/Life), each a run of small dots — filled for a day
present, hollow for absent — with `16 days` right-aligned. `TIME SPENT`: donut with `78h / Total`
centred, legend right at 32/21/27/20%. `QUICK STATS`: 3 Projects · 14 Books · 183 Topics.

### 7.9 Nav bar
`Today · Timeline · [+] · Projects · More`. Thin glyphs, active in primary text, inactive in
secondary. The centre `+` is a navy filled circle, ~44pt — prominent, not oversized.

---

## 8. Animation catalogue

Advanced, but calm — every one of these is a *transition between states*, never idle decoration.
Central `TraceMotion` tokens so nothing is ad-hoc:

```dart
const fast   = Duration(milliseconds: 180);   // taps, toggles
const base   = Duration(milliseconds: 280);   // sheets, page transitions
const slow   = Duration(milliseconds: 520);   // charts, progress draws
const enter  = Curves.easeOutExpo;
const exit   = Curves.easeInCubic;
const spring = Curves.easeOutBack;            // used almost nowhere
```

| # | Where | What |
|---|---|---|
| 1 | Splash | Background scale 1.08 → 1.00 over 1.2s (slow parallax settle); `TRACE` letterSpacing tweens 18 → 12 as it fades in; tagline follows at +200ms |
| 2 | Splash → Today | `FadeThroughTransition` from `animations`, not a slide |
| 3 | Today entry list | Staggered reveal — fade + 12px slide up, 45ms per row, `flutter_animate` |
| 4 | Presence bar | Track fills 0 → 78% on `slow`/`enter`; the `78%` label counts up in step via a mono ticker |
| 5 | Duration values | `TweenAnimationBuilder<Duration>` ticker so `02:34` counts rather than pops; tabular figures keep the width stable |
| 6 | Nav `+` | Rotates 0 → 45° into a `×` as the Quick Add sheet opens, driven by the *same* controller as the sheet |
| 7 | Quick Add open | Navy sheet rises with `easeOutExpo` + a backdrop blur ramping 0 → 12σ; suggestion chips stagger in at 30ms |
| 8 | Parse → confirm | The raw sentence dissolves upward and the structured `BUILD / PDS Express / 2h 34m` card resolves in its place — `AnimatedSwitcher` with a shared-axis vertical transition. This is the app's signature moment; spend time here |
| 9 | Save confirmation | A hairline sweeps left→right under the Save row, then the sheet dismisses. No checkmark bounce, no confetti |
| 10 | Row → detail | `Hero` on the glyph tile and title, paired with a container-transform-style page route (project row → Project screen, book → Reading) |
| 11 | Timeline scroll | Day-gutter numbers pin and fade as their block scrolls under the header |
| 12 | Timeline month change | Shared-axis horizontal, direction following the arrow pressed |
| 13 | Insights donut | `CustomPainter` sweeping each arc in sequence over `slow`, 40ms apart; the centre `78h` ticks up alongside |
| 14 | Consistency dots | Ripple in left→right, 18ms per dot, row after row — reads as the month being written out |
| 15 | Reading progress | Track animates on entry; on logging pages it animates *from the previous value*, so progress is visibly felt |
| 16 | Tab switches | `FadeThroughTransition` throughout — no horizontal sliding between tabs |
| 17 | Press feedback | Uniform 0.98 scale on `fast`, plus `HapticFeedback.selectionClick()` on save and tab change |

Everything runs on the Impeller-accelerated path; nothing here needs a shader warm-up. Charts must
be `RepaintBoundary`-wrapped so their animation does not repaint the scroll view.

---

## 9. Phased delivery

> **Status — 2026-09-10**
> - **Phase 0: complete.** Analyze clean, debug APK built.
> - **Phase 1: complete.** Drift schema generated, parser at 21 passing tests,
>   Quick Add + Add Entry + Today wired to live SQLite.
> - **Phase 2: complete.** Timeline, Projects (+ creation), Reading (+ books and
>   session logging), Insights with both custom-painted charts, More, About.
> - **Phase 3: complete** except for on-device profiling, which needs hardware.
>   Catalogue items 1–10 and 12–17 are implemented. Item 11 (Timeline gutter
>   pinning) is **not** built: it needs a sliver rewrite of the day list for a
>   small gain, and was judged not worth the structural churn yet.
> - **Phase 4: code complete, UNVERIFIED against a live Neon project.** Schema +
>   RLS migration, hand-rolled Neon Auth client, session controller with
>   refresh-ahead and single-flight, Data API client, sync engine, and an opt-in
>   Sync screen. Conflict resolution has 13 tests. **Nothing here has spoken to a
>   real server.** See the checklist below before trusting it.
> - Next: **Phase 5** (export, delete-all, icons, release config).
>
> ### Phase 4 verification checklist — do this first
>
> The load-bearing unknown: Neon controls the plugin configuration of its managed
> Better Auth, so whether `set-auth-token` actually comes back on sign-in could
> not be confirmed without a project. Settle it with three curls, not by reading
> the Dart:
>
> ```bash
> # 1. Does sign-in return a session token in a header?
> curl -i -X POST "$NEON_AUTH_BASE_URL/api/auth/sign-up/email" \
>   -H 'Content-Type: application/json' \
>   -d '{"email":"...","password":"...","name":"Leigh"}'
> #    inspect response headers for `set-auth-token`
>
> # 2. Does the session token exchange for a JWT?
> curl -s "$NEON_AUTH_BASE_URL/api/auth/token" \
>   -H "Authorization: Bearer $SESSION_TOKEN"
>
> # 3. Does that JWT satisfy RLS?
> curl -s "$DATA_API_URL/entries?select=*" -H "Authorization: Bearer $JWT"
> ```
>
> If step 1 returns only `Set-Cookie`, the client needs a cookie jar rather than
> a bearer header — a materially different design. `NeonAuthClient` throws a
> message saying exactly that rather than failing vaguely.
>
> Also unverified, and needing two real devices: tombstone propagation,
> simultaneous offline edits of one row, and a cold-start pull of a large
> history.
>
> Known gap: `Conflict.clampToServer` is tested but **unwired**. It needs a real
> server clock, and PostgREST does not surface the response `Date` header through
> the Dart package. Until then a device with a badly wrong clock can win every
> conflict.
>
> ### Deviations from the mockup, all deliberate
>
> - **"Open Project" button removed** from the project detail screen. There is no URL or path
>   on a project to open, so the button would do nothing. Add a `url` field later if you want it
>   back.
> - **Proof capture not built** (§7.4). Git and screenshot capture need real integrations, and a
>   row that does nothing is worse than no row.
> - **Book covers are a typographic tile**, not an image. Covers need fetching or a file picker;
>   neither exists yet, and a broken image frame is worse than an initial on navy.
> - **Category colours in the donut are one navy stepped through four opacities**, not four
>   hues — the brief rules out bright per-category colour.
> - **"View all sessions" and "View notes" are inert.** They are visible because the counts they
>   report are real, but the destination screens are Phase 3+.
>
> ### Known cleanups
>
> - `riverpod_generator` / `riverpod_annotation` are installed but unused — providers are
>   hand-written to avoid a `build_runner` run per provider edit. Adopt or remove; do not leave
>   it undecided forever.
> - Four sheets (`NewProjectSheet`, `NewBookSheet`, `OneLineSheet`, `LogReadingSheet`) now
>   duplicate the same container and field styling. Four is where extraction into a shared
>   `SheetScaffold` + `TraceField` earns its keep.
> - `TodayScreen._edit` fabricates a `ParsedEntry` from a stored row to reuse the form. It works,
>   but a proper draft type would be honest.

**Phase 0 — Foundation.** Install Flutter 3.47.2, `flutter create`, `git init`, bundle fonts, build
the full theme (`colors/typography/spacing/motion`), GoRouter `StatefulShellRoute` with the five
tabs, and the shared widget kit (`EntryRow`, `ProgressTrack`, `SectionLabel`, `CategoryGlyph`,
`TraceButton`, `MonoDuration`, `TraceNavBar`). Splash screen ships here.
*Exit: the nav shell runs with placeholder bodies and pixel-correct chrome.*

**Phase 1 — Capture loop.** Drift schema + DAOs + repositories + Riverpod providers. Today screen
against real data. Quick Add sheet, the parser, Add Entry confirmation, edit and delete.
*Exit: you can log a real entry in under five seconds and it survives a restart.*

**Phase 2 — The other screens.** Timeline, Projects (list + detail), Reading (list + detail +
log-reading), Insights with both custom-painted charts, Settings, ONE LINE.
*Exit: every screen in the mockup exists and is driven by real local data.*

**Phase 3 — Motion pass.** Implement the catalogue in §8 end to end, then profile: 120fps on a
120Hz panel, no jank on the Timeline scroll. Dark theme audited screen by screen.
*Exit: the app feels like the mockup, not merely like a copy of it.*

**Phase 4 — Neon.** Create the project, apply the schema and RLS policies, enable the Data API,
wire the chosen IdP, build `SyncEngine` + `DataApiClient`, add the opt-in sync toggle in Settings.
Test the hard cases: two devices offline editing the same entry, tombstone propagation, cold-start
pull of a large history.
*Exit: install on a second device, sign in, and the history is there.*

**Phase 5 — Living with it.** JSON/CSV export, delete-all-data, Presence explainer, iOS/Android
release config, icons and splash, store metadata.

Phases 0–3 ship a complete, genuinely useful app with no account and no server. That ordering is
deliberate: it means Neon can slip without blocking anything.

---

## 10. Non-negotiables while building

- No shadows. No gradients. No fifth use of navy.
- Every number in IBM Plex Mono with tabular figures; every word in Inter.
- No streaks, badges, confetti, or motivational copy — CLAUDE.md's anti-pattern list is a hard
  constraint, not a style preference.
- Missing days render as absence, never as failure. `18 of 22 days`, never `18-day streak`.
- Derived values (project totals, reading progress, insight percentages) are computed from
  entries, never stored twice.
- Nothing on a core screen awaits the network.

---

## 11. Decisions made and questions still open

### Settled

- **Auth: Neon Auth (managed Better Auth).** One vendor; `core/auth/` is hand-rolled Dart (§1).
- **SDK: stay on Flutter 3.44.6 / Dart 3.12.2.** Dependencies re-pinned and verified (§2).
- **No `freezed`** — Drift data classes plus Dart 3 `sealed` classes cover it (§2).

### Still open

1. **Presence formula.** Is `categories touched today ÷ 4` right, or do you have another
   definition? *Blocks the Today screen (Phase 1).*
2. **Platforms.** Android only, or Android + iOS? *Affects Phase 0 scaffolding and all of
   Phase 5.* The probe was created with both.
3. **Splash photograph.** Do you have that mountain image, or should I source a substitute?
   *Blocks Phase 0 finish.*
4. **Project percentages.** Confirm they appear only when you have set a target for the project,
   and that tracked time alone shows otherwise.
