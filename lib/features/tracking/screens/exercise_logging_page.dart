// lib/features/tracking/screens/enhanced_exercise_logging_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';
import 'package:user_onboarding/features/tracking/screens/exercise_history_page.dart';


class EnhancedExerciseLoggingPage extends StatefulWidget {
  final UserProfile userProfile;

  const EnhancedExerciseLoggingPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<EnhancedExerciseLoggingPage> createState() => _EnhancedExerciseLoggingPageState();
}

class _EnhancedExerciseLoggingPageState extends State<EnhancedExerciseLoggingPage> {
  final ExerciseApi _apiService = ExerciseApi();
  final TextEditingController _customExerciseController = TextEditingController();
  
  // Current flow state
  int _currentStep = 0;
  String _selectedMuscleGroup = '';
  List<String> _selectedExercises = [];
  Map<String, ExerciseLog> _exerciseLogs = {};
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  int _targetDuration = 30;
  List<String> _preferredWorkouts = [];
  String _fitnessLevel = 'Beginner';

  
  // Exercise history and smart defaults
  List<Map<String, dynamic>> _exerciseHistory = [];
  Map<String, ExerciseDefaults> _exerciseDefaults = {};
  List<String> _customExercises = [];
  
  // Progressive overload tracking
  Map<String, List<Map<String, dynamic>>> _progressHistory = {};

  // Track logged exercises for selected date
  List<Map<String, dynamic>> _exercisesForSelectedDate = [];
  Map<String, List<Map<String, dynamic>>> _exercisesByMuscleGroup = {};

  // Track suggested exercises from last workout
  List<Map<String, dynamic>> _suggestedExercises = [];
  bool _showSuggestions = false;

  // Enhanced muscle groups with more exercises
  final Map<String, List<Exercise>> _muscleGroupExercises = {
    'Chest': [
      Exercise('Bench Press', 'strength', 0.8),
      Exercise('Push-ups', 'strength', 0.5),
      Exercise('Incline Bench Press', 'strength', 0.8),
      Exercise('Dumbbell Press', 'strength', 0.7),
      Exercise('Chest Flys', 'strength', 0.6),
      Exercise('Decline Press', 'strength', 0.7),
      Exercise('Dips', 'strength', 0.9),
      Exercise('Cable Crossover', 'strength', 0.5),
      Exercise('Pec Deck', 'strength', 0.5),
      Exercise('Diamond Push-ups', 'strength', 0.6),
    ],
    'Back': [
      Exercise('Pull-ups', 'strength', 1.2),
      Exercise('Deadlifts', 'strength', 1.0),
      Exercise('Lat Pulldowns', 'strength', 0.7),
      Exercise('Bent-over Rows', 'strength', 0.8),
      Exercise('Seated Cable Rows', 'strength', 0.6),
      Exercise('T-Bar Rows', 'strength', 0.8),
      Exercise('Shrugs', 'strength', 0.4),
      Exercise('Face Pulls', 'strength', 0.3),
      Exercise('Chin-ups', 'strength', 1.1),
      Exercise('Single-arm Dumbbell Rows', 'strength', 0.7),
    ],
    'Shoulders': [
      Exercise('Overhead Press', 'strength', 0.8),
      Exercise('Lateral Raises', 'strength', 0.4),
      Exercise('Front Raises', 'strength', 0.4),
      Exercise('Rear Delt Flys', 'strength', 0.3),
      Exercise('Arnold Press', 'strength', 0.7),
      Exercise('Upright Rows', 'strength', 0.5),
      Exercise('Pike Push-ups', 'strength', 0.6),
      Exercise('Handstand Push-ups', 'strength', 1.0),
      Exercise('Cable Lateral Raises', 'strength', 0.4),
      Exercise('Reverse Flys', 'strength', 0.3),
    ],
    'Arms': [
      Exercise('Bicep Curls', 'strength', 0.3),
      Exercise('Tricep Dips', 'strength', 0.6),
      Exercise('Hammer Curls', 'strength', 0.3),
      Exercise('Tricep Extensions', 'strength', 0.4),
      Exercise('Preacher Curls', 'strength', 0.4),
      Exercise('Close-grip Push-ups', 'strength', 0.5),
      Exercise('21s Curls', 'strength', 0.5),
      Exercise('Overhead Tricep Extension', 'strength', 0.4),
      Exercise('Cable Curls', 'strength', 0.3),
      Exercise('Tricep Pushdowns', 'strength', 0.4),
    ],
    'Legs': [
      Exercise('Squats', 'strength', 0.8),
      Exercise('Lunges', 'strength', 0.7),
      Exercise('Leg Press', 'strength', 0.9),
      Exercise('Calf Raises', 'strength', 0.3),
      Exercise('Leg Curls', 'strength', 0.5),
      Exercise('Leg Extensions', 'strength', 0.5),
      Exercise('Bulgarian Split Squats', 'strength', 0.8),
      Exercise('Step-ups', 'strength', 0.6),
      Exercise('Romanian Deadlifts', 'strength', 0.9),
      Exercise('Goblet Squats', 'strength', 0.7),
    ],
    'Core': [
      Exercise('Planks', 'strength', 0.4),
      Exercise('Crunches', 'strength', 0.3),
      Exercise('Russian Twists', 'strength', 0.4),
      Exercise('Mountain Climbers', 'strength', 0.6),
      Exercise('Bicycle Crunches', 'strength', 0.4),
      Exercise('Dead Bug', 'strength', 0.3),
      Exercise('Hanging Leg Raises', 'strength', 0.8),
      Exercise('Ab Wheel Rollouts', 'strength', 0.9),
      Exercise('Leg Raises', 'strength', 0.5),
      Exercise('Side Planks', 'strength', 0.4),
    ],
    'Cardio': [
      Exercise('Running', 'cardio', 12.0),
      Exercise('Cycling', 'cardio', 8.0),
      Exercise('Swimming', 'cardio', 11.0),
      Exercise('Walking', 'cardio', 4.0),
      Exercise('Elliptical', 'cardio', 9.0),
      Exercise('Rowing', 'cardio', 10.0),
      Exercise('Jumping Jacks', 'cardio', 8.0),
      Exercise('Burpees', 'cardio', 12.0),
      Exercise('Stair Climbing', 'cardio', 11.0),
      Exercise('HIIT Training', 'cardio', 14.0),
    ],
  };

  @override
  void initState() {
    super.initState();
    _targetDuration = widget.userProfile.workoutDuration ?? 30;
    _preferredWorkouts = widget.userProfile.preferredWorkouts ?? [];
    _fitnessLevel = widget.userProfile.fitnessLevel ?? 'Beginner';
    _loadExerciseData();
    _loadCustomExercises();
  }

  @override
  void dispose() {
    _customExerciseController.dispose();
    super.dispose();
  }

  Future<void> _loadExerciseData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load exercise history
      final history = await _apiService.getExerciseHistory(
        widget.userProfile.id!,
        limit: 100,
      );
      
      setState(() {
        _exerciseHistory = history;
      });
      
      // Build exercise defaults from history
      _buildExerciseDefaults();
      
      // Load progressive overload data
      await _loadProgressHistory();

      // NEW: Load exercises for selected date
      _loadExercisesForSelectedDate();
      
    } catch (e) {
      print('Error loading exercise data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load exercises for the selected date
  void _loadExercisesForSelectedDate() {
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    setState(() {
      _exercisesForSelectedDate = _exerciseHistory.where((exercise) {
        final exerciseDateStr = exercise['exercise_date'].toString().substring(0, 10);
        return exerciseDateStr == selectedDateStr;
      }).toList();

      // Group by muscle group
      _exercisesByMuscleGroup = {};
      for (final exercise in _exercisesForSelectedDate) {
        final muscleGroup = _capitalizeFirst(exercise['muscle_group'] ?? '');
        if (!_exercisesByMuscleGroup.containsKey(muscleGroup)) {
          _exercisesByMuscleGroup[muscleGroup] = [];
        }
        _exercisesByMuscleGroup[muscleGroup]!.add(exercise);
      }
    });
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Future<void> _loadCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final customExercisesJson = prefs.getStringList('custom_exercises_${widget.userProfile.id}') ?? [];
    setState(() {
      _customExercises = customExercisesJson;
    });
  }

  Future<void> _saveCustomExercises() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_exercises_${widget.userProfile.id}', _customExercises);
  }

  void _buildExerciseDefaults() {
    final defaults = <String, ExerciseDefaults>{};
    
    for (final exercise in _exerciseHistory) {
      final name = exercise['exercise_name'] as String;
      final exerciseType = exercise['exercise_type'] as String? ?? 'strength';

      // Calculate duration if not present
      int duration = exercise['duration_minutes'] ?? 0;
      if (duration == 0 && exerciseType == 'strength') {
        final sets = exercise['sets'] ?? 0;
        final reps = exercise['reps'] ?? 0;
        if (sets > 0 && reps > 0) {
          duration = calculateExerciseDuration(
            exerciseType: exerciseType,
            sets: sets,
            reps: reps,
            exerciseName: name,
          ).round();
        }
      }
      
      if (!defaults.containsKey(name)) {
        defaults[name] = ExerciseDefaults(
          sets: exercise['sets'] ?? 0,
          reps: exercise['reps'] ?? 0,
          weight: exercise['weight_kg']?.toDouble() ?? 0.0,
          duration: duration,
          distance: exercise['distance_km']?.toDouble() ?? 0.0,
          frequency: 1,
          lastPerformed: DateTime.parse(exercise['exercise_date']),
        );
      } else {
        // Update averages and frequency
        final current = defaults[name]!;
        defaults[name] = ExerciseDefaults(
          sets: ((current.sets + (exercise['sets'] ?? 0)) / 2).round(),
          reps: ((current.reps + (exercise['reps'] ?? 0)) / 2).round(),
          weight: (current.weight + (exercise['weight_kg']?.toDouble() ?? 0.0)) / 2,
          duration: ((current.duration + duration) / 2).round(),
          distance: (current.distance + (exercise['distance_km']?.toDouble() ?? 0.0)) / 2,
          frequency: current.frequency + 1,
          lastPerformed: DateTime.parse(exercise['exercise_date']),
        );
      }
    }
    
    setState(() {
      _exerciseDefaults = defaults;
    });
  }

  Future<void> _loadProgressHistory() async {
    final progressData = <String, List<Map<String, dynamic>>>{};
    
    // Group history by exercise name
    for (final exercise in _exerciseHistory) {
      final name = exercise['exercise_name'] as String;
      if (!progressData.containsKey(name)) {
        progressData[name] = [];
      }
      progressData[name]!.add(exercise);
    }
    
    // Sort each exercise history by date
    for (final entry in progressData.entries) {
      entry.value.sort((a, b) {
        return DateTime.parse(b['exercise_date']).compareTo(DateTime.parse(a['exercise_date']));
      });
    }
    
    setState(() {
      _progressHistory = progressData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        leading: _currentStep > 0 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBack,
            )
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedExerciseHistoryPage(
                    userProfile: widget.userProfile,
                  ),
                ),
              );
            },
          ),
          if (_currentStep == 1)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCustomExerciseDialog,
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              try {
                await _refreshData();
              } catch (e) {
                print('Error refreshing: $e');
              }
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildCurrentStep(),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Logging your workout...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return 'Select Muscle Group';
      case 1:
        return '$_selectedMuscleGroup Exercises';
      case 2:
        return 'Log Your Workout';
      default:
        return 'Exercise Logging';
    }
  }

  double calculateExerciseDuration({
    required String exerciseType,
    required int sets,
    required int reps,
    String? exerciseName,
  }) {
    if (exerciseType == 'cardio') {
      return 0;
    }
    
    const timePerRep = 3;
    var restBetweenSets = 60;
    
    final heavyExercises = ['squat', 'deadlift', 'bench press', 'leg press'];
    if (exerciseName != null && 
        heavyExercises.any((e) => exerciseName.toLowerCase().contains(e))) {
      restBetweenSets = 90;
    }
    
    final totalRepTime = sets * reps * timePerRep;
    final totalRestTime = sets > 1 ? (sets - 1) * restBetweenSets : 0;
    const setupTime = 30;
    
    final totalSeconds = totalRepTime + totalRestTime + setupTime;
    return (totalSeconds / 60).roundToDouble();
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildMuscleGroupSelection();
      case 1:
        return _buildExerciseSelection();
      case 2:
        return _buildExerciseLogging();
      default:
        return Container();
    }
  }

  Widget _buildMuscleGroupSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What did you work on today?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the muscle group you exercised • ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // Quick date picker with indicator
          Card(
            child: ListTile(
              leading: Icon(
                Icons.calendar_today, 
                color: _exercisesForSelectedDate.isNotEmpty ? Colors.green : Colors.orange
              ),
              title: Row(
                children: [
                  const Text('Workout Date'),
                  const SizedBox(width: 8),
                  // Badge showing if exercises are logged
                  if (_exercisesForSelectedDate.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${_exercisesForSelectedDate.length} logged',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context),
            ),
          ),
          
          // Show logged exercises for selected date
          if (_exercisesForSelectedDate.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLoggedExercisesSummary(),
          ],
          
          const SizedBox(height: 24),
          
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(), 
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: _muscleGroupExercises.keys.length,
            itemBuilder: (context, index) {
              final muscleGroup = _muscleGroupExercises.keys.elementAt(index);
              return _buildMuscleGroupCard(muscleGroup);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedExercisesSummary() {
    final totalCalories = _exercisesForSelectedDate.fold<double>(
      0.0, 
      (sum, ex) => sum + ((ex['calories_burned'] ?? 0) as num).toDouble()
    );

    return Card(
      color: Colors.green.shade50,
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(Icons.check_circle, color: Colors.green.shade700),
        title: Text(
          'Exercises Logged for ${DateFormat('MMM d').format(_selectedDate)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${_exercisesForSelectedDate.length} exercises • ${totalCalories.toInt()} calories',
          style: TextStyle(color: Colors.green.shade700, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _exercisesByMuscleGroup.entries.map((entry) {
                final muscleGroup = entry.key;
                final exercises = entry.value;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            _getMuscleGroupIcon(muscleGroup),
                            size: 20,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            muscleGroup,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...exercises.map((ex) => Padding(
                      padding: const EdgeInsets.only(left: 28, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, size: 8),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ex['exercise_name']}${_getExerciseDetails(ex)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (entry.key != _exercisesByMuscleGroup.keys.last)
                      const Divider(height: 16),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Helper to format exercise details
  String _getExerciseDetails(Map<String, dynamic> exercise) {
    final type = exercise['exercise_type'];
    if (type == 'cardio') {
      final duration = exercise['duration_minutes'] ?? 0;
      final distance = exercise['distance_km'] ?? 0.0;
      if (distance > 0) {
        return ' • ${duration}min, ${distance.toStringAsFixed(1)}km';
      }
      return ' • ${duration}min';
    } else {
      final sets = exercise['sets'] ?? 0;
      final reps = exercise['reps'] ?? 0;
      final weight = exercise['weight_kg'] ?? 0.0;
      if (weight > 0) {
        return ' • ${sets}×${reps} @ ${weight.toStringAsFixed(1)}kg';
      }
      return ' • ${sets}×${reps}';
    }
  }

  Widget _buildMuscleGroupCard(String muscleGroup) {
    final isSelected = _selectedMuscleGroup == muscleGroup;
    final recentWorkouts = _getRecentWorkoutsForMuscleGroup(muscleGroup);
    final hasExercisesToday = _exercisesByMuscleGroup.containsKey(muscleGroup);
    
    // NEW: Check if has last workout suggestion available
    final hasLastWorkout = _hasLastWorkoutForMuscleGroup(muscleGroup);
    
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Colors.orange.shade50 : null,
      child: InkWell(
        onTap: () => _selectMuscleGroup(muscleGroup),
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Main content - centered
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getMuscleGroupIcon(muscleGroup),
                      size: 40,
                      color: isSelected ? Colors.orange : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      muscleGroup,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.orange : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_muscleGroupExercises[muscleGroup]!.length} exercises',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // Show quick log indicator
                    if (hasLastWorkout && !hasExercisesToday) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on, 
                              size: 10, 
                              color: Colors.blue.shade700
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Quick log',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (recentWorkouts > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$recentWorkouts this week',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Checkmark badge if exercises logged for selected date
            if (hasExercisesToday)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSelection() {
    final exercises = _muscleGroupExercises[_selectedMuscleGroup]!;
    final customExercisesForGroup = _customExercises
        .where((name) => _getCustomExerciseMuscleGroup(name) == _selectedMuscleGroup)
        .toList();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select $_selectedMuscleGroup Exercises',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the exercises you performed • Tap + to add custom exercises',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
                // Standard exercises
                ...exercises.map((exercise) => _buildExerciseCard(exercise, false)),
                
                // Custom exercises
                if (customExercisesForGroup.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Your Custom Exercises',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...customExercisesForGroup.map((exerciseName) => 
                    _buildCustomExerciseCard(exerciseName)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, bool isCustom) {
    final isSelected = _selectedExercises.contains(exercise.name);
    final defaults = _exerciseDefaults[exercise.name];
    final lastPerformed = defaults?.lastPerformed;
    final frequency = defaults?.frequency ?? 0;
    
    // NEW: Check if this exercise is already logged for the selected date
    final isLoggedToday = _exercisesForSelectedDate.any(
      (ex) => ex['exercise_name'] == exercise.name
    );
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      // NEW: Add visual indicator if already logged
      color: isLoggedToday ? Colors.green.shade50 : null,
      child: CheckboxListTile(
        title: Row(
          children: [
            Expanded(child: Text(exercise.name)),
            // NEW: Show checkmark if already logged
            if (isLoggedToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Logged',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.type == 'cardio' 
                ? 'Cardio • ${exercise.calorieRate.toInt()} cal/min'
                : 'Strength • ${exercise.calorieRate} cal/rep',
            ),
            // NEW: Show logged data for today if exists
            if (isLoggedToday) ...[
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final loggedExercise = _exercisesForSelectedDate.firstWhere(
                    (ex) => ex['exercise_name'] == exercise.name
                  );
                  return Row(
                    children: [
                      Icon(Icons.today, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Today: ${_getExerciseDetails(loggedExercise)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            if (defaults != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.history, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    lastPerformed != null
                      ? 'Last: ${_getTimeAgo(lastPerformed)} • ${frequency}x total'
                      : 'New exercise',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (exercise.type == 'strength' && defaults.weight > 0 && !isLoggedToday)
                Row(
                  children: [
                    Icon(Icons.fitness_center, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Last: ${defaults.sets} sets × ${defaults.reps} reps @ ${defaults.weight.toStringAsFixed(1)}kg',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
            ],
          ],
        ),
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedExercises.add(exercise.name);
            } else {
              _selectedExercises.remove(exercise.name);
            }
          });
        },
        activeColor: Colors.orange,
        secondary: isLoggedToday
          ? Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)
          : (frequency > 5 
              ? Icon(Icons.star, color: Colors.orange.shade700, size: 20)
              : null),
      ),
    );
  }

  Widget _buildCustomExerciseCard(String exerciseName) {
    final isSelected = _selectedExercises.contains(exerciseName);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      child: CheckboxListTile(
        title: Text(exerciseName),
        subtitle: const Text('Custom Exercise'),
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedExercises.add(exerciseName);
            } else {
              _selectedExercises.remove(exerciseName);
            }
          });
        },
        activeColor: Colors.orange,
        secondary: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteCustomExercise(exerciseName),
        ),
      ),
    );
  }

  Widget _buildExerciseLogging() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Log Your Workout',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('MMM d').format(_selectedDate)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Workout summary
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.fitness_center, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedMuscleGroup Workout',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_selectedExercises.length} exercises • ${_calculateTotalCalories().toInt()} calories estimated',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedExercises.length,
            itemBuilder: (context, index) {
              final exerciseName = _selectedExercises[index];
              final exercise = _getExerciseByName(exerciseName);
              return _buildExerciseLogCard(exercise);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseLogCard(Exercise exercise) {
    final log = _exerciseLogs[exercise.name] ?? ExerciseLog();
    final defaults = _exerciseDefaults[exercise.name];
    final progressData = _progressHistory[exercise.name];

    // Calculate estimated duration
    double estimatedDuration = 0;
    if (exercise.type == 'strength' && log.sets > 0 && log.reps > 0) {
      estimatedDuration = calculateExerciseDuration(
        exerciseType: exercise.type,
        sets: log.sets,
        reps: log.reps,
        exerciseName: exercise.name,
      );
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          exercise.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Estimated: ${_calculateCalories(exercise, log).toInt()} calories',
          style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progressive overload indicator
                if (progressData != null && progressData.isNotEmpty)
                  _buildProgressIndicator(exercise, progressData),
                
                const SizedBox(height: 16),
                
                // Input fields
                if (exercise.type == 'cardio') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Duration (min)',
                            border: const OutlineInputBorder(),
                            hintText: defaults?.duration.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateExerciseLog(exercise.name, duration: int.tryParse(value) ?? 0);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Distance (km)',
                            border: const OutlineInputBorder(),
                            hintText: defaults?.distance.toStringAsFixed(1),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateExerciseLog(exercise.name, distance: double.tryParse(value) ?? 0.0);
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Sets',
                            border: const OutlineInputBorder(),
                            hintText: defaults?.sets.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateExerciseLog(exercise.name, sets: int.tryParse(value) ?? 0);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Reps',
                            border: const OutlineInputBorder(),
                            hintText: defaults?.reps.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateExerciseLog(exercise.name, reps: int.tryParse(value) ?? 0);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Weight (kg)',
                            border: const OutlineInputBorder(),
                            hintText: defaults?.weight.toStringAsFixed(1),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _updateExerciseLog(exercise.name, weight: double.tryParse(value) ?? 0.0);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Smart defaults button
                if (defaults != null)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _applyDefaults(exercise.name, defaults),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Use Last Workout'),
                      ),
                      const Spacer(),
                      if (exercise.type == 'strength' && log.weight > 0)
                        Text(
                          'Volume: ${(log.sets * log.reps * log.weight).toStringAsFixed(1)}kg',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Exercise exercise, List<Map<String, dynamic>> progressData) {
    if (progressData.length < 2) return Container();
    
    final latest = progressData.first;
    final previous = progressData[1];
    
    if (exercise.type == 'strength') {
      final latestVolume = (latest['sets'] ?? 0) * (latest['reps'] ?? 0) * (latest['weight_kg'] ?? 0.0);
      final previousVolume = (previous['sets'] ?? 0) * (previous['reps'] ?? 0) * (previous['weight_kg'] ?? 0.0);
      
      if (latestVolume > previousVolume) {
        final improvement = ((latestVolume - previousVolume) / previousVolume * 100);
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Progressive overload! +${improvement.toStringAsFixed(1)}% volume vs last workout',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    
    return Container();
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _getNextButtonAction(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            _getNextButtonText(),
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // Helper methods
  IconData _getMuscleGroupIcon(String muscleGroup) {
    switch (muscleGroup) {
      case 'Chest':
        return Icons.fitness_center;
      case 'Back':
        return Icons.accessibility_new;
      case 'Shoulders':
        return Icons.open_with;
      case 'Arms':
        return Icons.sports_gymnastics;
      case 'Legs':
        return Icons.directions_run;
      case 'Core':
        return Icons.center_focus_strong;
      case 'Cardio':
        return Icons.favorite;
      default:
        return Icons.fitness_center;
    }
  }
      
  int _getRecentWorkoutsForMuscleGroup(String muscleGroup) {
   final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
   return _exerciseHistory.where((exercise) {
     final exerciseDate = DateTime.parse(exercise['exercise_date']);
     final exerciseName = exercise['exercise_name'] as String;
     
     // Check if this exercise belongs to the muscle group
     final belongsToGroup = _muscleGroupExercises[muscleGroup]
         ?.any((e) => e.name == exerciseName) ?? false;
     
     return exerciseDate.isAfter(oneWeekAgo) && belongsToGroup;
   }).length;
 }

 String _getCustomExerciseMuscleGroup(String exerciseName) {
   // Simple heuristic - you could make this more sophisticated
   // For now, we'll assume custom exercises belong to the currently selected muscle group
   return _selectedMuscleGroup.isNotEmpty ? _selectedMuscleGroup : 'Other';
 }

 String _getTimeAgo(DateTime date) {
   final now = DateTime.now();
   final difference = now.difference(date);
   
   if (difference.inDays > 0) {
     return '${difference.inDays}d ago';
   } else if (difference.inHours > 0) {
     return '${difference.inHours}h ago';
   } else {
     return 'Today';
   }
 }

 void _selectMuscleGroup(String muscleGroup) {
    setState(() {
      _selectedMuscleGroup = muscleGroup;
    });
    
    // Load suggestions for this muscle group
    _loadSuggestionsForMuscleGroup(muscleGroup);
  }

 VoidCallback? _getNextButtonAction() {
   switch (_currentStep) {
     case 0:
       return _selectedMuscleGroup.isNotEmpty ? _goToExerciseSelection : null;
     case 1:
       return _selectedExercises.isNotEmpty ? _goToLogging : null;
     case 2:
       return _canSubmit() ? _submitWorkout : null;
     default:
       return null;
   }
 }

 // Load last workout for selected muscle group
 void _loadSuggestionsForMuscleGroup(String muscleGroup) {
    // Get exercises from last workout for this muscle group
    final muscleGroupExercises = _exerciseHistory.where((ex) {
      final exMuscleGroup = _capitalizeFirst(ex['muscle_group'] ?? '');
      return exMuscleGroup == muscleGroup;
    }).toList();

    if (muscleGroupExercises.isEmpty) {
      setState(() {
        _suggestedExercises = [];
        _showSuggestions = false;
      });
      return;
    }

    // Sort by date to get most recent workout
    muscleGroupExercises.sort((a, b) {
      return DateTime.parse(b['exercise_date'])
          .compareTo(DateTime.parse(a['exercise_date']));
    });

    // Get the date of last workout
    final lastWorkoutDate = DateTime.parse(muscleGroupExercises.first['exercise_date']);
    
    // Check if it's from a different day (not today)
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final lastWorkoutDateStr = DateFormat('yyyy-MM-dd').format(lastWorkoutDate);
    
    if (selectedDateStr == lastWorkoutDateStr) {
      // Same day, don't show suggestions
      setState(() {
        _suggestedExercises = [];
        _showSuggestions = false;
      });
      return;
    }

    // Group exercises by date and get the last workout session
    final Map<String, List<Map<String, dynamic>>> exercisesByDate = {};
    for (final ex in muscleGroupExercises) {
      final date = ex['exercise_date'].toString().substring(0, 10);
      if (!exercisesByDate.containsKey(date)) {
        exercisesByDate[date] = [];
      }
      exercisesByDate[date]!.add(ex);
    }

    // Get the most recent workout session
    final dates = exercisesByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    if (dates.isNotEmpty) {
      final lastWorkoutExercises = exercisesByDate[dates.first]!;
      
      setState(() {
        _suggestedExercises = lastWorkoutExercises;
        _showSuggestions = true;
      });

      // Show suggestion dialog
      _showQuickLogDialog();
    }
  }

  // Show dialog to quick log last workout
  Future<void> _showQuickLogDialog() async {
    if (_suggestedExercises.isEmpty) return;

    final lastWorkoutDate = DateTime.parse(_suggestedExercises.first['exercise_date']);
    final daysAgo = _selectedDate.difference(lastWorkoutDate).inDays;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flash_on, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Quick Log',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Found your last $_selectedMuscleGroup workout from ${daysAgo == 1 ? "yesterday" : "$daysAgo days ago"}.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Exercises performed:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: _suggestedExercises.map((ex) {
                      final exerciseName = ex['exercise_name'];
                      final details = _getExerciseDetails(ex);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, 
                              size: 16, 
                              color: Colors.green.shade600
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$exerciseName$details',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, 
                        size: 18, 
                        color: Colors.orange.shade700
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This will log all these exercises directly to your workout history',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Continue with manual selection
                _goToExerciseSelection();
              },
              child: const Text('Choose Manually'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Trigger direct logging to database
                _quickLogLastWorkout();
              },
              icon: const Icon(Icons.flash_on, size: 18),
              label: const Text('Quick Log Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Quick log the suggested exercises directly to database
  Future<void> _quickLogLastWorkout() async {
    setState(() => _isLoading = true);
    
    try {
      final exercises = <Map<String, dynamic>>[];
      
      for (final ex in _suggestedExercises) {
        final exerciseName = ex['exercise_name'] as String;
        final exerciseType = ex['exercise_type'] as String? ?? 'strength';
        
        // Calculate calories based on the exercise type
        final exercise = _getExerciseByName(exerciseName);
        double calories = 0;
        
        if (exerciseType == 'cardio') {
          final duration = ex['duration_minutes'] ?? 0;
          calories = exercise.calorieRate * duration.toDouble();
        } else {
          final sets = ex['sets'] ?? 0;
          final reps = ex['reps'] ?? 0;
          calories = exercise.calorieRate * (sets.toDouble() * reps.toDouble());
        }
        
        // Get duration
        double duration = 0;
        if (exerciseType == 'strength') {
          final sets = ex['sets'] ?? 0;
          final reps = ex['reps'] ?? 0;
          duration = calculateExerciseDuration(
            exerciseType: exerciseType,
            sets: sets,
            reps: reps,
            exerciseName: exerciseName,
          );
        } else {
          duration = (ex['duration_minutes'] ?? 0).toDouble();
        }
        
        // Base exercise data
        final exerciseData = <String, dynamic>{
          'user_id': widget.userProfile.id,
          'exercise_name': exerciseName,
          'exercise_type': exerciseType,
          'muscle_group': _selectedMuscleGroup.toLowerCase(),
          'calories_burned': calories,
          'exercise_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'duration_minutes': duration.round(),
          'notes': 'Quick logged from previous workout',
        };
        
        // Add type-specific data
        if (exerciseType == 'cardio') {
          if (ex['duration_minutes'] != null && ex['duration_minutes'] > 0) {
            exerciseData['duration_minutes'] = ex['duration_minutes'];
          }
          if (ex['distance_km'] != null && ex['distance_km'] > 0) {
            exerciseData['distance_km'] = ex['distance_km'];
          }
        } else {
          // Strength exercise
          if (ex['sets'] != null && ex['sets'] > 0) {
            exerciseData['sets'] = ex['sets'];
          }
          if (ex['reps'] != null && ex['reps'] > 0) {
            exerciseData['reps'] = ex['reps'];
          }
          if (ex['weight_kg'] != null && ex['weight_kg'] > 0) {
            exerciseData['weight_kg'] = ex['weight_kg'];
          }
        }
        
        exercises.add(exerciseData);
      }
      
      print('Quick logging exercises: $exercises'); // Debug print
      
      // Submit all exercises to database
      for (final exerciseData in exercises) {
        await _apiService.logExercise(exerciseData);
      }
      
      if (mounted) {
        // Reload data to update indicators
        await _loadExerciseData();
        
        // Show success summary
        _showQuickLogSuccessSummary(exercises);
      }
    } catch (e) {
      print('Error quick logging workout: $e'); // Debug print
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging workout: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
        return 'Continue';
      case 1:
        return 'Log Exercises (${_selectedExercises.length})';
      case 2:
        return 'Complete Workout';
      default:
        return 'Continue';
    }
  }

 void _goToExerciseSelection() {
   setState(() {
     _currentStep = 1;
   });
 }

 void _goToLogging() {
   setState(() {
     _currentStep = 2;
     // Initialize exercise logs for selected exercises with smart defaults
     for (final exerciseName in _selectedExercises) {
       final defaults = _exerciseDefaults[exerciseName];
       _exerciseLogs[exerciseName] = ExerciseLog(
         sets: defaults?.sets ?? 0,
         reps: defaults?.reps ?? 0,
         weight: defaults?.weight ?? 0.0,
         duration: defaults?.duration ?? 0,
         distance: defaults?.distance ?? 0.0,
       );
     }
   });
 }

 void _goBack() {
   setState(() {
     if (_currentStep > 0) {
       _currentStep--;
     }
   });
 }

  // Check if muscle group has a previous workout
  bool _hasLastWorkoutForMuscleGroup(String muscleGroup) {
    final muscleGroupExercises = _exerciseHistory.where((ex) {
      final exMuscleGroup = _capitalizeFirst(ex['muscle_group'] ?? '');
      return exMuscleGroup == muscleGroup;
    }).toList();

    if (muscleGroupExercises.isEmpty) return false;

    // Check if not logged today
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final hasExercisesToday = muscleGroupExercises.any((ex) {
      final exerciseDateStr = ex['exercise_date'].toString().substring(0, 10);
      return exerciseDateStr == selectedDateStr;
    });

    return !hasExercisesToday && muscleGroupExercises.isNotEmpty;
  }

 bool _canSubmit() {
   for (final exerciseName in _selectedExercises) {
     final exercise = _getExerciseByName(exerciseName);
     final log = _exerciseLogs[exerciseName];
     
     if (log == null) return false;
     
     if (exercise.type == 'cardio') {
       if (log.duration <= 0) return false;
     } else {
       if (log.sets <= 0 || log.reps <= 0) return false;
     }
   }
   return true;
 }

 Exercise _getExerciseByName(String name) {
   // Check standard exercises
   for (final exercises in _muscleGroupExercises.values) {
     for (final exercise in exercises) {
       if (exercise.name == name) return exercise;
     }
   }
   
   // Check custom exercises - default to strength type
   if (_customExercises.contains(name)) {
     return Exercise(name, 'strength', 0.5); // Default calorie rate for custom exercises
   }
   
   throw Exception('Exercise not found: $name');
 }

 void _updateExerciseLog(String exerciseName, {
   int? sets,
   int? reps,
   double? weight,
   int? duration,
   double? distance,
 }) {
   setState(() {
     final currentLog = _exerciseLogs[exerciseName] ?? ExerciseLog();
     _exerciseLogs[exerciseName] = ExerciseLog(
       sets: sets ?? currentLog.sets,
       reps: reps ?? currentLog.reps,
       weight: weight ?? currentLog.weight,
       duration: duration ?? currentLog.duration,
       distance: distance ?? currentLog.distance,
     );
   });
 }

 void _applyDefaults(String exerciseName, ExerciseDefaults defaults) {
   setState(() {
     _exerciseLogs[exerciseName] = ExerciseLog(
       sets: defaults.sets,
       reps: defaults.reps,
       weight: defaults.weight,
       duration: defaults.duration,
       distance: defaults.distance,
     );
   });
   
   // Show feedback
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Text('Applied defaults from your last $exerciseName workout'),
       backgroundColor: Colors.orange,
       duration: const Duration(seconds: 2),
     ),
   );
 }

double _calculateCalories(Exercise exercise, ExerciseLog log) {
  if (exercise.type == 'cardio') {
    return exercise.calorieRate * log.duration.toDouble();
  } else {
    return exercise.calorieRate * (log.sets.toDouble() * log.reps.toDouble());
  }
}

double _calculateTotalCalories() {
  double total = 0;
  for (final exerciseName in _selectedExercises) {
    final exercise = _getExerciseByName(exerciseName);
    final log = _exerciseLogs[exerciseName] ?? ExerciseLog();
    total += _calculateCalories(exercise, log);
  }
  return total;
}

 Future<void> _selectDate(BuildContext context) async {
   final picked = await showDatePicker(
     context: context,
     initialDate: _selectedDate,
     firstDate: DateTime.now().subtract(const Duration(days: 365)),
     lastDate: DateTime.now(),
   );
   if (picked != null && picked != _selectedDate) {
     setState(() {
       _selectedDate = picked;
       // NEW: Reload exercises for the new date
       _loadExercisesForSelectedDate();
     });
   }
 }

 Future<void> _showAddCustomExerciseDialog() async {
   return showDialog<void>(
     context: context,
     builder: (BuildContext context) {
       return AlertDialog(
         title: const Text('Add Custom Exercise'),
         content: TextField(
           controller: _customExerciseController,
           decoration: const InputDecoration(
             labelText: 'Exercise Name',
             hintText: 'e.g., Cable Flies, Kettlebell Swings',
             border: OutlineInputBorder(),
           ),
           autofocus: true,
           textCapitalization: TextCapitalization.words,
         ),
         actions: [
           TextButton(
             onPressed: () {
               _customExerciseController.clear();
               Navigator.of(context).pop();
             },
             child: const Text('Cancel'),
           ),
           ElevatedButton(
             onPressed: () {
               final exerciseName = _customExerciseController.text.trim();
               if (exerciseName.isNotEmpty) {
                 _addCustomExercise(exerciseName);
                 _customExerciseController.clear();
                 Navigator.of(context).pop();
               }
             },
             style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
             child: const Text('Add Exercise', style: TextStyle(color: Colors.white)),
           ),
         ],
       );
     },
   );
 }

 void _addCustomExercise(String exerciseName) {
   if (!_customExercises.contains(exerciseName)) {
     setState(() {
       _customExercises.add(exerciseName);
     });
     _saveCustomExercises();
     
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Added "$exerciseName" to your exercises'),
         backgroundColor: Colors.green,
       ),
     );
   }
 }

 void _deleteCustomExercise(String exerciseName) {
   showDialog(
     context: context,
     builder: (BuildContext context) {
       return AlertDialog(
         title: const Text('Delete Custom Exercise'),
         content: Text('Are you sure you want to delete "$exerciseName"?'),
         actions: [
           TextButton(
             onPressed: () => Navigator.of(context).pop(),
             child: const Text('Cancel'),
           ),
           TextButton(
             onPressed: () {
               setState(() {
                 _customExercises.remove(exerciseName);
                 _selectedExercises.remove(exerciseName);
               });
               _saveCustomExercises();
               Navigator.of(context).pop();
               
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(
                   content: Text('Deleted "$exerciseName"'),
                   backgroundColor: Colors.red,
                 ),
               );
             },
             child: const Text('Delete', style: TextStyle(color: Colors.red)),
           ),
         ],
       );
     },
   );
 }

  Future<void> _submitWorkout() async {
    setState(() => _isLoading = true);
    
    try {
      final exercises = <Map<String, dynamic>>[];
      
      for (final exerciseName in _selectedExercises) {
        final exercise = _getExerciseByName(exerciseName);
        final log = _exerciseLogs[exerciseName]!;
        final calories = _calculateCalories(exercise, log);
        
        // Calculate duration for strength exercises
        double duration = 0;
        if (exercise.type == 'strength') {
          duration = calculateExerciseDuration(
            exerciseType: exercise.type,
            sets: log.sets,
            reps: log.reps,
            exerciseName: exerciseName,
          );
        } else if (exercise.type == 'cardio') {
          duration = log.duration.toDouble();
        }
        
        // Base exercise data
        final exerciseData = <String, dynamic>{
          'user_id': widget.userProfile.id,
          'exercise_name': exerciseName,
          'exercise_type': exercise.type,
          'muscle_group': _selectedMuscleGroup.toLowerCase(),
          'calories_burned': calories,
          'exercise_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'duration_minutes': duration.round(), // Add calculated duration
          'notes': '',
        };
        
        // Add type-specific data only if values exist
        if (exercise.type == 'cardio') {
          if (log.duration > 0) {
            exerciseData['duration_minutes'] = log.duration;
          }
          if (log.distance > 0) {
            exerciseData['distance_km'] = log.distance;
          }
        } else {
          // Strength exercise
          if (log.sets > 0) {
            exerciseData['sets'] = log.sets;
          }
          if (log.reps > 0) {
            exerciseData['reps'] = log.reps;
          }
          if (log.weight > 0) {
            exerciseData['weight_kg'] = log.weight;
          }
        }
        
        exercises.add(exerciseData);
      }
      
      print('Submitting exercises: $exercises'); // Debug print
      
      // Submit all exercises
      for (final exerciseData in exercises) {
        await _apiService.logExercise(exerciseData);
      }
      
      if (mounted) {
        // NEW: Reload data to update indicators
        await _loadExerciseData();
        _showWorkoutSummary(exercises);
      }
    } catch (e) {
      print('Error submitting workout: $e'); // Debug print
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showWorkoutSummary(List<Map<String, dynamic>> exercises) {
    final totalCalories = exercises.fold<double>(
      0.0, (sum, ex) => sum + ((ex['calories_burned'] ?? 0) as num).toDouble());
    
    final totalVolume = exercises
        .where((ex) => ex['exercise_type'] == 'strength')
        .fold<double>(0.0, (sum, ex) {
          final sets = ((ex['sets'] ?? 0) as num).toDouble();
          final reps = ((ex['reps'] ?? 0) as num).toDouble();
          final weight = ((ex['weight_kg'] ?? 0.0) as num).toDouble();
          return sum + (sets * reps * weight);
        });
    
    final totalCardioMinutes = exercises
        .where((ex) => ex['exercise_type'] == 'cardio')
        .fold<int>(0, (sum, ex) => sum + ((ex['duration_minutes'] ?? 0) as num).toInt());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Workout Complete! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Great job on your $_selectedMuscleGroup workout!'),
              const SizedBox(height: 16),
              _buildSummaryItem(Icons.fitness_center, '${exercises.length} exercises completed'),
              _buildSummaryItem(Icons.local_fire_department, '${totalCalories.toInt()} calories burned'),
              if (totalVolume > 0)
                _buildSummaryItem(Icons.monitor_weight, '${totalVolume.toStringAsFixed(1)}kg total volume'),
              if (totalCardioMinutes > 0)
                _buildSummaryItem(Icons.timer, '$totalCardioMinutes minutes cardio'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to previous screen
              },
              child: const Text('View History'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to previous screen
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    
    try {
      await _loadExerciseData();
      await _loadCustomExercises();

    } catch (e) {
      print('Error in _refreshData: $e');
    }
  }

  // Show success summary after quick log
  void _showQuickLogSuccessSummary(List<Map<String, dynamic>> exercises) {
    final totalCalories = exercises.fold<double>(
      0.0, (sum, ex) => sum + ((ex['calories_burned'] ?? 0) as num).toDouble());
    
    final totalVolume = exercises
        .where((ex) => ex['exercise_type'] == 'strength')
        .fold<double>(0.0, (sum, ex) {
          final sets = ((ex['sets'] ?? 0) as num).toDouble();
          final reps = ((ex['reps'] ?? 0) as num).toDouble();
          final weight = ((ex['weight_kg'] ?? 0.0) as num).toDouble();
          return sum + (sets * reps * weight);
        });
    
    final totalCardioMinutes = exercises
        .where((ex) => ex['exercise_type'] == 'cardio')
        .fold<int>(0, (sum, ex) => sum + ((ex['duration_minutes'] ?? 0) as num).toInt());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.flash_on, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Quick Log Complete! 🎉',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully logged your $_selectedMuscleGroup workout for ${DateFormat('MMM d').format(_selectedDate)}!',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    _buildSummaryItem(Icons.fitness_center, '${exercises.length} exercises logged'),
                    _buildSummaryItem(Icons.local_fire_department, '${totalCalories.toInt()} calories burned'),
                    if (totalVolume > 0)
                      _buildSummaryItem(Icons.monitor_weight, '${totalVolume.toStringAsFixed(1)}kg total volume'),
                    if (totalCardioMinutes > 0)
                      _buildSummaryItem(Icons.timer, '$totalCardioMinutes minutes cardio'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'All exercises logged with values from your last workout',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to previous screen
              },
              child: const Text('View History'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to previous screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

}


// Supporting classes
class Exercise {
 final String name;
 final String type;
 final double calorieRate; 

 Exercise(this.name, this.type, this.calorieRate);
}

class ExerciseLog {
 final int sets;
 final int reps;
 final double weight;
 final int duration;
 final double distance;

 ExerciseLog({
   this.sets = 0,
   this.reps = 0,
   this.weight = 0.0,
   this.duration = 0,
   this.distance = 0.0,
 });
}

class ExerciseDefaults {
 final int sets;
 final int reps;
 final double weight;
 final int duration;
 final double distance;
 final int frequency;
 final DateTime lastPerformed;

 ExerciseDefaults({
   required this.sets,
   required this.reps,
   required this.weight,
   required this.duration,
   required this.distance,
   required this.frequency,
   required this.lastPerformed,
 });
}