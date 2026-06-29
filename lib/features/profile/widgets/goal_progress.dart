// lib/features/profile/widgets/goal_progress.dart
import 'package:flutter/material.dart';

class GoalProgress extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final List<Map<String, dynamic>>? goals; // Optional for backward compatibility

  const GoalProgress({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    this.goals,
  }) : super(key: key);

  // Alternative constructor for the new goals-based approach
  const GoalProgress.fromGoals({
    Key? key,
    required List<Map<String, dynamic>> goals,
  }) : title = '',
       subtitle = '',
       progress = 0.0,
       color = Colors.blue,
       goals = goals,
       super(key: key);

  @override
  Widget build(BuildContext context) {
    // If goals list is provided, use the new format
    if (goals != null && goals!.isNotEmpty) {
      return _buildGoalsList(context);
    }

    // Otherwise use the single goal format
    return _buildSingleGoal(context);
  }

  Widget _buildSingleGoal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(BuildContext context) {
    return Column(
      children: goals!.map((goal) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 0,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (goal['color'] as Color? ?? Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  goal['icon'] as IconData? ?? Icons.flag,
                  color: goal['color'] as Color? ?? Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal['title'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goal['subtitle'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (goal['progress'] as double? ?? 0.0).clamp(0.0, 1.0),
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        goal['color'] as Color? ?? Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${((goal['progress'] as double? ?? 0.0) * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: goal['color'] as Color? ?? Colors.blue,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}