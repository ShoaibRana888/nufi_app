// lib/features/reports/screens/today_report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/repositories/step_repository.dart';
import 'package:user_onboarding/data/models/weight_entry.dart';
import 'package:user_onboarding/data/repositories/sleep_repository.dart';
import 'package:user_onboarding/data/services/data_manager.dart';
import 'package:user_onboarding/features/tracking/screens/meal_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/water_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/sleep_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/exercise_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/steps_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/weight_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/supplements_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/activity_logging_menu.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';
import 'package:user_onboarding/data/services/api/water_api.dart';
import 'package:user_onboarding/data/services/api/supplement_api.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';


class TodayReportScreen extends StatefulWidget {
  final UserProfile userProfile;

  const TodayReportScreen({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<TodayReportScreen> createState() => _TodayReportScreenState();
}

class _TodayReportScreenState extends State<TodayReportScreen> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  
  // Tracking data for today
  Map<String, TrackingStatus> trackingStatus = {};
  
  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }
  
  Future<void> _loadTodayData() async {
    setState(() => isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userProfile.id ?? '';
      final todayStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      // Load each category with individual error handling
      final futures = [
        _getMealStatus(prefs, todayStr).catchError((e) {
          print('Meal status error: $e');
          return _getEmptyMealStatus();
        }),
        _getWaterStatus(prefs, todayStr).catchError((e) {
          print('Water status error: $e');
          return _getEmptyWaterStatus();
        }),
        _getSleepStatus(prefs, todayStr).catchError((e) {
          print('Sleep status error: $e');
          return _getEmptySleepStatus();
        }),
        _getExerciseStatus(prefs, todayStr).catchError((e) {
          print('Exercise status error: $e');
          return _getEmptyExerciseStatus();
        }),
        _getStepsStatus(userId).catchError((e) {
          print('Steps status error: $e');
          return _getEmptyStepsStatus();
        }),
        _getWeightStatus(prefs, todayStr).catchError((e) {
          print('Weight status error: $e');
          return _getEmptyWeightStatus();
        }),
        _getSupplementStatus(prefs, todayStr).catchError((e) {
          print('Supplement status error: $e');
          return _getEmptySupplementStatus();
        }),
      ];
      
      final results = await Future.wait(futures);
      
      trackingStatus = {
        'meals': results[0],
        'water': results[1],
        'sleep': results[2],
        'exercise': results[3],
        'steps': results[4],
        'weight': results[5],
        'supplements': results[6],
      };
      
    } catch (e) {
      print('Error loading today data: $e');
      // Set all to empty states
      trackingStatus = {
        'meals': _getEmptyMealStatus(),
        'water': _getEmptyWaterStatus(),
        'sleep': _getEmptySleepStatus(),
        'exercise': _getEmptyExerciseStatus(),
        'steps': _getEmptyStepsStatus(),
        'weight': _getEmptyWeightStatus(),
        'supplements': _getEmptySupplementStatus(),
      };
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<TrackingStatus> _getMealStatus(SharedPreferences prefs, String date) async {
    try {
      final apiService = MealApi();
      final userId = widget.userProfile.id ?? '';

      final dailySummary = await apiService.getDailySummary(
        userId,
        date: date,
      );

      // getDailySummary returns: { 'totals': { 'calories': .. }, 'meals_count': N }
      final mealCount = (dailySummary['meals_count'] as num?)?.toInt() ?? 0;
      final totals = dailySummary['totals'] as Map<String, dynamic>? ?? {};
      final calories = (totals['calories'] as num?)?.toDouble() ?? 0.0;

      // Get user's meal goal from profile
      final mealGoal = widget.userProfile.dailyMealsCount ?? 3;

      return TrackingStatus(
        category: 'Meals',
        icon: Icons.restaurant,
        color: Colors.green,
        completed: mealCount,
        total: mealGoal,  // Use user's meal goal
        details: {
          'Calories': calories.toInt(),
          'Status': mealCount >= mealGoal ? 'Complete' : 'In Progress',
        },
        unit: 'meals',
        isComplete: mealCount >= mealGoal,
        excludeFromProgress: false,
      );

    } catch (e) {
      print('Error getting meal status: $e');
      return _getEmptyMealStatus();
    }
  }
  
  Future<TrackingStatus> _getWaterStatus(SharedPreferences prefs, String date) async {
    try {
      final waterApi = WaterApi();
      final userId = widget.userProfile.id ?? '';

      final waterData = await waterApi.getTodaysWater(userId);
      
      final glasses = (waterData['glasses'] as num? ?? 0).toInt();
      final totalMl = (waterData['total_ml'] as num? ?? 0.0).toDouble();
      
      // Get user's water goal from profile
      final targetGlasses = widget.userProfile.waterIntakeGlasses ?? 8;
      final remaining = (targetGlasses - glasses).clamp(0, targetGlasses);
      
      await prefs.setInt('water_glasses_$date', glasses);
      
      return TrackingStatus(
        category: 'Water',
        icon: Icons.water_drop,
        color: Colors.blue,
        completed: glasses,
        total: targetGlasses,  // Use user's water goal
        details: {
          'Consumed': '$glasses glasses',
          'Target': '$targetGlasses glasses',
          'Remaining': '$remaining glasses',
          'Volume': '${totalMl.toInt()}ml',
          'Status': glasses >= targetGlasses ? 'Complete' : 'In Progress',
        },
        unit: 'glasses',
        isComplete: glasses >= targetGlasses,
        excludeFromProgress: false,
      );
      
    } catch (e) {
      print('Error getting water status: $e');
      
      // Fallback with user's goal
      final glasses = prefs.getInt('water_glasses_$date') ?? 0;
      final targetGlasses = widget.userProfile.waterIntakeGlasses ?? 8;
      
      return TrackingStatus(
        category: 'Water',
        icon: Icons.water_drop,
        color: Colors.blue,
        completed: glasses,
        total: targetGlasses,
        details: {
          'Consumed': '$glasses glasses',
          'Target': '$targetGlasses glasses',
          'Remaining': '${targetGlasses - glasses} glasses',
          'Status': glasses >= targetGlasses ? 'Complete' : 'In Progress',
        },
        unit: 'glasses',
        isComplete: glasses >= targetGlasses,
        excludeFromProgress: false,
      );
    }
  }
  
  Future<TrackingStatus> _getSleepStatus(SharedPreferences prefs, String date) async {
    try {
      final sleepRepo = SleepRepository();
      final sleepEntry = await sleepRepo.getSleepEntryByDate(
        widget.userProfile.id ?? '',
        selectedDate
      );
      
      // Get user's sleep goal from profile
      final goalHours = widget.userProfile.sleepHours ?? 8.0;
      
      if (sleepEntry != null) {
        return TrackingStatus(
          category: 'Sleep',
          icon: Icons.bedtime,
          color: Colors.purple,
          completed: sleepEntry.totalHours.toInt(),
          total: goalHours.toInt(),
          details: {
            'Duration': '${sleepEntry.totalHours.toStringAsFixed(1)} hours',
            'Target': '${goalHours.toStringAsFixed(1)} hours',
            'Quality': 'Score: ${sleepEntry.qualityScore ?? 0}',
            'Status': sleepEntry.totalHours >= goalHours ? 'Complete' : 'Insufficient',
          },
          unit: 'hours',
          isComplete: sleepEntry.totalHours >= goalHours,
          excludeFromProgress: false,
        );
      }
    } catch (e) {
      print('Error getting sleep status: $e');
    }
    
    final goalHours = widget.userProfile.sleepHours ?? 8.0;
    return TrackingStatus(
      category: 'Sleep',
      icon: Icons.bedtime,
      color: Colors.purple,
      completed: 0,
      total: goalHours.toInt(),
      details: {
        'Status': 'Not logged',
        'Target': '${goalHours.toStringAsFixed(1)} hours',
      },
      unit: 'hours',
      isComplete: false,
      excludeFromProgress: false,
    );
  }
  
  Future<TrackingStatus> _getExerciseStatus(SharedPreferences prefs, String date) async {
    try {
      // Exercise logs live on the backend (same source as the dashboard tracker),
      // not in SharedPreferences. Fetch today's logs from the API.
      final exercises = await ExerciseApi().getExerciseLogs(
        widget.userProfile.id ?? '',
        startDate: date,
        endDate: date,
      );

      // Get user's workout goal from profile
      final goalMinutes = widget.userProfile.workoutDuration ?? 30;

      // Only count exercises actually dated today.
      final todays = exercises.where((ex) {
        final exDate = (ex['exercise_date'] ?? ex['created_at'])?.toString();
        return exDate != null && exDate.startsWith(date);
      }).toList();

      if (todays.isNotEmpty) {
        int totalMinutes = 0;
        for (final ex in todays) {
          if (ex['duration_minutes'] != null) {
            totalMinutes += (ex['duration_minutes'] as num?)?.toInt() ?? 0;
          } else {
            // Strength sets: estimate ~2 minutes per set (matches dashboard tracker).
            final sets = (ex['sets'] as num?)?.toInt() ?? 0;
            if (sets > 0) totalMinutes += sets * 2;
          }
        }

        return TrackingStatus(
          category: 'Exercise',
          icon: Icons.fitness_center,
          color: Colors.orange,
          completed: totalMinutes,
          total: goalMinutes,
          details: {
            'Duration': '$totalMinutes min',
            'Target': '$goalMinutes min',
            'Sessions': todays.length,
            'Status': totalMinutes >= goalMinutes ? 'Complete' : 'In Progress',
          },
          unit: 'min',
          isComplete: totalMinutes >= goalMinutes,
          excludeFromProgress: false,
        );
      }
    } catch (e) {
      print('Error getting exercise status: $e');
    }
    
    final goalMinutes = widget.userProfile.workoutDuration ?? 30;
    return TrackingStatus(
      category: 'Exercise',
      icon: Icons.fitness_center,
      color: Colors.orange,
      completed: 0,
      total: goalMinutes,
      details: {
        'Duration': '0 min',
        'Target': '$goalMinutes min',
        'Sessions': 0,
        'Status': 'Not logged',
      },
      unit: 'min',
      isComplete: false,
      excludeFromProgress: false,
    );
  }
  
  Future<TrackingStatus> _getStepsStatus(String userId) async {
    try {
      // Use the correct method name from StepRepository
      final todayEntry = await StepRepository.getTodayStepEntry(userId);
      
      // Get user's step goal from profile
      final userGoal = widget.userProfile.dailyStepGoal ?? 10000;
      
      if (todayEntry != null) {
        final distance = (todayEntry.steps * 0.0008).toStringAsFixed(1);
        final calories = (todayEntry.steps * 0.04).toInt();
        
        return TrackingStatus(
          category: 'Steps',
          icon: Icons.directions_walk,
          color: Colors.green.shade700,
          completed: todayEntry.steps,
          total: userGoal,
          details: {
            'Steps': '${todayEntry.steps}',
            'Goal': '$userGoal',
            'Distance': '$distance km',
            'Calories': '$calories cal',
            'Status': todayEntry.steps >= userGoal ? 'Complete' : 'In Progress',
          },
          unit: 'steps',
          isComplete: todayEntry.steps >= userGoal,
          excludeFromProgress: false,
        );
      }
    } catch (e) {
      print('Error getting steps status: $e');
    }
    
    final userGoal = widget.userProfile.dailyStepGoal ?? 10000;
    return TrackingStatus(
      category: 'Steps',
      icon: Icons.directions_walk,
      color: Colors.green.shade700,
      completed: 0,
      total: userGoal,
      details: {
        'Steps': '0',
        'Goal': '$userGoal',
        'Distance': '0.0 km',
        'Calories': '0 cal',
        'Status': 'Not tracked',
      },
      unit: 'steps',
      isComplete: false,
      excludeFromProgress: false,
    );
  }
  
  Future<TrackingStatus> _getWeightStatus(SharedPreferences prefs, String date) async {
    try {
      // Try to get from DataManager/Repository first
      final dataManager = DataManager();
      final history = await dataManager.getWeightHistory(
        widget.userProfile.id ?? '',
        limit: 30,
      );
      
      // Check if there's an entry for today
      final todayEntry = history.firstWhere(
        (entry) => 
          entry.date.year == selectedDate.year &&
          entry.date.month == selectedDate.month &&
          entry.date.day == selectedDate.day,
        orElse: () => WeightEntry(
          userId: '',
          date: DateTime(1900), // Dummy date to indicate not found
          weight: 0,
        ),
      );
      
      if (todayEntry.date.year != 1900) {
        return TrackingStatus(
          category: 'Weight',
          icon: Icons.monitor_weight,
          color: Colors.indigo,
          completed: 1,
          total: 1,
          details: {
            'Weight': '${todayEntry.weight.toStringAsFixed(1)} kg',
            'BMI': _calculateBMI(todayEntry.weight),
            'Status': 'Logged',
            'Time': DateFormat('hh:mm a').format(todayEntry.date),
          },
          unit: '',
          isComplete: true,
          excludeFromProgress: false,
        );
      }
      
      // Fallback to SharedPreferences
      final hasEntry = prefs.getBool('weight_logged_$date') ?? false;
      final weight = prefs.getDouble('weight_$date') ?? 0;
      
      if (hasEntry) {
        return TrackingStatus(
          category: 'Weight',
          icon: Icons.monitor_weight,
          color: Colors.indigo,
          completed: 1,
          total: 1,
          details: {
            'Weight': '${weight.toStringAsFixed(1)} kg',
            'Status': 'Logged',
          },
          unit: '',
          isComplete: true,
          excludeFromProgress: false,
        );
      }
      
      // No entry found
      return TrackingStatus(
        category: 'Weight',
        icon: Icons.monitor_weight,
        color: Colors.indigo,
        completed: 0,
        total: 1,
        details: {
          'Status': 'Not logged',
        },
        unit: '',
        isComplete: false,
        excludeFromProgress: false,
      );
    } catch (e) {
      print('Error getting weight status: $e');
      return TrackingStatus(
        category: 'Weight',
        icon: Icons.monitor_weight,
        color: Colors.indigo,
        completed: 0,
        total: 1,
        unit: '',
        isComplete: false,
        excludeFromProgress: false,
      );
    }
  }

  Future<TrackingStatus> _getSupplementStatus(SharedPreferences prefs, String date) async {
    try {
      final apiService = SupplementApi();
      final userId = widget.userProfile.id ?? '';

      // Get user's supplement preferences
      final supplementData = await apiService.getSupplementStatus(userId, date: date);
      
      if (supplementData['success'] == true) {
        final supplements = supplementData['supplements'] as List? ?? [];
        final takenCount = supplements.where((s) => s['taken'] == true).length;
        final totalCount = supplements.length;
        
        if (totalCount == 0) {
          return TrackingStatus(
            category: 'Supplements',
            icon: Icons.medication,
            color: Colors.teal,
            completed: 0,
            total: 0,
            details: {'Status': 'Not configured'},
            unit: 'pills',
            isComplete: false,
            excludeFromProgress: true,
          );
        }
        
        return TrackingStatus(
          category: 'Supplements',
          icon: Icons.medication,
          color: Colors.teal,
          completed: takenCount,
          total: totalCount,
          details: {
            'Taken': takenCount,
            'Total': totalCount,
            'Status': takenCount >= totalCount ? 'Complete' : 'In Progress',
          },
          unit: 'pills',
          isComplete: takenCount >= totalCount,
          excludeFromProgress: false,
        );
      }
    } catch (e) {
      print('Error getting supplement status: $e');
    }
    
    return _getEmptySupplementStatus();
}

  TrackingStatus _getEmptyMealStatus() {
    final mealGoal = widget.userProfile.dailyMealsCount ?? 3;
    return TrackingStatus(
      category: 'Meals',
      icon: Icons.restaurant,
      color: Colors.green,
      completed: 0,
      total: mealGoal,
      details: {'Status': 'Not logged'},
      unit: 'meals',
      isComplete: false,
      excludeFromProgress: false,
    );
  }

  TrackingStatus _getEmptySupplementStatus() {
    return TrackingStatus(
      category: 'Supplements',
      icon: Icons.medication,
      color: Colors.teal,
      completed: 0,
      total: 0,
      details: {'Status': 'Not configured'},
      unit: 'pills',
      isComplete: false,
      excludeFromProgress: true,
    );
  }

  TrackingStatus _getEmptyWaterStatus() {
    final waterGoal = widget.userProfile.waterIntakeGlasses ?? 8;
    return TrackingStatus(
      category: 'Water',
      icon: Icons.water_drop,
      color: Colors.blue,
      completed: 0,
      total: waterGoal,
      details: {
        'Consumed': 0,
        'Target': waterGoal,
        'Remaining': waterGoal,
        'Status': 'Not logged',
      },
      unit: 'glasses',
      isComplete: false,
      excludeFromProgress: false,
    );
  }

  TrackingStatus _getEmptySleepStatus() {
    final sleepGoal = widget.userProfile.sleepHours ?? 8.0;
    return TrackingStatus(
      category: 'Sleep',
      icon: Icons.bedtime,
      color: Colors.purple,
      completed: 0,
      total: sleepGoal.toInt(),
      details: {
        'Status': 'Not logged',
        'Target': '${sleepGoal.toStringAsFixed(1)} hours',
      },
      unit: 'hours',
      isComplete: false,
      excludeFromProgress: false,
    );
  }

  TrackingStatus _getEmptyExerciseStatus() {
    final exerciseGoal = widget.userProfile.workoutDuration ?? 30;
    return TrackingStatus(
      category: 'Exercise',
      icon: Icons.fitness_center,
      color: Colors.orange,
      completed: 0,
      total: exerciseGoal,
      details: {
        'Duration': '0 min',
        'Target': '$exerciseGoal min',
        'Calories': 'Not tracked',
        'Sessions': 0,
        'Status': 'Not logged',
      },
      unit: 'min',
      isComplete: false,
      excludeFromProgress: false,
    );
  }

  TrackingStatus _getEmptyStepsStatus() {
    final stepGoal = widget.userProfile.dailyStepGoal ?? 10000;
    return TrackingStatus(
      category: 'Steps',
      icon: Icons.directions_walk,
      color: Colors.green.shade700,
      completed: 0,
      total: stepGoal,
      details: {
        'Steps': '0',
        'Goal': '$stepGoal',
        'Distance': '0.0 km',
        'Calories': '0 cal',
        'Status': 'Not tracked',
      },
      unit: 'steps',
      isComplete: false,
      excludeFromProgress: false,
    );
  }

  TrackingStatus _getEmptyWeightStatus() {
    return TrackingStatus(
      category: 'Weight',
      icon: Icons.monitor_weight,
      color: Colors.indigo,
      completed: 0,
      total: 1,
      details: {
        'Status': 'Not logged',
      },
      unit: '',
      isComplete: false,
      excludeFromProgress: false,
    );
  }

  // Helper method to calculate BMI
  String _calculateBMI(double weight) {
    final height = widget.userProfile.height ?? 170; // Default height
    final heightInMeters = height / 100;
    final bmi = weight / (heightInMeters * heightInMeters);
    return 'BMI: ${bmi.toStringAsFixed(1)}';
  }
  
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Report'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _selectDate,
              ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTodayData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildOverallProgress(),
                    _buildTrackingGrid(),
                    _buildMissingActivities(),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(selectedDate),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getCompletionMessage(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOverallProgress() {
    final completed = trackingStatus.values.where((s) => s.isComplete).length;
    final total = trackingStatus.length;
    final percentage = total > 0 ? (completed / total) : 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$completed/$total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getProgressColor(percentage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(percentage),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(percentage * 100).toInt()}% Complete',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTrackingGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemCount: trackingStatus.length,
        itemBuilder: (context, index) {
          final key = trackingStatus.keys.elementAt(index);
          final status = trackingStatus[key]!;
          return _buildTrackingCard(status);
        },
      ),
    );
  }
  
  Widget _buildTrackingCard(TrackingStatus status) {
    final progress = status.total > 0 
        ? (status.completed / status.total).clamp(0.0, 1.0) 
        : 0.0;
    
    // Special handling for unconfigured/disabled items
    final isUnconfigured = status.excludeFromProgress;
    final isSupplementsUnconfigured = status.category == 'Supplements' && status.total == 0;
    
    return InkWell(
      onTap: () => _navigateToTracking(status.category),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isUnconfigured || isSupplementsUnconfigured) 
              ? Colors.grey.shade50 
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isUnconfigured || isSupplementsUnconfigured)
                ? Colors.grey.shade300
                : status.isComplete 
                    ? status.color.withOpacity(0.3)
                    : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  status.icon,
                  color: (isUnconfigured || isSupplementsUnconfigured) 
                      ? Colors.grey 
                      : status.color,
                  size: 24,
                ),
                if (status.isComplete && !isUnconfigured && !isSupplementsUnconfigured)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  )
                else if (isSupplementsUnconfigured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Setup',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              status.category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: (isUnconfigured || isSupplementsUnconfigured) 
                    ? Colors.grey 
                    : Colors.black87,
              ),
            ),
            Text(
              _getStatusDisplay(status),
              style: TextStyle(
                fontSize: 10,
                color: (isUnconfigured || isSupplementsUnconfigured)
                    ? Colors.grey.shade500 
                    : Colors.grey.shade600,
              ),
            ),
            if (!isUnconfigured && !isSupplementsUnconfigured && status.total > 0)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                ),
              )
            else
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _getStatusDisplay(TrackingStatus status) {
    if (status.category == 'Weight') {
      return status.isComplete ? 'Logged' : 'Not logged';
    } else if (status.category == 'Supplements') {
      if (status.total == 0) {
        if (status.details['Status'] == 'Tracking disabled') {
          return 'Disabled';
        }
        return 'Not configured';
      }
      return '${status.completed}/${status.total} ${status.unit}';
    } else if (status.total > 0) {
      return '${status.completed}/${status.total} ${status.unit}';
    } else {
      return status.isComplete ? 'Complete' : 'Pending';
    }
  }
  
  Widget _buildMissingActivities() {
    // Get items that are incomplete and should be tracked
    final missing = trackingStatus.entries
        .where((e) => !e.value.isComplete && !e.value.excludeFromProgress)
        .toList();
    
    // Check supplements status
    final supplementsEntry = trackingStatus['supplements'];
    final supplementsNotConfigured = supplementsEntry != null && 
        supplementsEntry.total == 0 && 
        supplementsEntry.details['Status'] == 'Not configured';
    
    if (missing.isEmpty && !supplementsNotConfigured) {
      // Success state - everything complete
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.green.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perfect Day! 🌟',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'All activities completed',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // Build the missing activities card
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                missing.isNotEmpty ? 'Missing Activities' : 'Suggestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            
            // Show missing tracked activities (including configured supplements)
            ...missing.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () => _navigateToTracking(entry.value.category),
                child: Row(
                  children: [
                    Icon(
                      entry.value.icon,
                      color: entry.value.color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.value.category,
                            style: const TextStyle(fontSize: 12),
                          ),
                          // Show which supplements are remaining if applicable
                          if (entry.value.category == 'Supplements' && 
                              entry.value.details.containsKey('Remaining'))
                            Text(
                              '${entry.value.details['Remaining']} supplements remaining',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            )
                          else if (entry.value.details.containsKey('Status'))
                            Text(
                              entry.value.details['Status'].toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            )),
          ],
          
          // Show supplements setup suggestion ONLY if not configured
          if (supplementsNotConfigured) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _navigateToTracking('Supplements'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.medication, color: Colors.teal.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set up supplement tracking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Track daily vitamins and supplements',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: Colors.teal.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityLoggingMenu(
                      userProfile: widget.userProfile,
                    ),
                  ),
                ).then((_) => _loadTodayData());
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Log Activity'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareProgress,
              icon: const Icon(Icons.share),
              label: const Text('Share Progress'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      _loadTodayData();
    }
  }
  
  void _navigateToTracking(String category) {
    Widget? page;
    
    switch (category.toLowerCase()) {
      case 'meals':
        page = EnhancedMealLoggingPage(userProfile: widget.userProfile);
        break;
      case 'water':
        page = WaterLoggingPage(userProfile: widget.userProfile);
        break;
      case 'sleep':
        page = SleepLoggingPage(userProfile: widget.userProfile);
        break;
      case 'exercise':
        page = EnhancedExerciseLoggingPage(userProfile: widget.userProfile);
        break;
      case 'steps':
        page = StepsLoggingPage(userProfile: widget.userProfile);
        break;
      case 'weight':
        page = WeightLoggingPage(userProfile: widget.userProfile);
        break;
      case 'supplements':
        page = SupplementLoggingPage(userProfile: widget.userProfile);
        break;
    }
    
    if (page != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page!),
      ).then((_) => _loadTodayData());
    }
  }
  
  void _shareProgress() {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon!')),
    );
  }
  
  String _getCompletionMessage() {
    final completed = trackingStatus.values.where((s) => s.isComplete).length;
    final total = trackingStatus.length;
    
    if (completed == total) {
      return '🎉 All activities completed!';
    } else if (completed >= total * 0.7) {
      return '💪 Almost there! ${total - completed} activities left';
    } else if (completed >= total * 0.5) {
      return '📈 Good progress! Keep going';
    } else {
      return '🚀 Let\'s track your activities';
    }
  }
  
  Color _getProgressColor(double percentage) {
    if (percentage >= 1.0) return Colors.green;
    if (percentage >= 0.7) return Colors.lightGreen;
    if (percentage >= 0.5) return Colors.orange;
    return Colors.red;
  }
  
  String _getMissingDescription(TrackingStatus status) {
    if (status.total > 0) {
      final remaining = status.total - status.completed;
      return '$remaining ${status.unit} needed';
    }
    return 'Not logged';
  }
}

// Data model for tracking status
class TrackingStatus {
  final String category;
  final IconData icon;
  final Color color;
  final int completed;
  final int total;
  final Map<String, dynamic> details;
  final String unit;
  final bool isComplete;
  final bool excludeFromProgress; 

  TrackingStatus({
    required this.category,
    required this.icon,
    required this.color,
    required this.completed,
    required this.total,
    this.details = const {},
    this.unit = '',
    required this.isComplete,
    this.excludeFromProgress = false,
  });
}