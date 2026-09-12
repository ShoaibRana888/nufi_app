# 3. DaySnapshot contract-request (frontend → backend handoff)

Date: 2026-09-06
Status: Accepted (frontend); **Built** (backend, 2026-09-07) — see the addenda below

## Context

`DailySnapshot.forDay` ([[0002-daily-snapshot-module]]) ships now over the existing
per-tracker endpoints via parallel fan-out. Its interface is a shield: when the backend
can serve the whole day in one call, `forDay` swaps its internals with no change to
callers. This ADR **freezes the shape** the frontend wants, so the backend track designs
to it by construction rather than by luck.

**This is the authoritative source for that shape.** The backend repo carries a mirror
(`docs/contracts/daily-snapshot-endpoint.md`) that must not diverge from this file.

## The critical distinction

This endpoint returns the **owner's complete day** — every entry, regardless of its
`sharedWithChat` flag — because the owner sees and edits all their own data.

It is **not** the same read as the backend's `get_shared_activities_for_date`
(candidate #1), which returns only the *shared* subset for the AI coach. Two different
reads; they must not be conflated on the backend.

## Requested endpoint

```
GET /daily-snapshot/{user_id}/{date}      # date = YYYY-MM-DD in the user's timezone
```

Response (each section independently omittable; a missing section ⇒ the client marks it
`missing`, a 5xx/partial-failure marker per section ⇒ `error`):

```jsonc
{
  "user_id": "...",
  "date": "2026-09-06",
  "meals":       { "totals": { "calories": 0, "protein_g": 0, "carbs_g": 0, "fat_g": 0 },
                   "count": 0, "entries": [ /* meal rows */ ] },
  "water":       { /* daily_water row */ },
  "steps":       { /* daily_steps row */ },
  "sleep":       { /* sleep row */ },
  "exercise":    { "entries": [ /* exercise rows */ ],
                   "total_minutes": 0, "total_calories_burned": 0 },
  "weight":      { /* weight row */ },
  "supplements": { "items": [ { "name": "...", "taken": false } ],
                   "taken_count": 0, "total_count": 0 }
}
```

Row shapes are the existing per-tracker entry payloads unchanged (client already maps
them via `WaterEntry.fromMap`, `StepEntry.fromMap`, etc.), including each row's
`shared_with_chat` field.

## Backend acceptance (for when the backend track picks this up)

- One round-trip returns the full owner day for a date; per-section failures are isolated
  (a broken tracker read must not fail the whole response).
- Reuses the store reads that candidate #2's daily-metric store will expose; pairs with
  candidate #4's `log_daily_metric` use-case for the write side.
- Additive: does not change or replace the existing per-tracker endpoints while the client
  migrates.

## Addenda (2026-09-07, as built)

The backend shipped this endpoint at
`GET /api/health/daily-snapshot/{user_id}/{date}`. Two things this ADR left
underspecified were settled during that work; recorded here because this file
is the authoritative copy of the shape.

### 1. The per-section error marker is `_read_errors`

This ADR asked for "a 5xx/partial-failure marker per section" without saying
what one looks like. It is a top-level map of section name to a fixed token —
the same key and rule the backend's own day reads use:

```jsonc
{ "user_id": "...", "date": "2026-09-06",
  "meals": { ... }, "water": { ... },
  "_read_errors": { "sleep": "read_failed" } }
```

> **Amended 2026-09-12.** This originally read "section name to message" with
> the example `"sleep_entries exploded"`, and as built it *was* the message:
> the backend store's raw exception text, which for a PostgREST failure
> carries the SQL message, the Postgres error code and a hint naming tables
> and columns, and for an HTTP failure the request URL with the project host
> — on a route with no auth. This client reads only the key: `Section.error`
> holds the value and no screen renders it. So the value is now the opaque
> token **`"read_failed"`**, identical for every failed section. The
> missing-vs-error distinction is carried by presence, not by the message.
> **Treat the value as opaque; never parse or display it.** Backend
> reasoning: its ADR-0007.

So, per section: **present ⇒ `ok`**, **absent ⇒ `missing`**, **absent and named
in `_read_errors` ⇒ `error`** — exactly `SectionStatus`. A failed section is
never served with a value. `_read_errors` is always present, `{}` when every
read succeeded.

### 2. Meal totals are a superset

`meals.totals` carries `fiber_g`, `sugar_g` and `sodium_mg` alongside the four
named above, because `/daily-summary` already returned them and
`MealApi.getDailySummary` already mapped them. Omitting them would have made
migrating off `/daily-summary` a regression.

### Also worth knowing

- **`period` is not in the response.** The backend's day read covers eight
  trackers; `DaySnapshot` has seven and no period section. Adding it is
  additive and needs no backend change.
- **Roll-ups are always present; single rows are omitted when empty.** `meals`,
  `exercise` and `supplements` carry zeros for a day with nothing logged;
  `water`, `steps`, `sleep` and `weight` are omitted when there is no row.
  This mirrors what `DailySnapshot` already did, so it needed no adjustment.
- **`supplements.items` is sorted by name**, so the list does not reshuffle
  between refreshes. `taken_count` / `total_count` are emitted as specified
  even though `SupplementsDay` derives both from `items`.
- **Rows carry `shared_with_chat`, including `weight`.** The backend's
  `get_weight_by_date` projection used to drop it; it was widened rather than
  bypassed. Before this, `WeightEntry.sharedWithChat` read as `true` for every
  entry, because `fromMap` defaults an absent flag to true.

The backend's reasoning is in its `docs/adr/0004-daily-snapshot-endpoint.md`.

## Consequences

- Frontend needs no backend change to ship F1; this is a later optimization behind the
  seam (6 dashboard calls → 1).
- The backend #1 (shared read) and this (full-owner read) share plumbing but are distinct
  interfaces — record both in the backend `CONTEXT.md`.
