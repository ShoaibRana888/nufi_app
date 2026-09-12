import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/models/day_snapshot.dart';
import 'package:user_onboarding/data/models/sleep_entry.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/features/home/widgets/compact_exercise_tracker.dart';
import 'package:user_onboarding/features/home/widgets/compact_sleep_tracker.dart';
import 'package:user_onboarding/features/home/widgets/compact_water_tracker.dart';
import 'package:user_onboarding/features/home/widgets/daily_meal_card.dart';

/// The dashboard's today-data cards render from the one day the dashboard
/// read, not from a fetch of their own. Each card takes `day` (the shared
/// future) and `refreshDay` (asks the dashboard for a new one). A new `day`
/// identity is the signal to re-derive -- that is what makes one request
/// update every card. See docs/adr/0007-dashboard-reads-the-day-once.md.
///
/// The step card is not pumped here: its initState reaches the permission
/// plugin, which has no test-platform implementation. The exercise card's
/// week read still goes through ExerciseApi; in the test it fails fast (no
/// network) and the card degrades to zero weekly, which is the pre-existing
/// behaviour and not what these tests are about.
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

  DaySnapshot day({int glasses = 5, double hours = 7.5, int minutes = 25,
                   double calories = 1800}) =>
      DaySnapshot(
        userId: 'u1',
        date: today,
        meals: Section.ok(MealsDay(
            calories: calories, proteinG: 90, carbsG: 200, fatG: 60, count: 3)),
        water: Section.ok(WaterEntry(
            userId: 'u1', date: today, glassesConsumed: glasses,
            totalMl: glasses * 250.0, targetMl: 2000)),
        sleep: Section.ok(SleepEntry(
            userId: 'u1', date: today, totalHours: hours, qualityScore: 0.8,
            deepSleepHours: 2, sleepIssues: const [], createdAt: today)),
        exercise: Section.ok(ExerciseDay(
            entries: [
              {'exercise_date': '2026-09-07T00:00:00+00:00',
               'duration_minutes': minutes, 'muscle_group': 'legs'},
            ],
            totalMinutes: minutes)),
      );

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Future<void> noop() async {}

  group('each card renders its section of the shared day', () {
    testWidgets('water', (tester) async {
      await tester.pumpWidget(host(CompactWaterTracker(
        userProfile: testProfile(),
        day: Future.value(day(glasses: 5)),
        refreshDay: noop,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('5 / 8 glasses'), findsOneWidget);
    });

    testWidgets('meals', (tester) async {
      await tester.pumpWidget(host(SingleChildScrollView(
        child: DailyGoalsCard(
          userProfile: testProfile(),
          day: Future.value(day(calories: 1800)),
          refreshDay: noop,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('1800 consumed'), findsOneWidget);
    });

    testWidgets('sleep, from today when today has an entry', (tester) async {
      await tester.pumpWidget(host(CompactSleepTracker(
        userProfile: testProfile(),
        day: Future.value(day(hours: 7.5)),
        refreshDay: noop,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('7.5'), findsWidgets);
    });

    testWidgets('exercise, today\'s minutes from the day', (tester) async {
      await tester.pumpWidget(host(CompactExerciseTracker(
        userProfile: testProfile(),
        day: Future.value(day(minutes: 25)),
        refreshDay: noop,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('25 /'), findsOneWidget);
    });
  });

  group('a missing section is the card\'s empty state, not a crash', () {
    testWidgets('water with nothing logged shows zero of the goal', (tester) async {
      await tester.pumpWidget(host(CompactWaterTracker(
        userProfile: testProfile(),
        day: Future.value(DaySnapshot(userId: 'u1', date: today)),
        refreshDay: noop,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 / 8 glasses'), findsOneWidget);
    });

    testWidgets('meals with a failed read shows zeros', (tester) async {
      await tester.pumpWidget(host(SingleChildScrollView(
        child: DailyGoalsCard(
          userProfile: testProfile(),
          day: Future.value(DaySnapshot(
              userId: 'u1', date: today,
              meals: const Section.error('read_failed'))),
          refreshDay: noop,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 consumed'), findsOneWidget);
    });
  });

  group('a new day identity re-derives the card', () {
    testWidgets('water follows the dashboard\'s reload', (tester) async {
      Widget build(Future<DaySnapshot> d) => host(CompactWaterTracker(
            userProfile: testProfile(), day: d, refreshDay: noop,
          ));

      await tester.pumpWidget(build(Future.value(day(glasses: 2))));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 / 8 glasses'), findsOneWidget);

      // The dashboard read the day again: a different future, more glasses.
      await tester.pumpWidget(build(Future.value(day(glasses: 6))));
      await tester.pumpAndSettle();
      expect(find.textContaining('6 / 8 glasses'), findsOneWidget);
    });

    testWidgets('the same future does not re-derive', (tester) async {
      var reads = 0;
      final shared = Future<DaySnapshot>(() {
        reads++;
        return day(glasses: 3);
      });
      Widget build() => host(CompactWaterTracker(
            userProfile: testProfile(), day: shared, refreshDay: noop,
          ));

      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();

      expect(reads, 1);
      expect(find.textContaining('3 / 8 glasses'), findsOneWidget);
    });
  });

  testWidgets('returning from the logging page asks the dashboard, not the Api',
      (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(host(CompactWaterTracker(
      userProfile: testProfile(),
      day: Future.value(day(glasses: 1)),
      refreshDay: () async => refreshes++,
    )));
    await tester.pumpAndSettle();

    // Tap the card to open the logging page, then pop it.
    await tester.tap(find.textContaining('1 / 8 glasses'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });
}
