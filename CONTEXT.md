# Context — nufi_app (Flutter client)

The domain glossary for the nufi health-tracking app. When code, an issue title, a
refactor, or a test names a domain concept, use the term as defined here — don't drift
to a synonym. If a concept you need isn't here, that's a signal: either you're inventing
language the project doesn't use, or there's a real gap worth adding.

The client is a thin front-end over a FastAPI backend (a separate repo). It owns
presentation, local caching, and notifications; the backend owns persistence and the AI.

## Core nouns

- **User** — an onboarded person. Identified by a `userId`; their `UserProfile` holds
  age, goals, and per-domain preferences captured during **onboarding**.
- **Tracker** — one health domain the user logs against. The eight trackers are:
  **meal, water, steps, sleep, exercise, supplement, period, weight**. Each has its own
  logging screen, history screen, and (mostly) a dashboard card.
- **Entry** — a single logged record for one tracker on one date (e.g. `WaterEntry`,
  `SleepEntry`). Most trackers are one-entry-per-day (upsert by date); meals and
  exercises can have several per day. "Log" (verb) = create or update an entry.
- **Daily Snapshot** — a user's assembled data across all trackers for a single date,
  owned by `DailySnapshot.forDay(userId, date)` and modelled by `DaySnapshot`. Prefer
  **Daily Snapshot** over "metrics", "today's data", or "summary". `MetricsService` is
  gone. See [ADR-0002](docs/adr/0002-daily-snapshot-module.md) and
  [ADR-0006](docs/adr/0006-migrate-dailysnapshot-onto-the-endpoint.md).
  - **It is the owner's day**, every entry regardless of `sharedWithChat` — not the
    shared subset the coach sees, which is a different backend read. Same data, two
    interfaces; do not conflate them.
  - **One backend call.** It used to fan out across seven endpoints, one of which read
    the user's entire weight history and scanned it client-side. It now reads
    `GET /daily-snapshot/{user_id}/{date}`; the interface did not change, which is what
    it was for.
  - **Three states per section**, carried by `Section` / `SectionStatus`: `ok`,
    `missing` (nothing logged), `error` (that tracker's read failed). The backend omits
    a section for `missing` and names it in `_read_errors` for `error`. Keeping these
    apart is the point — a failed read rendered as an empty day is a lie about the
    user's data.
  - **Two consumers: `today_report_screen` and `dashboard_home`.** The dashboard was
    wired to it in F1 and removed again in `e918b74` (it fed a write-only map), then
    wired properly in [ADR-0007](docs/adr/0007-dashboard-reads-the-day-once.md): the
    dashboard reads the day **once** and its today-data cards (meals, water, steps,
    exercise-today, sleep-today) derive from that one `Future<DaySnapshot>`, re-deriving
    when the dashboard swaps in a new one. Five requests became one. Supplements never
    fetched; period, exercise-week and sleep-yesterday are different questions and stay
    their own reads.
- **Coach** — the AI chat assistant (user-facing name is "coach"; code says `chat` /
  `ChatApi`). The coach answers using **chat context** built from the user's shared data.
- **Chat context** — the digest of a user's recent tracker data (daily and weekly) that
  is fed to the coach. Assembled backend-side; the client reads and displays it.
- **Shared with chat** — a per-entry privacy flag (`sharedWithChat`). An entry hidden
  from the coach is excluded from chat context. User-facing labels: "Share with coach" /
  "Hide from coach".
- **Report** — a read-only rollup for a period: the **today report**
  (`today_report_screen`) and the **weekly summary** (`weekly_summary_screen`).

## Data access vocabulary (the architecture work touches this)

- **Api** — a per-tracker HTTP client under `lib/data/services/api/` (`MealApi`, …).
  This is the live seam to the backend, and the one adapter that actually runs.
- **Repository** — a `lib/data/repositories/` type. These were once shaped for two
  adapters, the `Api` and a direct-Postgres `DatabaseService`; the Postgres path was dead,
  so [ADR-0001](docs/adr/0001-collapse-repository-seam.md) collapsed the pass-through ones
  into their `Api`. What survives is the shape worth keeping: **a deep module hiding an
  `Api` plus `SharedPreferences`**. There are three — `StepRepository`, `SleepRepository`
  and `SessionRepository`. Everything else calls its `Api` directly.
- **Session** — who is signed in: the cached `UserProfile`, the user id, and the
  signed-in flag. Owned by `SessionRepository`, which is the **only** writer of those
  three `SharedPreferences` keys, so "a cached profile implies signed-in" holds by
  construction rather than by callers pairing two writes. Its three write operations are
  `startSession` (login and onboarding), `cacheProfile` (refresh an existing session's
  profile) and `endSession`. `DataManager` and `UserManager`, which used to share this
  concern and disagreed about it, are gone. See
  [ADR-0005](docs/adr/0005-session-repository.md).
  - **Ending a session is not deleting an account.** `endSession` clears the three
    session keys and nothing else — the theme, the step-accrual baseline, the chat cache
    and supplement preferences all survive a logout. Account deletion wipes local state
    wholesale, and that is deliberate.

## Conventions

- **Emerging vs. established terms.** Terms marked *(emerging term)* name a concept the
  code re-derives in several places but hasn't yet given a module. Once the architecture
  work lands the module, drop the marker.
- Architecture vocabulary (module, interface, seam, adapter, depth, leverage, locality)
  lives in the design skill, not here. This file names the *domain*; that file names the
  *shapes*.
