// lib/features/reports/screens/today_report_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/weight_entry.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/models/sleep_entry.dart';
import 'package:user_onboarding/data/models/day_snapshot.dart';
import 'package:user_onboarding/data/services/daily_snapshot.dart';
import 'package:user_onboarding/features/home/widgets/card_load_error.dart';
import 'package:user_onboarding/features/tracking/screens/meal_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/water_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/sleep_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/exercise_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/steps_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/weight_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/supplements_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/activity_logging_menu.dart';


class TodayReportScreen extends StatefulWidget {
  final UserProfile userProfile;

  /// Injected for tests; production defaults to a fresh [DailySnapshot].
  final DailySnapshot? dailySnapshot;

  const TodayReportScreen({
    Key? key,
    required this.userProfile,
    this.dailySnapshot,
  }) : super(key: key);

  @override
  State<TodayReportScreen> createState() => _TodayReportScreenState();
}

class _TodayReportScreenState extends State<TodayReportScreen> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  
  // Tracking data for today
  Map<String, TrackingStatus> trackingStatus = {};

  late final DailySnapshot _dailySnapshot =
      widget.dailySnapshot ?? DailySnapshot();
  
  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }
  
  Future<void> _loadTodayData() async {
    final userId = widget.userProfile.id ?? '';

    // Cache-first: render an already-loaded day instantly (no spinner), then
    // revalidate behind it. Only show the loader when there's nothing to show.
    final cached = _dailySnapshot.cachedDay(userId, selectedDate);
    if (cached != null) {
      _applyStatuses(cached);
    } else {
      setState(() => isLoading = true);
    }

    try {
      // One fan-out for the whole day; each tracker fails independently inside
      // DailySnapshot, so a broken read degrades only its own card.
      final snap = await _dailySnapshot.forDay(userId, selectedDate);
      _applyStatuses(snap);
    } catch (e) {
      print('Error loading today data: $e');
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Build every tracker card from a single DaySnapshot.
  ///
  /// A section the backend could not read is the card's error state, not
  /// its empty one. `Section.error` has carried that distinction since
  /// ADR-0006; until now this screen read only `.value`, so a failed read
  /// drew "0/8 glasses" -- the lie the model stopped telling and the screen
  /// kept on. Same widget as the dashboard's cards.
  void _applyStatuses(DaySnapshot snap) {
    TrackingStatus status<T>(Section<T> section, TrackingStatus Function(T?) from) =>
        section.isError ? from(null).failed() : from(section.value);

    trackingStatus = {
      'meals': status(snap.meals, _mealStatusFrom),
      'water': status(snap.water, _waterStatusFrom),
      'sleep': status(snap.sleep, _sleepStatusFrom),
      'exercise': status(snap.exercise, _exerciseStatusFrom),
      'steps': status(snap.steps, _stepsStatusFrom),
      'weight': status(snap.weight, _weightStatusFrom),
      'supplements': status(snap.supplements, _supplementStatusFrom),
    };
    if (mounted) setState(() {});
  }

  TrackingStatus _mealStatusFrom(MealsDay? meals) {
    if (meals == null) return _getEmptyMealStatus();

    final mealCount = meals.count;
    final calories = meals.calories;
    final mealGoal = widget.userProfile.dailyMealsCount ?? 3;

    return TrackingStatus(
      category: 'Meals',
      icon: Icons.restaurant,
      color: Colors.green,
      completed: mealCount,
      total: mealGoal,
      details: {
        'Calories': calories.toInt(),
        'Status': mealCount >= mealGoal ? 'Complete' : 'In Progress',
      },
      unit: 'meals',
      isComplete: mealCount >= mealGoal,
      excludeFromProgress: false,
    );
  }
  
  TrackingStatus _waterStatusFrom(WaterEntry? water) {
    final targetGlasses = widget.userProfile.waterIntakeGlasses ?? 8;
    if (water == null) return _getEmptyWaterStatus();

    final glasses = water.glassesConsumed;
    final totalMl = water.totalMl;
    final remaining = (targetGlasses - glasses).clamp(0, targetGlasses);

    return TrackingStatus(
      category: 'Water',
      icon: Icons.water_drop,
      color: Colors.blue,
      completed: glasses,
      total: targetGlasses,
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
  }
  
  TrackingStatus _sleepStatusFrom(SleepEntry? sleepEntry) {
    final goalHours = widget.userProfile.sleepHours ?? 8.0;
    if (sleepEntry == null) return _getEmptySleepStatus();

    return TrackingStatus(
      category: 'Sleep',
      icon: Icons.bedtime,
      color: Colors.purple,
      completed: sleepEntry.totalHours.toInt(),
      total: goalHours.toInt(),
      details: {
        'Duration': '${sleepEntry.totalHours.toStringAsFixed(1)} hours',
        'Target': '${goalHours.toStringAsFixed(1)} hours',
        'Quality': 'Score: ${sleepEntry.qualityScore}',
        'Status': sleepEntry.totalHours >= goalHours ? 'Complete' : 'Insufficient',
      },
      unit: 'hours',
      isComplete: sleepEntry.totalHours >= goalHours,
      excludeFromProgress: false,
    );
  }
  
  TrackingStatus _exerciseStatusFrom(ExerciseDay? exercise) {
    final goalMinutes = widget.userProfile.workoutDuration ?? 30;
    final entries = exercise?.entries ?? const [];
    if (entries.isEmpty) return _getEmptyExerciseStatus();

    // Duration in minutes, with a sets*2 fallback for strength entries that
    // carry no duration (matches the dashboard tracker's estimate).
    int totalMinutes = 0;
    for (final ex in entries) {
      if (ex['duration_minutes'] != null) {
        totalMinutes += (ex['duration_minutes'] as num?)?.toInt() ?? 0;
      } else {
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
        'Sessions': entries.length,
        'Status': totalMinutes >= goalMinutes ? 'Complete' : 'In Progress',
      },
      unit: 'min',
      isComplete: totalMinutes >= goalMinutes,
      excludeFromProgress: false,
    );
  }
  
  TrackingStatus _stepsStatusFrom(StepEntry? todayEntry) {
    final userGoal = widget.userProfile.dailyStepGoal ?? 10000;
    if (todayEntry == null) return _getEmptyStepsStatus();

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
  
  TrackingStatus _weightStatusFrom(WeightEntry? entry) {
    if (entry != null) {
      return TrackingStatus(
        category: 'Weight',
        icon: Icons.monitor_weight,
        color: Colors.indigo,
        completed: 1,
        total: 1,
        details: {
          'Weight': '${entry.weight.toStringAsFixed(1)} kg',
          'BMI': _calculateBMI(entry.weight),
          'Status': 'Logged',
          'Time': DateFormat('hh:mm a').format(entry.date),
        },
        unit: '',
        isComplete: true,
        excludeFromProgress: false,
      );
    }

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

  TrackingStatus _supplementStatusFrom(SupplementsDay? supplements) {
    if (supplements == null || supplements.totalCount == 0) {
      return _getEmptySupplementStatus();
    }

    final takenCount = supplements.takenCount;
    final totalCount = supplements.totalCount;

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
      width: double.infinity,
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
    // A section that could not be read is neither done nor missing; it is
    // not counted either way.
    final read = trackingStatus.values.where((s) => !s.loadFailed);
    final completed = read.where((s) => s.isComplete).length;
    final total = read.length;
    final percentage = total > 0 ? (completed / total) : 0.0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          if (status.loadFailed) {
            return CardLoadError(
              title: status.category,
              icon: status.icon,
              color: status.color,
              onRetry: _loadTodayData,
              compact: true,
            );
          }
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
              ? Colors.grey.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isUnconfigured || isSupplementsUnconfigured)
                ? Colors.grey.withValues(alpha: 0.3)
                : status.isComplete
                    ? status.color.withOpacity(0.3)
                    : Theme.of(context).dividerColor,
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
                      color: Colors.grey.withValues(alpha: 0.3),
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
                    : Theme.of(context).colorScheme.onSurface,
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
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                ),
              )
            else
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
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
    // "Not logged" is a claim about the user's data; a failed read cannot
    // make it, so an unread section is not listed as missing.
    final missing = trackingStatus.entries
        .where((e) => !e.value.isComplete && !e.value.excludeFromProgress &&
            !e.value.loadFailed)
        .toList();
    
    // Check supplements status
    final supplementsEntry = trackingStatus['supplements'];
    final supplementsNotConfigured = supplementsEntry != null && 
        supplementsEntry.total == 0 && 
        supplementsEntry.details['Status'] == 'Not configured';
    
    // "Perfect Day" is a claim about every tracker; a section that could
    // not be read cannot support it, so an unread section blocks the
    // celebration even when everything that was read is complete.
    final anyUnread = trackingStatus.values.any((s) => s.loadFailed);

    if (missing.isEmpty && !supplementsNotConfigured && !anyUnread) {
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
        color: Colors.orange.withValues(alpha: 0.12),
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
                  color: Colors.teal.withValues(alpha: 0.12),
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
    final read = trackingStatus.values.where((s) => !s.loadFailed);
    final completed = read.where((s) => s.isComplete).length;
    final total = read.length;
    final anyUnread = read.length != trackingStatus.length;

    // The numeric progress excludes unread sections; the words do not get
    // to. With every section unread, 0 == 0 is not a completed day.
    if (anyUnread) {
      return '⚠️ Some trackers could not be loaded';
    }
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

  /// The section could not be read. The numbers above are the empty
  /// state's placeholders and must not be shown or counted.
  final bool loadFailed;

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
    this.loadFailed = false,
  });

  /// This tracker's card, marked unreadable: the icon and colour survive
  /// so the cell is still recognisable; nothing else is trusted.
  TrackingStatus failed() => TrackingStatus(
        category: category,
        icon: icon,
        color: color,
        completed: 0,
        total: 0,
        isComplete: false,
        excludeFromProgress: true,
        loadFailed: true,
      );
}