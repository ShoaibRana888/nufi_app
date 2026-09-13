import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/daily_snapshot.dart';
import 'package:user_onboarding/features/home/widgets/card_load_error.dart';
import 'package:user_onboarding/features/reports/screens/today_report_screen.dart';

/// Widget test proving F3's seam: TodayReportScreen renders from an injected
/// DailySnapshot. The "fake" is a real DailySnapshot over a canned day
/// document -- the shape the daily-snapshot endpoint serves -- so no network
/// is touched. See docs/adr/0004-daily-snapshot-endpoint-migration.md.
void main() {
  final today = DateTime(2026, 9, 7);

  UserProfile testProfile() => UserProfile(
        id: 'u1',
        name: 'Test',
        email: 't@example.com',
        gender: 'female',
        age: 30,
        height: 165,
        weight: 60,
        activityLevel: 'moderate',
        primaryGoal: 'maintain',
        weightGoal: 'maintain_weight',
        sleepHours: 8,
        bedtime: '22:00',
        wakeupTime: '06:00',
        dailyStepGoal: 10000,
        sleepIssues: const [],
        dietaryPreferences: const [],
        waterIntake: 2000,
        waterIntakeGlasses: 8,
        medicalConditions: const [],
        preferredWorkouts: const [],
        workoutFrequency: 3,
        workoutDuration: 30,
        workoutLocation: 'home',
        availableEquipment: const [],
        fitnessLevel: 'beginner',
        hasTrainer: false,
      );

  /// One day document, as the endpoint returns it. `sleep` and `weight` are
  /// omitted, which is how the contract says "nothing logged".
  Map<String, dynamic> dayDocument() => {
        'user_id': 'u1',
        'date': '2026-09-07',
        'meals': {
          'totals': {'calories': 1800.0, 'protein_g': 90.0,
                     'carbs_g': 200.0, 'fat_g': 60.0},
          'count': 3,
          'entries': const [],
        },
        'water': {
          'user_id': 'u1', 'date': '2026-09-07',
          'glasses_consumed': 5, 'total_ml': 1250.0, 'target_ml': 2000.0,
        },
        'steps': {
          'user_id': 'u1', 'date': '2026-09-07', 'steps': 8000, 'goal': 10000,
        },
        'exercise': {'entries': const [], 'total_minutes': 0,
                     'total_calories_burned': 0.0},
        'supplements': {'items': const [], 'taken_count': 0, 'total_count': 0},
        '_read_errors': const <String, dynamic>{},
      };

  /// A DailySnapshot over a canned document -- no network in the test.
  /// `reads` counts the day reads, so a test can see a retry happen.
  DailySnapshot fakeSnapshot({Map<String, dynamic>? document, List<int>? reads}) =>
      DailySnapshot(
        clock: () => today,
        readDay: (u, d) async {
          reads?.add(1);
          return document ?? dayDocument();
        },
        readLocalSteps: (u, d) async => null,
      );

  /// The day with one section the backend could not read: omitted from the
  /// body and named in `_read_errors`, which is the contract's `error`.
  Map<String, dynamic> dayWithFailed(String section) => dayDocument()
    ..remove(section)
    ..['_read_errors'] = {section: 'read_failed'};

  Future<void> pumpReport(WidgetTester tester, DailySnapshot snapshot) async {
    await tester.pumpWidget(MaterialApp(
      home: TodayReportScreen(userProfile: testProfile(), dailySnapshot: snapshot),
    ));
    // Let initState -> _loadTodayData -> forDay resolve.
    await tester.pumpAndSettle();
  }

  testWidgets('renders tracker cards from an injected DailySnapshot', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TodayReportScreen(
        userProfile: testProfile(),
        dailySnapshot: fakeSnapshot(),
      ),
    ));

    // Let initState -> _loadTodayData -> forDay resolve.
    await tester.pumpAndSettle();

    // Cards for each tracker rendered (the day loaded, not the spinner).
    expect(find.text('Meals'), findsWidgets);
    expect(find.text('Water'), findsWidgets);
    expect(find.text('Steps'), findsWidgets);

    // Injected values flowed through to the UI.
    expect(find.textContaining('8000'), findsWidgets); // steps
    expect(find.textContaining('5/8'), findsWidgets);   // water: 5 of 8 glasses
  });

  // A failed read is not an empty day. `Section.error` has carried the
  // distinction since ADR-0006, and this screen rendered it as the empty
  // card anyway -- "0/8 glasses" for a tracker the backend could not read.
  // The dashboard's cards got an error state first (ADR-0007); this is the
  // same widget, in the report's grid.
  group('a failed section is the card\'s error state, not a zero', () {
    testWidgets('water', (tester) async {
      await pumpReport(tester, fakeSnapshot(document: dayWithFailed('water')));

      // The screen rendered despite the water failure; neighbours are intact.
      expect(find.text('Steps'), findsWidgets);
      expect(find.textContaining('8000'), findsWidgets);

      // Water is named, says it could not load, and shows no number.
      expect(find.text('Water'), findsWidgets);
      expect(find.text(CardLoadError.compactMessage), findsOneWidget);
      expect(find.textContaining('0/8 glasses'), findsNothing);
    });

    testWidgets('meals -- a roll-up the endpoint always sends when it can',
        (tester) async {
      await pumpReport(tester, fakeSnapshot(document: dayWithFailed('meals')));

      expect(find.text(CardLoadError.compactMessage), findsOneWidget);
      expect(find.textContaining('0/3 meals'), findsNothing);
    });

    testWidgets('a missing section is still the empty state, not an error',
        (tester) async {
      // `sleep` is omitted from the document without being named in
      // _read_errors: nothing logged, which is a reading, not a failure.
      await pumpReport(tester, fakeSnapshot());

      expect(find.text(CardLoadError.compactMessage), findsNothing);
      expect(find.text('Sleep'), findsWidgets);
    });

    testWidgets('an unread section is not counted as done or as missing',
        (tester) async {
      await pumpReport(tester, fakeSnapshot(document: dayWithFailed('water')));

      // Daily Progress counts the six sections that were read, not seven,
      // and water is not listed as something the user has yet to log.
      expect(find.textContaining('/6'), findsOneWidget);
      expect(find.textContaining('/7'), findsNothing);
      expect(find.text('Water'), findsOneWidget,
          reason: 'only the grid cell; not a "not logged" row below it');
    });

    testWidgets('tapping the error card reads the day again', (tester) async {
      final reads = <int>[];
      await pumpReport(tester, fakeSnapshot(document: dayWithFailed('water'), reads: reads));
      expect(reads.length, 1);

      await tester.tap(find.text(CardLoadError.compactMessage));
      await tester.pumpAndSettle();

      expect(reads.length, 2);
    });

    testWidgets('the error card fits a phone-width grid cell', (tester) async {
      // The grid is three columns at childAspectRatio 1.2; on a 360dp phone
      // a cell is about 103x86. The test font draws every glyph as a full
      // square, so text here is wider than on any device: a cell that fits
      // in this font fits in a real one. An overflow is an exception in a
      // widget test, so this is the layout's proof. (The screen as a whole
      // cannot be pumped at that size: its existing cards overflow in the
      // test font, which is a property of the font, not the cards.)
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 103, height: 86,
              child: CardLoadError(
                title: 'Water', icon: Icons.water_drop, color: Colors.blue,
                onRetry: () async {}, compact: true,
              ),
            ),
          ),
        ),
      ));

      expect(find.text(CardLoadError.compactMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a whole failed day read marks every card, not none',
        (tester) async {
      // ADR-0006 decision 3: one request replacing seven means a total
      // failure must not render as a day with nothing logged.
      final snapshot = DailySnapshot(
        clock: () => today,
        readDay: (u, d) async => throw Exception('backend down'),
        readLocalSteps: (u, d) async => null,
      );
      await pumpReport(tester, snapshot);

      expect(find.text(CardLoadError.compactMessage), findsNWidgets(7));
      expect(find.textContaining('0/7'), findsNothing);
      // 0 of 0 read is not a completed day (raised in review).
      expect(find.textContaining('All activities completed'), findsNothing);
      expect(find.textContaining('Perfect Day'), findsNothing);
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });

    testWidgets('an unread section blocks the celebration even when everything read is done',
        (tester) async {
      // Every readable section complete, water unreadable: the numbers say
      // 6/6, but neither "All activities completed" nor "Perfect Day" is a
      // claim the screen can make about a tracker it could not read.
      final document = dayWithFailed('water')
        ..['meals'] = {
          'totals': {'calories': 1800.0, 'protein_g': 90.0, 'carbs_g': 200.0, 'fat_g': 60.0},
          'count': 3, 'entries': const [],
        }
        ..['steps'] = {'user_id': 'u1', 'date': '2026-09-07', 'steps': 12000, 'goal': 10000}
        ..['sleep'] = {'user_id': 'u1', 'date': '2026-09-07', 'total_hours': 8.0, 'quality_score': 8,
                       'bedtime': '2026-09-06T22:00:00', 'wake_time': '2026-09-07T06:00:00'}
        ..['weight'] = {'id': 'w1', 'user_id': 'u1', 'date': '2026-09-07T07:00:00', 'weight': 60.0}
        ..['exercise'] = {'entries': [{'exercise_name': 'run', 'duration_minutes': 30}],
                          'total_minutes': 30, 'total_calories_burned': 250.0}
        ..['supplements'] = {'items': [{'name': 'D3', 'taken': true}], 'taken_count': 1, 'total_count': 1};
      await pumpReport(tester, fakeSnapshot(document: document));

      expect(find.text(CardLoadError.compactMessage), findsOneWidget);
      expect(find.textContaining('All activities completed'), findsNothing);
      expect(find.textContaining('Perfect Day'), findsNothing);
      expect(find.textContaining('could not be loaded'), findsOneWidget);
    });
  });
}
