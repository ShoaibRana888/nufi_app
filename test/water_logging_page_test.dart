import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/services/api/water_api.dart';
import 'package:user_onboarding/features/tracking/screens/water_logging_page.dart';

/// The water page's goal must follow the profile's glass goal.
///
/// Regression: the ml target driving the progress bar and the goal-met state
/// was a hardcoded 2000ml — exactly 8 glasses at 250ml — so anyone with a
/// goal above 8 was told "Goal achieved!" early. Entries loaded from the
/// backend carried that stale target too, so the profile goal has to win
/// over whatever was stored on the row.
class _FakeWaterApi implements WaterApi {
  final WaterEntry? stored;
  _FakeWaterApi(this.stored);

  @override
  Future<WaterEntry?> getWaterEntryByDate(String userId, DateTime date) async =>
      stored;

  @override
  Future<String> saveWaterEntry(WaterEntry waterEntry) async => 'saved';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  UserProfile profileWithGoal(int glasses) => UserProfile(
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
        waterIntake: glasses * 250,
        waterIntakeGlasses: glasses,
        medicalConditions: const [],
        preferredWorkouts: const [],
        workoutFrequency: 3,
        workoutDuration: 30,
        workoutLocation: 'home',
        availableEquipment: const [],
        fitnessLevel: 'beginner',
        hasTrainer: false,
      );

  /// Eight glasses logged, on a row whose stored target is the old 2000ml.
  WaterEntry eightGlassesOnStaleRow() => WaterEntry(
        id: 'w1',
        userId: 'u1',
        date: DateTime.now(),
        glassesConsumed: 8,
        totalMl: 2000,
        targetMl: 2000,
      );

  testWidgets('a 10-glass goal is not met at 8 glasses', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WaterLoggingPage(
        userProfile: profileWithGoal(10),
        waterApi: _FakeWaterApi(eightGlassesOnStaleRow()),
      ),
    ));
    await tester.pumpAndSettle();

    // The target follows the profile (10 × 250), not the stored row.
    expect(find.textContaining('2000ml / 2500ml'), findsOneWidget);
    expect(find.textContaining('80% of daily goal'), findsOneWidget);
    expect(find.text('Goal achieved! 🎉'), findsNothing);
  });

  testWidgets('an 8-glass goal is met at 8 glasses', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WaterLoggingPage(
        userProfile: profileWithGoal(8),
        waterApi: _FakeWaterApi(eightGlassesOnStaleRow()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('2000ml / 2000ml'), findsOneWidget);
    expect(find.text('Goal achieved! 🎉'), findsOneWidget);
  });

  testWidgets('a fresh day uses the profile goal for its target', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WaterLoggingPage(
        userProfile: profileWithGoal(12),
        waterApi: _FakeWaterApi(null),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('0ml / 3000ml'), findsOneWidget);
  });
}
