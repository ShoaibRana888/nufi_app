import 'package:flutter/material.dart';

class RecoveryTimer extends StatelessWidget {
  final List<Map<String, dynamic>> muscleGroups;
  
  const RecoveryTimer({
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
                Icons.update,
                color: Colors.deepPurple,
              ),
              SizedBox(width: 8),
              Text(
                'Muscle Recovery Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Optimal time between training the same muscle group',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          // Muscle recovery grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: muscleGroups.length,
            itemBuilder: (context, index) {
              final group = muscleGroups[index];
              return _buildMuscleRecoveryCard(
                context,
                group['name'],
                group['lastTrainedDays'],
                group['recoveryDays'],
                group['icon'] ?? Icons.fitness_center,
              );
            },
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Recovery tips
          const Text(
            'Recovery Tips',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          // Sample recovery tip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb,
                color: Colors.amber[700],
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Focus on chest, shoulders and triceps today since your back and legs are still recovering.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMuscleRecoveryCard(
    BuildContext context,
    String name,
    int lastTrainedDays,
    int recoveryDays,
    IconData icon,
  ) {
    // Calculate recovery percentage
    final recoveryPercentage = (lastTrainedDays / recoveryDays).clamp(0.0, 1.0);
    final isRecovered = recoveryPercentage >= 1.0;
    
    // Determine status color
    Color statusColor;
    String statusText;
    
    if (isRecovered) {
      statusColor = Colors.green;
      statusText = 'Ready';
    } else if (recoveryPercentage > 0.7) {
      statusColor = Colors.orange;
      statusText = 'Soon';
    } else {
      statusColor = Colors.red;
      statusText = 'Resting';
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
          // Muscle name
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Progress circle - IMPROVED
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: SizedBox(
              height: 80, // Increased from 60
              width: 80, // Increased from 60
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer circle with progress
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: CircularProgressIndicator(
                      value: recoveryPercentage,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      strokeWidth: 8, // Made slightly thicker
                    ),
                  ),
                  
                  // Background circle for the icon
                  Container(
                    height: 58, // Increased from 45
                    width: 58, // Increased from 45
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  
                  // Body part icon
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getMuscleIcon(name),
                        size: 28, // Increased from 20
                        color: statusColor,
                      ),
                      Text(
                        '$lastTrainedDays/$recoveryDays',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Status text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Get a more representative icon for each muscle group
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