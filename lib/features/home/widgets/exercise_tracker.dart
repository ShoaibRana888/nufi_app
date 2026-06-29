import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/features/home/screens/exercise_history_screen.dart';
import 'package:user_onboarding/data/services/data_manager.dart';


class ExerciseTracker extends StatefulWidget {
  final UserProfile userProfile;
  
  const ExerciseTracker({
    Key? key,
    required this.userProfile,
  }) : super(key: key);
  
  @override
  State<ExerciseTracker> createState() => _ExerciseTrackerState();
}

class _ExerciseTrackerState extends State<ExerciseTracker> {
  final List<Map<String, dynamic>> _exercises = [];
  bool _isAddingExercise = false;
  int _caloriesBurned = 0;
  String _selectedDateFilter = 'Today';
  final List<String> _dateFilters = ['Today', 'This Week', 'This Month', 'All Time'];
  
  // Exercise categories with their respective icons and calorie multipliers
  final Map<String, Map<String, dynamic>> _exerciseCategories = {
    'Running': {'icon': Icons.directions_run, 'calorieMultiplier': 10},
    'Walking': {'icon': Icons.directions_walk, 'calorieMultiplier': 5},
    'Cycling': {'icon': Icons.directions_bike, 'calorieMultiplier': 8},
    'Swimming': {'icon': Icons.pool, 'calorieMultiplier': 12},
    'Weight Training': {'icon': Icons.fitness_center, 'calorieMultiplier': 7},
    'Yoga': {'icon': Icons.self_improvement, 'calorieMultiplier': 4},
    'HIIT': {'icon': Icons.timer, 'calorieMultiplier': 15},
    'Sports': {'icon': Icons.sports_basketball, 'calorieMultiplier': 9},
    'Dancing': {'icon': Icons.music_note, 'calorieMultiplier': 7},
    'Other': {'icon': Icons.more_horiz, 'calorieMultiplier': 6},
  };
  
  @override
  void initState() {
    super.initState();
    _loadExercises();
  }
  
  void _loadExercises() async {
    try {
      // In a real app, load from database
      final dataManager = DataManager();
      final exercises = await dataManager.loadExercises('${widget.userProfile.email}');
      
      if (exercises.isNotEmpty) {
        setState(() {
          _exercises.clear();
          _exercises.addAll(exercises);
          _updateCaloriesBurned();
        });
      } else {
        // Load sample data if no saved data exists
        _loadSampleExercises();
      }
    } catch (e) {
      print('Error loading exercises: $e');
      // Fallback to sample data on error
      _loadSampleExercises();
    }
  }
  
  void _loadSampleExercises() {
    // Clear any existing exercises
    _exercises.clear();
    
    // Add some sample exercises for testing
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final dayBefore = today.subtract(const Duration(days: 2));
    
    // Sample exercises with dates
    _exercises.add({
      'name': 'Morning Run',
      'category': 'Running',
      'duration': 30,
      'caloriesBurned': 300,
      'time': '7:30 AM',
      'date': today,
      'notes': 'Felt good, increased pace'
    });
    
    _exercises.add({
      'name': 'Weight Training',
      'category': 'Weight Training',
      'duration': 45,
      'caloriesBurned': 280,
      'time': '6:00 PM',
      'date': yesterday,
      'notes': 'Upper body focus'
    });
    
    _exercises.add({
      'name': 'Yoga Session',
      'category': 'Yoga',
      'duration': 60,
      'caloriesBurned': 200,
      'time': '8:00 AM',
      'date': dayBefore,
      'notes': 'Relaxing session'
    });
    
    // Calculate total calories burned based on filter
    _updateCaloriesBurned();
  }


  void _updateCaloriesBurned() {
    List<Map<String, dynamic>> filteredExercises = _getFilteredExercises();
    _caloriesBurned = filteredExercises.fold(0, (sum, exercise) => sum + (exercise['caloriesBurned'] as int));
  }
  
  List<Map<String, dynamic>> _getFilteredExercises() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _exercises.where((exercise) {
      final exerciseDate = exercise['date'] as DateTime;
      final exerciseDateOnly = DateTime(exerciseDate.year, exerciseDate.month, exerciseDate.day);
      
      switch (_selectedDateFilter) {
        case 'Today':
          return exerciseDateOnly.isAtSameMomentAs(today);
        case 'This Week':
          final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
          return exerciseDateOnly.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
                 exerciseDateOnly.isBefore(startOfWeek.add(const Duration(days: 7)));
        case 'This Month':
          return exerciseDateOnly.month == today.month && exerciseDateOnly.year == today.year;
        case 'All Time':
          return true;
        default:
          return true;
      }
    }).toList();
  }
  
  void _navigateToExerciseHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseHistoryScreen(
          userProfile: widget.userProfile,
          exercises: _exercises,
        ),
      ),
    ).then((_) {
      // When returning from the exercise history screen, update the UI
      setState(() {
        _updateCaloriesBurned();
      });
    });
  }
  
  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final durationController = TextEditingController();
    final caloriesController = TextEditingController();
    final timeController = TextEditingController(text: _getCurrentTime());
    final notesController = TextEditingController();
    String selectedCategory = _exerciseCategories.keys.first;
    
    setState(() {
      _isAddingExercise = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Function to calculate estimated calories
          void calculateEstimatedCalories() {
            if (durationController.text.isNotEmpty) {
              try {
                final duration = int.parse(durationController.text);
                final multiplier = _exerciseCategories[selectedCategory]!['calorieMultiplier'] as int;
                final userWeight = widget.userProfile.weight;
                
                // Simplified calorie calculation formula
                // Calories = duration (minutes) * multiplier * weight (kg) / 10
                final estimatedCalories = (duration * multiplier * userWeight / 10).round();
                
                setDialogState(() {
                  caloriesController.text = estimatedCalories.toString();
                });
              } catch (e) {
                // Handle parsing error
              }
            }
          }
          
          return AlertDialog(
            title: const Text('Add Exercise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Name',
                      hintText: 'e.g., Morning Run, Weight Training',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Category',
                    ),
                    items: _exerciseCategories.keys.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Row(
                          children: [
                            Icon(_exerciseCategories[category]!['icon'] as IconData),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value!;
                        calculateEstimatedCalories();
                      });
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                      hintText: 'e.g., 30',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => calculateEstimatedCalories(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: caloriesController,
                    decoration: const InputDecoration(
                      labelText: 'Calories Burned',
                      hintText: 'e.g., 250',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      hintText: 'e.g., 7:30 AM',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'e.g., Felt energetic, increased pace',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _isAddingExercise = false;
                  });
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate inputs
                  if (nameController.text.isEmpty || 
                      durationController.text.isEmpty || 
                      caloriesController.text.isEmpty ||
                      int.tryParse(durationController.text) == null ||
                      int.tryParse(caloriesController.text) == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all required fields correctly'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  final newExercise = {
                    'name': nameController.text,
                    'category': selectedCategory,
                    'duration': int.parse(durationController.text),
                    'caloriesBurned': int.parse(caloriesController.text),
                    'time': timeController.text,
                    'date': DateTime.now(),
                    'notes': notesController.text,
                  };
                  
                  setState(() {
                    _exercises.add(newExercise);
                    _updateCaloriesBurned();
                    _isAddingExercise = false;
                  });
                  
                  // In a real app, save this to the database
                  _saveExerciseData();
                  
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        }
      ),
    );
  }
  
  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  Future<void> _saveExerciseData() async {
    final dataManager = DataManager();
    await dataManager.saveExercises('userId', _exercises);
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredExercises = _getFilteredExercises();
    
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
          // Header with date filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exercise',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: _selectedDateFilter,
                underline: Container(),
                icon: const Icon(Icons.filter_list),
                items: _dateFilters.map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(filter),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDateFilter = value!;
                    _updateCaloriesBurned();
                  });
                },
              ),
            ],
          ),
          
          // Calories summary
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_caloriesBurned',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'calories burned ($_selectedDateFilter)',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Exercise list
          filteredExercises.isEmpty 
              ? Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Icon(
                        Icons.fitness_center,
                        size: 48,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No exercises recorded for $_selectedDateFilter',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const Text(
                      'Activity Log',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...filteredExercises.map((exercise) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(
                                  _exerciseCategories[exercise['category']]?['icon'] as IconData? ?? Icons.fitness_center,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        exercise['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${exercise['caloriesBurned']} cal',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${exercise['duration']} minutes | ${exercise['category']}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${exercise['time']} · ${_formatDate(exercise['date'] as DateTime)}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (exercise['notes'] != null && exercise['notes'].toString().isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        exercise['notes'],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                // Remove exercise
                                setState(() {
                                  _exercises.remove(exercise);
                                  _updateCaloriesBurned();
                                });
                                // Save changes
                                _saveExerciseData();
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
          
          // Add exercise button
          Center(
            child: _isAddingExercise
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
                    onPressed: _showAddExerciseDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Exercise'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ),
          
          if (filteredExercises.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: _navigateToExerciseHistory,
                child: const Text('View Exercise History'),
              ),
            ),
        ],
      ),
    );
  }
}