import 'package:flutter/material.dart';

class WorkoutSplitCalendar extends StatelessWidget {
  final List<Map<String, dynamic>> weekSchedule;
  final int currentDayIndex;
  
  const WorkoutSplitCalendar({
    Key? key,
    required this.weekSchedule,
    this.currentDayIndex = 0,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final List<String> dayAbbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
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
          // Header with title
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.deepPurple,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Weekly Training Split',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Day indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isCurrentDay = index == currentDayIndex;
              return _buildDayCircle(
                context,
                dayAbbreviations[index],
                isCurrentDay,
              );
            }),
          ),
          
          const SizedBox(height: 20),
          
          // Current day's workout
          _buildCurrentDayWorkout(weekSchedule[currentDayIndex]),
          
          const SizedBox(height: 16),
          
          // Navigation hint
          Center(
            child: Text(
              'Tap days to view different workouts',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDayCircle(BuildContext context, String day, bool isCurrentDay) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrentDay ? Colors.deepPurple : Colors.grey[200],
        boxShadow: isCurrentDay ? [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Center(
        child: Text(
          day,
          style: TextStyle(
            color: isCurrentDay ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
  
  Widget _buildCurrentDayWorkout(Map<String, dynamic> dayData) {
    final String muscleGroup = dayData['muscleGroup'];
    final bool isRestDay = dayData['isRestDay'] ?? false;
    final List<String> exercises = List<String>.from(dayData['exercises'] ?? []);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: isRestDay
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hotel,
                  color: Colors.blue,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  'Rest Day',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Focus on recovery today',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Muscle group title
                Text(
                  muscleGroup,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Exercise list - simple, without scrolling
                if (exercises.isEmpty)
                  const Text(
                    'No exercises scheduled',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  )
                else
                  for (var exercise in exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 16,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            exercise,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}