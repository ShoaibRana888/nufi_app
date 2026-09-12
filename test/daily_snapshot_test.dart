import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/models/day_snapshot.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/services/daily_snapshot.dart';

/// DailySnapshot over the single daily-snapshot endpoint — no network.
///
/// The fixture below is the shape the backend actually returns (verified
/// against the deployed endpoint), so these tests are a check on the contract
/// as well as on the mapping. See docs/adr/0003 for the frozen shape and
/// docs/adr/0004 for the migration off the seven-call fan-out.
///
/// The distinction the whole design turns on: a section that loaded, a section
/// the user logged nothing for, and a section whose read failed are three
/// different answers. The backend omits a section for the middle case and
/// names it in `_read_errors` for the last.
void main() {
  final today = DateTime(2026, 9, 6);
  DateTime clock() => DateTime(2026, 9, 6, 12, 0);

  /// A fully logged day, exactly as the endpoint serves it.
  Map<String, dynamic> document({
    Map<String, dynamic>? readErrors,
    List<String> omit = const [],
  }) {
    final doc = <String, dynamic>{
      'user_id': 'u1',
      'date': '2026-09-06',
      'meals': {
        'totals': {
          'calories': 1800.0, 'protein_g': 90.0, 'carbs_g': 200.0,
          'fat_g': 60.0, 'fiber_g': 25.0, 'sugar_g': 40.0, 'sodium_mg': 1200.0,
        },
        'count': 3,
        'entries': [
          {'id': 'm1', 'food_item': 'oats', 'calories': 300,
           'shared_with_chat': true},
        ],
      },
      'water': {
        'id': 'wa1', 'user_id': 'u1', 'date': '2026-09-06',
        'glasses_consumed': 5, 'total_ml': 1250.0, 'target_ml': 2000.0,
        'shared_with_chat': false,
      },
      'steps': {
        'id': 's1', 'user_id': 'u1', 'date': '2026-09-06',
        'steps': 8000, 'goal': 10000, 'shared_with_chat': true,
      },
      'sleep': {
        'id': 'sl1', 'user_id': 'u1', 'date': '2026-09-06',
        'total_hours': 7.5, 'quality_score': 0.8, 'shared_with_chat': false,
      },
      'exercise': {
        'entries': [
          {'id': 'e1', 'exercise_name': 'run', 'duration_minutes': 30,
           'calories_burned': 250, 'shared_with_chat': true},
        ],
        'total_minutes': 30,
        'total_calories_burned': 250.0,
      },
      'weight': {
        'id': 'w1', 'user_id': 'u1', 'date': '2026-09-06T07:00:00+00:00',
        'weight': 70.4, 'notes': null, 'shared_with_chat': false,
      },
      'supplements': {
        'items': [
          {'name': 'D3', 'taken': true},
          {'name': 'Omega', 'taken': false},
        ],
        'taken_count': 1,
        'total_count': 2,
      },
      '_read_errors': readErrors ?? <String, dynamic>{},
    };
    for (final key in omit) {
      doc.remove(key);
    }
    return doc;
  }

  DailySnapshot buildModule({
    DayReader? readDay,
    LocalStepsReader? readLocalSteps,
  }) {
    return DailySnapshot(
      clock: clock,
      readDay: readDay ?? (u, d) async => document(),
      // Default to "nothing stored locally" so the on-device fallback only
      // shows up in the tests that ask for it.
      readLocalSteps: readLocalSteps ?? (u, d) async => null,
    );
  }

  group('mapping the document', () {
    test('forDay assembles every section from one read', () async {
      final snap = await buildModule().forDay('u1', today);

      expect(snap.meals.value!.calories, 1800);
      expect(snap.meals.value!.count, 3);
      expect(snap.water.value!.glassesConsumed, 5);
      expect(snap.steps.value!.steps, 8000);
      expect(snap.sleep.value!.totalHours, 7.5);
      expect(snap.exercise.value!.totalMinutes, 30);
      expect(snap.exercise.value!.totalCaloriesBurned, 250);
      expect(snap.weight.value!.weight, 70.4);
      expect(snap.supplements.value!.takenCount, 1);
      expect(snap.supplements.value!.totalCount, 2);
    });

    test('it makes exactly one read', () async {
      var reads = 0;
      final module = buildModule(readDay: (u, d) async {
        reads++;
        return document();
      });

      await module.forDay('u1', today);

      expect(reads, 1); // was seven parallel calls before the migration
    });

    test('meal entries arrive, which the old fan-out could never deliver',
        () async {
      // MealApi.getDailySummary normalised its response to
      // {totals, meals_count} and never emitted a `meals` key, so the old
      // _mealsSection read an absent list and MealsDay.entries was always
      // empty. The snapshot carries the rows.
      final snap = await buildModule().forDay('u1', today);

      expect(snap.meals.value!.entries, hasLength(1));
      expect(snap.meals.value!.entries.first['food_item'], 'oats');
    });

    test('rows keep shared_with_chat', () async {
      final snap = await buildModule().forDay('u1', today);

      expect(snap.water.value!.sharedWithChat, isFalse);
      expect(snap.steps.value!.sharedWithChat, isTrue);
      // Weight is the one the backend had to widen to carry the flag: its
      // store projection used to drop it, which read as `true` by default.
      expect(snap.weight.value!.sharedWithChat, isFalse);
    });
  });

  group('ok / missing / error', () {
    test('an omitted section is missing, not failed', () async {
      final module = buildModule(
        readDay: (u, d) async => document(omit: ['sleep', 'weight']),
      );
      final snap = await module.forDay('u1', today);

      expect(snap.sleep.status, SectionStatus.missing);
      expect(snap.weight.status, SectionStatus.missing);
      expect(snap.sleep.isError, isFalse);
    });

    test('a section named in _read_errors is failed, not missing', () async {
      final module = buildModule(
        readDay: (u, d) async => document(
          omit: ['sleep'],
          readErrors: {'sleep': 'read_failed'},
        ),
      );
      final snap = await module.forDay('u1', today);

      expect(snap.sleep.isError, isTrue);
      expect(snap.sleep.error, 'read_failed'); // opaque token, carried as-is
    });

    test('a failed section does not take its neighbours down', () async {
      final module = buildModule(
        readDay: (u, d) async => document(
          omit: ['water'],
          readErrors: {'water': 'read_failed'},
        ),
      );
      final snap = await module.forDay('u1', today);

      expect(snap.water.isError, isTrue);
      expect(snap.meals.hasValue, isTrue);
      expect(snap.steps.hasValue, isTrue);
      expect(snap.sleep.hasValue, isTrue);
    });

    test('a malformed row fails only its own section', () async {
      final broken = document();
      broken['water'] = {'date': 'not-a-date'};
      final snap = await buildModule(readDay: (u, d) async => broken)
          .forDay('u1', today);

      expect(snap.water.isError, isTrue);
      expect(snap.steps.hasValue, isTrue);
    });

    test('a failed day read marks every section failed, not empty', () async {
      // The regression this guards: one request replacing seven means a total
      // failure must not read as "the user logged nothing all day".
      final module = buildModule(
        readDay: (u, d) async => throw Exception('HTTP 503'),
      );
      final snap = await module.forDay('u1', today);

      for (final section in [
        snap.meals, snap.water, snap.sleep,
        snap.exercise, snap.weight, snap.supplements,
      ]) {
        expect(section.isError, isTrue);
        expect(section.status, isNot(SectionStatus.missing));
      }
    });
  });

  group('steps fall back to on-device storage', () {
    final local = StepEntry(userId: 'u1', date: today, steps: 4200, goal: 10000);

    test('a locally stored count shows when the day read fails', () async {
      // The pedometer accrues locally and syncs later, so steps can be known
      // here even when nothing else is. This is the behaviour StepRepository
      // provided while it was the steps reader.
      final module = buildModule(
        readDay: (u, d) async => throw Exception('offline'),
        readLocalSteps: (u, d) async => local,
      );
      final snap = await module.forDay('u1', today);

      expect(snap.steps.value!.steps, 4200);
      expect(snap.meals.isError, isTrue); // the rest still failed
    });

    test('it also covers a steps section the backend could not read', () async {
      final module = buildModule(
        readDay: (u, d) async => document(
          omit: ['steps'],
          readErrors: {'steps': 'read_failed'},
        ),
        readLocalSteps: (u, d) async => local,
      );
      final snap = await module.forDay('u1', today);

      expect(snap.steps.value!.steps, 4200);
    });

    test('it never overrides a value the backend did supply', () async {
      final module = buildModule(readLocalSteps: (u, d) async => local);
      final snap = await module.forDay('u1', today);

      expect(snap.steps.value!.steps, 8000); // server wins
    });

    test('nothing stored leaves the section as it was', () async {
      // "Offline" must not masquerade as "you walked nothing today".
      final module = buildModule(
        readDay: (u, d) async => document(
          omit: ['steps'],
          readErrors: {'steps': 'read_failed'},
        ),
        readLocalSteps: (u, d) async => null,
      );
      final snap = await module.forDay('u1', today);

      expect(snap.steps.isError, isTrue);
    });

    test('a failing local read is not itself an error', () async {
      final module = buildModule(
        readDay: (u, d) async => document(omit: ['steps']),
        readLocalSteps: (u, d) async => throw Exception('prefs unavailable'),
      );
      final snap = await module.forDay('u1', today);

      expect(snap.steps.status, SectionStatus.missing);
    });
  });

  group('caching', () {
    test('today is cached; other days are not', () async {
      final module = buildModule();
      expect(module.cachedDay('u1', today), isNull);

      await module.forDay('u1', today);
      expect(module.cachedDay('u1', today), isNotNull);

      final otherDay = DateTime(2026, 9, 1);
      await module.forDay('u1', otherDay);
      expect(module.cachedDay('u1', otherDay), isNull);
    });

    test('clearCache drops cached days', () async {
      final module = buildModule();
      await module.forDay('u1', today);
      module.clearCache();
      expect(module.cachedDay('u1', today), isNull);
    });
  });
}
