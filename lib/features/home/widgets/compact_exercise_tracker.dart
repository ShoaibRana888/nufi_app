import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/tracking/screens/exercise_logging_page.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CompactExerciseTracker extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onUpdate;

  const CompactExerciseTracker({
    Key? key,
    required this.userProfile,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<CompactExerciseTracker> createState() => _CompactExerciseTrackerState();
}

class _CompactExerciseTrackerState extends State<CompactExerciseTracker> {
  final ExerciseApi _apiService = ExerciseApi();
  int _todayMinutes = 0;
  int _todayExercises = 0;
  int _weeklyExercises = 0;
  Set<String> _weeklyMuscleGroups = {};
  bool _isLoading = true;
  late int _dailyGoal;

  @override
  void initState() {
    super.initState();
    _initializeExerciseGoal();
    _loadExerciseData();
  }

  void _initializeExerciseGoal() {
    // Get exercise goal from user profile
    if (widget.userProfile.workoutDuration != null) {
      _dailyGoal = widget.userProfile.workoutDuration;
    } else {
      // Default fallback if no exercise goal is set
      _dailyGoal = 30; // 30 minutes default
    }
    
    // Ensure exercise goal is reasonable (between 10 and 180 minutes)
    _dailyGoal = _dailyGoal.clamp(10, 180);
  }

  @override
  void didUpdateWidget(CompactExerciseTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _initializeExerciseGoal();
      _loadExerciseData();
    }
  }

  Future<void> _loadExerciseData() async {
    setState(() => _isLoading = true);
    
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      
      // Calculate start of week (Monday)
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      // Load today's exercise data
      final todayExercises = await _apiService.getExerciseLogs(
        widget.userProfile.id,
        startDate: today,
        endDate: today,
      );
      
      // Load this week's exercise data
      final weekExercises = await _apiService.getExerciseLogs(
        widget.userProfile.id,
        startDate: weekStartStr,
        endDate: today,
      );
      
      // Calculate today's total minutes
      int todayMinutes = 0;
      int todayCount = 0;
      if (todayExercises != null && todayExercises.isNotEmpty) {
        for (var exercise in todayExercises) {
          // Check if the exercise date is actually today
          final exerciseDate = exercise['exercise_date'] ?? exercise['created_at'];
          if (exerciseDate != null && exerciseDate.toString().startsWith(today)) {
            // Check if it's a cardio exercise with duration
            if (exercise['duration_minutes'] != null) {
              todayMinutes += (exercise['duration_minutes'] as num?)?.toInt() ?? 0;
            } else {
              // For strength exercises, estimate duration based on sets
              // Typically, a set takes about 1-2 minutes including rest
              final sets = (exercise['sets'] as num?)?.toInt() ?? 0;
              final exerciseType = exercise['exercise_type'] as String?;
              
              if (sets > 0) {
                // Estimate: 2 minutes per set for strength training (includes rest)
                // This is a reasonable approximation for tracking purposes
                final estimatedMinutes = sets * 2;
                todayMinutes += estimatedMinutes;
              }
            }
            todayCount++;
          }
        }
      }
      
      // Calculate weekly stats and muscle groups
      int weeklyCount = 0;
      Set<String> muscleGroups = {};
      
      if (weekExercises != null && weekExercises.isNotEmpty) {
        for (var exercise in weekExercises) {
          final exerciseDate = exercise['exercise_date'] ?? exercise['created_at'];
          if (exerciseDate != null) {
            final exDate = DateTime.parse(exerciseDate.toString());
            // Only count exercises from this week
            if (exDate.isAfter(weekStart.subtract(Duration(days: 1)))) {
              weeklyCount++;
              
              // Track muscle groups
              final muscleGroup = exercise['muscle_group'] as String?;
              if (muscleGroup != null && muscleGroup != 'general') {
                muscleGroups.add(muscleGroup);
              }
            }
          }
        }
      }
      
      setState(() {
        _todayMinutes = todayMinutes;
        _todayExercises = todayCount;
        _weeklyExercises = weeklyCount;
        _weeklyMuscleGroups = muscleGroups;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading exercise data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _navigateToExerciseLogging() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedExerciseLoggingPage(
          userProfile: widget.userProfile,
        ),
      ),
    ).then((_) {
      _loadExerciseData();
      widget.onUpdate?.call();
    });
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanMuscleGroupChips() {
    final muscleIcons = {
      'chest': Icons.fitness_center,
      'back': Icons.rowing,
      'shoulders': Icons.accessibility_new,
      'arms': Icons.sports_handball,
      'legs': Icons.directions_run,
      'core': Icons.self_improvement,
      'cardio': Icons.favorite,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _weeklyMuscleGroups.map((muscle) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), // Uniform color for all chips
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muscleIcons[muscle.toLowerCase()] ?? Icons.fitness_center,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                muscle.substring(0, 1).toUpperCase() + muscle.substring(1),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_todayMinutes / _dailyGoal).clamp(0.0, 1.0);
    final bool goalMet = _todayMinutes >= _dailyGoal;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: goalMet
              ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]  // Green when goal met
              : [const Color(0xFFFF6B35), const Color(0xFFFF9558)],  // Orange default
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: goalMet 
                ? Colors.green.withOpacity(0.3)
                : const Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToExerciseLogging,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Goal Met badge on the right
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        goalMet ? Icons.emoji_events : Icons.fitness_center,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Exercise Tracker',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Daily goal: $_dailyGoal min',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Goal Met Badge on the right
                    if (goalMet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Goal Met!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Progress Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Activity',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$_todayMinutes / $_dailyGoal min',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Progress Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 12,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOutCubic,
                              height: 12,
                              width: constraints.maxWidth * progress,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _todayExercises > 0
                          ? '$_todayExercises exercise${_todayExercises > 1 ? 's' : ''} today'
                          : 'No exercises logged yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Clean Weekly Stats Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_weeklyExercises workouts',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'This week',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 35,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.sports_martial_arts,
                                  size: 20,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_weeklyMuscleGroups.length} trained',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Muscle groups',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_weeklyMuscleGroups.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildCleanMuscleGroupChips(),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Clean Action Button
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _navigateToExerciseLogging,
                      borderRadius: BorderRadius.circular(24),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Log Exercise',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}