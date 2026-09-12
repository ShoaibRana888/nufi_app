import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_onboarding/features/onboarding/screens/dietary_preferences_page.dart';
import 'package:user_onboarding/features/onboarding/screens/exercise_setup_page.dart';
import 'package:user_onboarding/features/onboarding/screens/period_cycle_page.dart';
import 'package:user_onboarding/features/onboarding/screens/weight_goal_page.dart';
import 'package:user_onboarding/features/onboarding/screens/workout_preferences_page.dart';

/// Onboarding pages must lay out without overflowing on a narrow phone.
///
/// A RenderFlex overflow surfaces here as a FlutterError, so these fail the
/// moment a label stops fitting. Regression for three visible overflows at
/// iPhone width — the water-goal row (4.2px) and two section headings (0.6px,
/// 28px) — all from the same cause: labels inside a Row cannot wrap. Pinned at
/// iPhone SE width, narrower than where they were first seen, so the other
/// labels sharing that pattern are covered too.
void main() {
  // iPhone SE (3rd gen): the narrowest current iPhone.
  const narrowPhone = Size(375, 667);

  Future<void> pumpAtNarrowWidth(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = narrowPhone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: page)),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'page overflowed at ${narrowPhone.width}px');
  }

  void noop(String key, dynamic value) {}

  testWidgets('dietary preferences page fits a narrow phone', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      DietaryPreferencesPage(formData: const {}, onDataChanged: noop),
    );
  });

  testWidgets('workout preferences page fits a narrow phone', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      WorkoutPreferencesPage(formData: const {}, onDataChanged: noop),
    );
  });

  testWidgets('exercise setup page fits a narrow phone', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      CurrentExerciseSetupPage(formData: const {}, onDataChanged: noop),
    );
  });

  testWidgets('weight goal page fits a narrow phone', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      WeightGoalPage(formData: const {'weight': 70.0}, onDataChanged: noop),
    );
  });

  testWidgets('period cycle page fits a narrow phone', (tester) async {
    await pumpAtNarrowWidth(
      tester,
      PeriodCyclePage(formData: const {}, onDataChanged: noop),
    );
  });
}
