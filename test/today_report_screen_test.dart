import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/daily_snapshot.dart';
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
  DailySnapshot fakeSnapshot({Map<String, dynamic>? document}) => DailySnapshot(
        clock: () => today,
        readDay: (u, d) async => document ?? dayDocument(),
        readLocalSteps: (u, d) async => null,
      );

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

  testWidgets('a failing section degrades only its own card', (tester) async {
    // The backend could not read water and says so in _read_errors; every
    // other tracker loaded. The screen should still render, with water in its
    // empty state.
    final document = dayDocument()
      ..remove('water')
      ..['_read_errors'] = {'water': 'read_failed'};

    await tester.pumpWidget(MaterialApp(
      home: TodayReportScreen(
        userProfile: testProfile(),
        dailySnapshot: fakeSnapshot(document: document),
      ),
    ));
    await tester.pumpAndSettle();

    // The screen rendered despite the water failure; neighbours are intact.
    expect(find.text('Steps'), findsWidgets);
    expect(find.textContaining('8000'), findsWidgets);
    expect(find.text('Water'), findsWidgets); // still shown, in its empty state
  });
}
