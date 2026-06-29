import 'package:flutter/material.dart';

class MuscleGroupTracker extends StatelessWidget {
  final List<Map<String, dynamic>> muscleGroups;
  
  const MuscleGroupTracker({
    Key? key,
    required this.muscleGroups,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: Colors.green, // Changed from default color
              ),
              SizedBox(width: 8),
              Text(
                'Muscle Group Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Muscle group grid layout
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9, // Adjusted for better proportions
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: muscleGroups.length,
            itemBuilder: (context, index) {
              final muscleGroup = muscleGroups[index];
              return _buildMuscleGroupTile(
                context,
                muscleGroup['name'],
                muscleGroup['progress']
              );
            },
          ),
          
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                // TODO: Navigate to detailed muscle progress
              },
              icon: const Icon(
                Icons.bar_chart,
                size: 16,
              ),
              label: const Text('View Detailed Progress'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMuscleGroupTile(BuildContext context, String name, double progress) {
    // Determine color based on progress
    Color progressColor;
    if (progress < 0.3) {
      progressColor = Colors.red;
    } else if (progress < 0.6) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress circle with icon
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: SizedBox(
              height: 80,
              width: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress indicator
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                  
                  // Center white background for icon
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  // Muscle icon
                  Icon(
                    _getMuscleIcon(name),
                    color: progressColor,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Muscle name
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          
          // Progress percentage
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: progressColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getMuscleIcon(String muscleName) {
    switch (muscleName.toLowerCase()) {
      case 'chest':
        return Icons.accessibility_new; // Person with arms out
      case 'back':
        return Icons.fitness_center; // Weight
      case 'legs':
        return Icons.directions_run; // Running person
      case 'shoulders':
        return Icons.accessibility; // Person 
      case 'arms':
        return Icons.sports_gymnastics; // Person doing activities
      case 'core':
        return Icons.radio_button_unchecked; // Circle for abs
      default:
        return Icons.fitness_center;
    }
  }
}