// lib/data/services/daily_snapshot.dart
//
// DailySnapshot: the deep read module for "a user's day". One interface —
// forDay(userId, date) — over a single backend call, with per-section error
// isolation and a cache-first read for today. Absorbs the old MetricsService.
// See docs/adr/0002-daily-snapshot-module.md and docs/adr/0004.
//
// It used to fan out across seven endpoints in parallel (one of which read the
// user's entire weight history and scanned it client-side). The backend now
// serves the whole owner day in one request, so forDay swaps its internals
// behind the same interface — which is what that interface was for.

import 'package:user_onboarding/data/models/day_snapshot.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/models/sleep_entry.dart';
import 'package:user_onboarding/data/models/weight_entry.dart';
import 'package:user_onboarding/data/repositories/step_repository.dart';
import 'package:user_onboarding/data/services/api/daily_snapshot_api.dart';

/// Reads the whole day for (userId, date). Injectable so the module is
/// testable through fakes and independent of the Api's exact shape.
typedef DayReader = Future<Map<String, dynamic>> Function(
    String userId, DateTime date);

/// Reads steps from on-device storage. Used only when the day read could not
/// supply a steps section — see [_stepsSection]. Local means local: the
/// default is the repository's storage-only read, not its network-first one,
/// so a day with no server steps row stays one request.
typedef LocalStepsReader = Future<StepEntry?> Function(
    String userId, DateTime date);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class DailySnapshot {
  final DayReader _readDay;
  final LocalStepsReader _readLocalSteps;
  final DateTime Function() _clock;

  /// In-memory cache for the current day only, keyed by userId.
  final Map<String, DaySnapshot> _todayCache = {};

  DailySnapshot({
    DayReader? readDay,
    LocalStepsReader? readLocalSteps,
    DateTime Function()? clock,
  })  : _readDay = readDay ?? _defaultReadDay,
        _readLocalSteps = readLocalSteps ?? StepRepository.getLocalStepEntryByDate,
        _clock = clock ?? DateTime.now;

  static Future<Map<String, dynamic>> _defaultReadDay(String u, DateTime d) =>
      DailySnapshotApi().getDay(u, d);

  // --- Public interface (unchanged) ---

  /// The cached snapshot for [date] if it is today and has been loaded, else
  /// null. Lets a caller paint instantly before [forDay] resolves.
  DaySnapshot? cachedDay(String userId, DateTime date) {
    final cached = _todayCache[userId];
    if (cached != null && _sameDay(cached.date, date)) return cached;
    return null;
  }

  /// Assemble the full day for [userId] on [date].
  ///
  /// One request. A tracker the backend could not read degrades that section
  /// only; if the request itself fails, every section is marked `error`,
  /// because a day none of which loaded is not a day with nothing logged.
  /// Today's result is cached.
  Future<DaySnapshot> forDay(String userId, DateTime date) async {
    DaySnapshot snapshot;
    try {
      snapshot = _fromDocument(userId, date, await _readDay(userId, date));
    } catch (e) {
      snapshot = _allFailed(userId, date, e);
    }

    // Steps are the one tracker with on-device state (the pedometer accrues
    // locally and syncs later), so they can be known here when the backend
    // could not supply them.
    if (!snapshot.steps.hasValue) {
      snapshot = snapshot.copyWith(
        steps: await _localStepsSection(userId, date, snapshot.steps),
      );
    }

    if (_sameDay(date, _clock())) {
      _todayCache[userId] = snapshot;
    }
    return snapshot;
  }

  /// Clear cached state (e.g. on logout).
  void clearCache() => _todayCache.clear();

  // --- Mapping (each section isolates its own failure) ---

  DaySnapshot _fromDocument(
      String userId, DateTime date, Map<String, dynamic> day) {
    // Sections the backend could not read are absent from the body and named
    // here; absent and *unnamed* means the user logged nothing.
    final errors = (day['_read_errors'] as Map?) ?? const {};

    Section<T> section<T>(String key, T Function(Object) parse) {
      final error = errors[key];
      if (error != null) return Section<T>.error(error);

      final raw = day[key];
      if (raw == null) return Section<T>.missing();
      try {
        return Section<T>.ok(parse(raw));
      } catch (e) {
        // A section we cannot read is not a section that is absent.
        return Section<T>.error(e);
      }
    }

    return DaySnapshot(
      userId: userId,
      date: date,
      meals: section<MealsDay>('meals', (v) => _meals(v as Map)),
      water: section<WaterEntry>(
          'water', (v) => WaterEntry.fromMap(_row(v))),
      steps: section<StepEntry>('steps', (v) => StepEntry.fromMap(_row(v))),
      sleep: section<SleepEntry>('sleep', (v) => SleepEntry.fromMap(_row(v))),
      exercise: section<ExerciseDay>('exercise', (v) => _exercise(v as Map)),
      weight: section<WeightEntry>(
          'weight', (v) => WeightEntry.fromMap(_row(v))),
      supplements:
          section<SupplementsDay>('supplements', (v) => _supplements(v as Map)),
    );
  }

  /// Every section failed for the same reason: the day never arrived.
  DaySnapshot _allFailed(String userId, DateTime date, Object error) =>
      DaySnapshot(
        userId: userId,
        date: date,
        meals: Section<MealsDay>.error(error),
        water: Section<WaterEntry>.error(error),
        steps: Section<StepEntry>.error(error),
        sleep: Section<SleepEntry>.error(error),
        exercise: Section<ExerciseDay>.error(error),
        weight: Section<WeightEntry>.error(error),
        supplements: Section<SupplementsDay>.error(error),
      );

  /// Locally cached steps, if any, in place of a section the backend could not
  /// give us. Preserves the offline read that [StepRepository] used to provide
  /// when it was this module's steps reader: the pedometer's count stays
  /// visible when the network or the tracker read is down.
  ///
  /// Falls back to [existing] — keeping `missing` as `missing` and an error as
  /// an error — when there is nothing stored, so "offline" never masquerades
  /// as "you walked nothing today".
  Future<Section<StepEntry>> _localStepsSection(
      String userId, DateTime date, Section<StepEntry> existing) async {
    try {
      final local = await _readLocalSteps(userId, date);
      return local == null ? existing : Section<StepEntry>.ok(local);
    } catch (_) {
      return existing;
    }
  }

  static Map<String, dynamic> _row(Object value) =>
      Map<String, dynamic>.from(value as Map);

  static double _double(Object? v) => (v as num?)?.toDouble() ?? 0.0;

  static List<Map<String, dynamic>> _entries(Object? value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : const [];

  static MealsDay _meals(Map raw) {
    final totals = (raw['totals'] as Map?) ?? const {};
    return MealsDay(
      calories: _double(totals['calories']),
      proteinG: _double(totals['protein_g']),
      carbsG: _double(totals['carbs_g']),
      fatG: _double(totals['fat_g']),
      count: (raw['count'] as num?)?.toInt() ?? 0,
      entries: _entries(raw['entries']),
    );
  }

  static ExerciseDay _exercise(Map raw) => ExerciseDay(
        entries: _entries(raw['entries']),
        totalMinutes: (raw['total_minutes'] as num?)?.toInt() ?? 0,
        totalCaloriesBurned: _double(raw['total_calories_burned']),
      );

  static SupplementsDay _supplements(Map raw) {
    final items = <String, bool>{};
    for (final item in (raw['items'] as List? ?? const [])) {
      final entry = item as Map;
      final name = entry['name']?.toString();
      if (name != null) items[name] = entry['taken'] == true;
    }
    return SupplementsDay(items: items);
  }
}
