import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/services/api/water_api.dart';
import 'package:user_onboarding/features/home/widgets/compact_water_tracker.dart';
import 'package:user_onboarding/features/tracking/screens/water_history_page.dart';

/// Every water surface must measure against the profile goal, not the row.
///
/// Rows created before the target fix carry a 2000ml constant that was never a
/// record of the user's goal. Two consumers read it back: the dashboard's
/// compact tracker, which resaves whatever it loaded — so a stale target would
/// be written back on the next glass — and the history page, which reports
/// "goals achieved" straight from the stored value.
class _FakeWaterApi implements WaterApi {
  final WaterEntry? today;
  final List<WaterEntry> history;
  final List<WaterEntry> saved = [];

  _FakeWaterApi({this.today, this.history = const []});

  @override
  Future<WaterEntry?> getTodayWaterEntry(String userId) async => today;

  @override
  Future<List<WaterEntry>> getWaterHistory(String userId,
          {int limit = 30}) async =>
      history;

  @override
  Future<String> saveWaterEntry(WaterEntry waterEntry) async {
    saved.add(waterEntry);
    return 'saved';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  UserProfile tenGlassUser() => UserProfile(
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
        waterIntake: 2500,
        waterIntakeGlasses: 10,
        medicalConditions: const [],
        preferredWorkouts: const [],
        workoutFrequency: 3,
        workoutDuration: 30,
        workoutLocation: 'home',
        availableEquipment: const [],
        fitnessLevel: 'beginner',
        hasTrainer: false,
      );

  /// A legacy row: eight glasses against the old 2000ml constant.
  WaterEntry legacyRow({DateTime? date}) => WaterEntry(
        id: 'w1',
        userId: 'u1',
        date: date ?? DateTime.now(),
        glassesConsumed: 8,
        totalMl: 2000,
        targetMl: 2000,
      );

  testWidgets('the compact tracker resaves a legacy row with the profile target',
      (tester) async {
    final api = _FakeWaterApi(today: legacyRow());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CompactWaterTracker(userProfile: tenGlassUser(), waterApi: api),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Ten-glass user at eight: the quick-add button is still enabled.
    final quickAdd = find.byIcon(Icons.add_circle_outline);
    expect(quickAdd, findsOneWidget);
    await tester.tap(quickAdd);
    await tester.pumpAndSettle();

    // What went back to the server carries 10 × 250, not the stale 2000.
    expect(api.saved, hasLength(1));
    expect(api.saved.single.glassesConsumed, 9);
    expect(api.saved.single.targetMl, 2500);
  });

  testWidgets('history measures achievement against the profile goal',
      (tester) async {
    final rows = [
      legacyRow(date: DateTime(2026, 9, 10)),
      legacyRow(date: DateTime(2026, 9, 11)),
      legacyRow(date: DateTime(2026, 9, 12)),
    ];
    await tester.pumpWidget(MaterialApp(
      home: WaterHistoryPage(
        userProfile: tenGlassUser(),
        waterApi: _FakeWaterApi(history: rows),
      ),
    ));
    await tester.pumpAndSettle();

    // Three days at eight glasses against a ten-glass goal: none achieved.
    // Against the stored 2000ml constant every one of them would count.
    expect(find.text('0/3'), findsOneWidget);
    expect(find.textContaining('2000ml / 2500ml'), findsNWidgets(3));
  });
}
