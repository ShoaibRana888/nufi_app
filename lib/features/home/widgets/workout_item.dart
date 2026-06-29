// lib/features/home/widgets/workout_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/daily_metrics.dart';

class WorkoutItem extends StatelessWidget {
  final WorkoutSession workout;
  final VoidCallback? onTap;

  const WorkoutItem({
    Key? key,
    required this.workout,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            _buildWorkoutIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.workoutType,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(workout.date),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMetric(
                        Icons.timer,
                        '${workout.durationMinutes} min',
                        Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      _buildMetric(
                        Icons.local_fire_department,
                        '${workout.caloriesBurned.toInt()} cal',
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                _buildIntensityBadge(),
                const SizedBox(height: 8),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutIcon() {
    IconData iconData;
    Color backgroundColor;

    switch (workout.workoutType.toLowerCase()) {
      case 'running':
      case 'morning run':
        iconData = Icons.directions_run;
        backgroundColor = Colors.green;
        break;
      case 'cycling':
        iconData = Icons.directions_bike;
        backgroundColor = Colors.blue;
        break;
      case 'upper body':
      case 'strength':
        iconData = Icons.fitness_center;
        backgroundColor = Colors.purple;
        break;
      case 'yoga':
        iconData = Icons.self_improvement;
        backgroundColor = Colors.pink;
        break;
      case 'swimming':
        iconData = Icons.pool;
        backgroundColor = Colors.cyan;
        break;
      case 'cardio':
        iconData = Icons.favorite;
        backgroundColor = Colors.red;
        break;
      default:
        iconData = Icons.sports_gymnastics;
        backgroundColor = Colors.orange;
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: backgroundColor,
        size: 24,
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityBadge() {
    Color badgeColor;
    switch (workout.intensity.toLowerCase()) {
      case 'high':
        badgeColor = Colors.red;
        break;
      case 'medium':
        badgeColor = Colors.orange;
        break;
      case 'low':
        badgeColor = Colors.green;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        workout.intensity,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today • ${DateFormat('h:mm a').format(date)}';
    } else if (difference == 1) {
      return 'Yesterday • ${DateFormat('h:mm a').format(date)}';
    } else if (difference < 7) {
      return '${difference} days ago • ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM dd • h:mm a').format(date);
    }
  }
}

// Compact version for smaller lists
class CompactWorkoutItem extends StatelessWidget {
  final WorkoutSession workout;
  final VoidCallback? onTap;

  const CompactWorkoutItem({
    Key? key,
    required this.workout,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: _getWorkoutColor(),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.workoutType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${workout.durationMinutes}m • ${workout.caloriesBurned.toInt()} cal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatCompactDate(workout.date),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getWorkoutColor() {
    switch (workout.workoutType.toLowerCase()) {
      case 'running':
      case 'morning run':
        return Colors.green;
      case 'cycling':
        return Colors.blue;
      case 'upper body':
      case 'strength':
        return Colors.purple;
      case 'yoga':
        return Colors.pink;
      default:
        return Colors.orange;
    }
  }

  String _formatCompactDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      return '${difference}d ago';
    }
  }
}

// Weekly workout summary widget
class WeeklyWorkoutSummary extends StatelessWidget {
  final List<WorkoutSession> workouts;
  final int weeklyGoal;

  const WeeklyWorkoutSummary({
    Key? key,
    required this.workouts,
    this.weeklyGoal = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final thisWeekWorkouts = _getThisWeekWorkouts();
    final totalDuration = thisWeekWorkouts.fold<int>(
      0, (sum, workout) => sum + workout.durationMinutes
    );
    final totalCalories = thisWeekWorkouts.fold<double>(
      0, (sum, workout) => sum + workout.caloriesBurned
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'This Week',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${thisWeekWorkouts.length}/$weeklyGoal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStat(
                  'Duration',
                  '${totalDuration}m',
                  Icons.timer,
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Calories',
                  '${totalCalories.toInt()}',
                  Icons.local_fire_department,
                ),
              ),
              Expanded(
                child: _buildStat(
                  'Sessions',
                  '${thisWeekWorkouts.length}',
                  Icons.fitness_center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<WorkoutSession> _getThisWeekWorkouts() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return workouts.where((workout) {
      return workout.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
             workout.date.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();
  }
}