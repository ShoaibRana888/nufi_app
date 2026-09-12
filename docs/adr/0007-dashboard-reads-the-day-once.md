# 7. The dashboard reads the day once; the today-data cards derive from it

Date: 2026-09-13
Status: Accepted

## Context

[ADR-0006](0006-migrate-dailysnapshot-onto-the-endpoint.md) left the dashboard's
compact trackers self-fetching, one request each, as "the larger remaining win and its
own decision". This is that decision. The inventory before it changed the premise.

**Not all six trackers fetch the day.** `CompactSupplementsTracker` reads only
`SharedPreferences` — no network at all. `CompactPeriodTracker` reads twelve months of
cycle history, which `DaySnapshot` does not carry (it has no period section, per the
contract). Two of the six were never candidates.

**Two of the remaining four ask a second question the day cannot answer.**
`CompactExerciseTracker` also reads the week (`weekStart..today`) for its weekly count
and muscle groups. `CompactSleepTracker` falls back to *yesterday* when today has no
entry — last night's sleep is usually logged this morning against yesterday's date.

**So the today-reads were five, not six**, across five widgets: `DailyGoalsCard`
(meals, summed client-side from `getMealHistory(date)`), `CompactWaterTracker`,
`CompactStepTracker` (via `StepRepository`, network then local), the today half of
exercise and the today half of sleep. Five requests for one day, staggered with
`loadDelay`s of 900–1700 ms precisely because they were five requests.

**The reload mechanism was already shared.** `dashboard_home._refreshData` swaps in a
new `_currentUserProfile`, and every card's `didUpdateWidget` refetches on the new
identity. A new-identity signal was the existing contract; only the source was per-card.

**`DailySnapshot` is per-screen and `forDay` always fetches** ([ADR-0004](0004-inject-dailysnapshot-at-screen-seam.md)),
so the cards could not each call it — that would be five requests again. The dashboard
has to own the read.

## Decision

1. **`DashboardHome` owns one `DailySnapshot`** (injectable through the constructor,
   the ADR-0004 seam) **and one `Future<DaySnapshot> _today`**, created in `initState`
   and recreated by `_refreshData` (pull-to-refresh, app resume) and by `_reloadDay`.
2. **The five today-data cards take `day` and `refreshDay`.** `day` is the shared
   future; a new identity means "re-derive", checked with `identical` in
   `didUpdateWidget` alongside the existing profile check. `refreshDay` asks the
   dashboard for a new read — one request that updates every card — and replaces each
   card's post-navigation `_loadX()`.
3. **The cards keep their state and their writes.** `_loadX()` now reads the section
   from `await widget.day` instead of an Api; the optimistic local update after a write
   (`+1 glass`, quick-add steps) is unchanged. The change is the source of the initial
   and refreshed read, nothing else.
4. **Missing and error both land in each card's existing "no data" branch**, exactly
   where a failed fetch landed before. The cards have no error state; adding one is a
   design decision about the dashboard, not this change. `_read_errors` is available
   when that decision is made.
5. **Exercise keeps its week read; sleep keeps its yesterday read.** Different
   questions. Exercise keeps a `loadDelay` for the week request; the others drop theirs.
6. **The step card's pedometer path is unchanged**: a `StepRepository` read per count
   update, as before, split into `_loadFromRepository` beside `_loadTodayEntry`. The
   counter service exposes `todaySteps`, so that request could go entirely; its own
   change, and untestable here.
7. **`DaySnapshot`'s exercise entries are the day's by construction**, so the card's
   per-row `startsWith(today)` check against the device clock is removed. It was the
   one place the client re-derived which day a row belonged to.
8. **`DailySnapshot`'s steps fallback is local-only now.** Its default was
   `StepRepository.getStepEntryByDate`, which tries `StepApi` *before* on-device storage
   — so a day with no server steps row (the documented normal case) cost a second
   request, undoing the consolidation this ADR is for. That default predates this ADR
   (ADR-0006 introduced the fallback); it became load-bearing here. The repository gains
   `getLocalStepEntryByDate`, storage only, and the module defaults to it. Raised by
   review on this PR.

## Consequences

- Dashboard load: five today-requests become one, and the 900–1300 ms stagger on
  water/steps/sleep goes with them — those cards now paint when the one read lands.
  Weight history, weekly stats, exercise-week, sleep-yesterday (when needed) and period
  history remain their own requests: ~10 → ~6.
- A write on one card followed by `refreshDay` refreshes every card from one request.
  Before, the writing card refetched its own section and the others stayed as they were.
- `test/dashboard_cards_read_the_day_test.dart` pumps water, meals, sleep and exercise
  over an injected `Future<DaySnapshot>` and pins: the value flows through; a missing or
  errored section is the empty state; a new future identity re-derives and the same one
  does not; returning from the logging page calls `refreshDay`, not an Api. The step card
  is not pumped — its `initState` reaches the permission plugin, which has no
  test-platform implementation.
- `flutter analyze`: no errors or warnings, 1300 → 1299 infos. `flutter test`: the same
  network-dependent integration failures as before, compared by name (two of them flake
  run-to-run against the live backend and did so on the unmodified tree too).
- **Not done:** the dashboard has no error UI, so a failed day read still renders as
  zeros — the same lie the today report stopped telling in ADR-0006. The dashboard
  has the `Section` states now; rendering them is the next decision.
