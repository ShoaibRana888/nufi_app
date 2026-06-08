// lib/data/services/metrics_service.dart
import 'package:user_onboarding/data/repositories/water_repository.dart';
import 'package:user_onboarding/data/repositories/step_repository.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:intl/intl.dart';

class MetricsService {
  final MealApi _apiService = MealApi();
  final ExerciseApi _exerciseApi = ExerciseApi();
  
  Future<Map<String, dynamic>> getTodayMetrics(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    try {
      Map<String, dynamic> metrics = {
        'steps': 0,
        'water': 0,
        'activeMinutes': 0,
        'caloriesBurned': 0,
        'caloriesConsumed': 0,
      };
      
      // Get steps using EXISTING repository method (same as reports page)
      final stepEntry = await StepRepository.getTodayStepEntry(userId);
      if (stepEntry != null) {
        metrics['steps'] = stepEntry.steps;
        metrics['activeMinutes'] = stepEntry.activeMinutes ?? 0;
        metrics['caloriesBurned'] = stepEntry.caloriesBurned ?? 0;
      }
      
      // Get water using EXISTING repository method (same as reports page)
      final waterEntry = await WaterRepository.getTodayWaterEntry(userId);
      if (waterEntry != null) {
        metrics['water'] = waterEntry.glassesConsumed;
      }
      
      // Get exercise data using EXISTING API method
      final exercises = await _exerciseApi.getExerciseHistory(userId, date: today);
      for (var exercise in exercises) {
        metrics['activeMinutes'] += (exercise['duration_minutes'] ?? 0) as int;
        metrics['caloriesBurned'] += (exercise['calories_burned'] ?? 0) as int;
      }
      
      // Get meals using EXISTING API method
      final mealsData = await _apiService.getDailySummary(userId, date: today);
      if (mealsData['success'] == true) {
        metrics['caloriesConsumed'] = (mealsData['totals']['calories'] ?? 0).toInt();
      }
      
      return metrics;
    } catch (e) {
      print('Error fetching metrics: $e');
      return {
        'steps': 0,
        'water': 0,
        'activeMinutes': 0,
        'caloriesBurned': 0,
        'caloriesConsumed': 0,
      };
    }
  }

  // Add update methods using EXISTING repositories
  Future<void> updateWater(String userId, int glasses) async {
    final waterEntry = WaterEntry(
      userId: userId,
      date: DateTime.now(),
      glassesConsumed: glasses,
      totalMl: glasses * 250.0,
      targetMl: 2000.0,
    );
    await WaterRepository.saveWaterEntry(waterEntry);
  }

  Future<void> updateSteps(String userId, int steps, {int? goal}) async {
    final stepEntry = StepEntry(
      userId: userId,
      date: DateTime.now(),
      steps: steps,
      goal: goal ?? 10000,
    );
    await StepRepository.saveStepEntry(stepEntry);
  }
}