// lib/features/onboarding/screens/workout_preferences_page.dart
import 'package:flutter/material.dart';

class WorkoutPreferencesPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;

  const WorkoutPreferencesPage({
    Key? key,
    required this.formData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<WorkoutPreferencesPage> createState() => _WorkoutPreferencesPageState();
}

class _WorkoutPreferencesPageState extends State<WorkoutPreferencesPage> {
  List<String> _selectedWorkouts = [];
  int _workoutFrequency = 3;
  int _workoutDuration = 30;
  bool _showValidationErrors = false;

  final List<Map<String, dynamic>> _workoutTypes = [
    {'name': 'Walking/Running', 'icon': Icons.directions_run, 'color': Colors.orange},
    {'name': 'Cycling', 'icon': Icons.directions_bike, 'color': Colors.blue},
    {'name': 'Swimming', 'icon': Icons.pool, 'color': Colors.cyan},
    {'name': 'Strength Training', 'icon': Icons.fitness_center, 'color': Colors.red},
    {'name': 'Yoga/Pilates', 'icon': Icons.self_improvement, 'color': Colors.purple},
    {'name': 'Dancing', 'icon': Icons.music_note, 'color': Colors.deepPurple},
    {'name': 'Sports', 'icon': Icons.sports_basketball, 'color': Colors.indigo},
    {'name': 'HIIT', 'icon': Icons.timer, 'color': Colors.deepOrange},
    {'name': 'CrossFit', 'icon': Icons.sports, 'color': Colors.teal},
    {'name': 'Other', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  final List<int> _frequencyOptions = [1, 2, 3, 4, 5, 6, 7];
  final List<int> _durationOptions = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    if (widget.formData['preferredWorkouts'] != null) {
      _selectedWorkouts = List<String>.from(widget.formData['preferredWorkouts']);
    }
    _workoutFrequency = widget.formData['workoutFrequency'] ?? 3;
    _workoutDuration = widget.formData['workoutDuration'] ?? 30;
  }

  bool _isFieldValid(String fieldName) {
    if (!_showValidationErrors) return true;
    
    switch (fieldName) {
      case 'workouts':
        return _selectedWorkouts.isNotEmpty;
      case 'frequency':
        return _workoutFrequency > 0 && _workoutFrequency <= 7;
      case 'duration':
        return _workoutDuration >= 15 && _workoutDuration <= 120;
      default:
        return true;
    }
  }

  String _getFrequencyMessage() {
    if (_workoutFrequency <= 2) {
      return 'Good start! Consistency is key.';
    } else if (_workoutFrequency <= 4) {
      return 'Great balance! This is optimal for most people.';
    } else if (_workoutFrequency <= 6) {
      return 'Very active! Make sure to include rest days.';
    } else {
      return 'Highly active! Consider recovery time.';
    }
  }

  Color _getFrequencyColor() {
    if (_workoutFrequency <= 2) return Colors.orange;
    if (_workoutFrequency <= 4) return Colors.green;
    if (_workoutFrequency <= 6) return Colors.blue;
    return Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout Preferences',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us about your exercise routine to personalize your fitness plan.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // Workout Types Selection
          Row(
            children: const [
              Text(
                'What types of exercise do you enjoy?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all that apply',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          
          if (!_isFieldValid('workouts') && _showValidationErrors)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Please select at least one workout type',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.0,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _workoutTypes.length,
            itemBuilder: (context, index) {
              final workout = _workoutTypes[index];
              final isSelected = _selectedWorkouts.contains(workout['name']);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedWorkouts.remove(workout['name']);
                    } else {
                      _selectedWorkouts.add(workout['name'] as String);
                    }
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('preferredWorkouts', _selectedWorkouts);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (workout['color'] as Color).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? workout['color'] as Color
                          : (!_isFieldValid('workouts') && _showValidationErrors
                              ? Colors.red[300]!
                              : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        workout['icon'] as IconData,
                        size: 32,
                        color: isSelected 
                            ? workout['color'] as Color
                            : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        workout['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? workout['color'] as Color
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Selected workouts summary
          if (_selectedWorkouts.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedWorkouts.length} workout type${_selectedWorkouts.length > 1 ? 's' : ''} selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Workout Frequency
          Row(
            children: const [
              Text(
                'How often do you want to workout?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getFrequencyColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !_isFieldValid('frequency') && _showValidationErrors
                    ? Colors.red
                    : _getFrequencyColor().withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 24,
                      color: _getFrequencyColor(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_workoutFrequency',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _getFrequencyColor(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'days/week',
                      style: TextStyle(
                        fontSize: 18,
                        color: _getFrequencyColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _frequencyOptions.map((freq) {
                    final isSelected = _workoutFrequency == freq;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _workoutFrequency = freq;
                          _showValidationErrors = false;
                        });
                        widget.onDataChanged('workoutFrequency', freq);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? _getFrequencyColor()
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$freq',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _getFrequencyColor(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getFrequencyMessage(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getFrequencyColor(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Workout Duration
          Row(
            children: const [
              Text(
                'How long are your typical workouts?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (!_isFieldValid('duration') && _showValidationErrors)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Please select workout duration',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _durationOptions.map((duration) {
              final isSelected = _workoutDuration == duration;
              final hours = duration >= 60 ? duration ~/ 60 : 0;
              final minutes = duration % 60;
              String displayText = '';
              
              if (hours > 0 && minutes > 0) {
                displayText = '${hours}h ${minutes}m';
              } else if (hours > 0) {
                displayText = '${hours} hour${hours > 1 ? 's' : ''}';
              } else {
                displayText = '$minutes min';
              }
              
              Color durationColor = Colors.blue;
              if (duration <= 30) durationColor = Colors.orange;
              else if (duration <= 60) durationColor = Colors.green;
              else durationColor = Colors.purple;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _workoutDuration = duration;
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('workoutDuration', duration);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? durationColor.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected 
                          ? durationColor
                          : (!_isFieldValid('duration') && _showValidationErrors
                              ? Colors.red[300]!
                              : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: isSelected ? durationColor : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        displayText,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? durationColor : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  void validateFields() {
    setState(() {
      _showValidationErrors = true;
    });
  }
}