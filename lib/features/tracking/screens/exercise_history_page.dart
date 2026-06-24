// lib/features/tracking/screens/exercise_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';

class EnhancedExerciseHistoryPage extends StatefulWidget {
  final UserProfile userProfile;

  const EnhancedExerciseHistoryPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<EnhancedExerciseHistoryPage> createState() => _EnhancedExerciseHistoryPageState();
}

class _EnhancedExerciseHistoryPageState extends State<EnhancedExerciseHistoryPage> 
    with SingleTickerProviderStateMixin {
  final ExerciseApi _apiService = ExerciseApi();
  final SharingApi _sharingApi = SharingApi();

  List<Map<String, dynamic>> _exercises = [];
  Map<String, dynamic> _weeklyStats = {};
  bool _isLoading = false;
  
  // Filters
  String? _selectedMuscleGroup;
  String? _selectedExerciseType;
  DateTimeRange? _selectedDateRange;
  
  // Tab controller
  late TabController _tabController;

  final List<String> _muscleGroups = [
    'All', 'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Cardio'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load exercises with current filters
      final exercises = await _apiService.getExerciseLogs(
        widget.userProfile.id!,
        exerciseType: _selectedExerciseType,
        startDate: _selectedDateRange?.start.toIso8601String(),
        endDate: _selectedDateRange?.end.toIso8601String(),
        limit: 200,
      );
      
      // Load weekly stats
      final stats = await _apiService.getWeeklyExerciseSummary(widget.userProfile.id!);
      
      setState(() {
        _exercises = exercises;
        _weeklyStats = stats;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredExercises {
    var filtered = _exercises;
    
    if (_selectedMuscleGroup != null && _selectedMuscleGroup != 'All') {
      filtered = filtered.where((ex) => 
        (ex['muscle_group'] ?? '').toString().toLowerCase() == 
        _selectedMuscleGroup!.toLowerCase()).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise History'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.trending_up), text: 'Progress'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filters
          _buildFiltersSection(),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryTab(),
                _buildAnalyticsTab(),
                _buildProgressTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Muscle group filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _muscleGroups.map((group) {
                final isSelected = _selectedMuscleGroup == group || 
                    (group == 'All' && _selectedMuscleGroup == null);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(group),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedMuscleGroup = selected ? group : null;
                        if (group == 'All') _selectedMuscleGroup = null;
                      });
                    },
                    selectedColor: Colors.orange.shade100,
                    checkmarkColor: Colors.orange,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Date and type filters
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _selectedDateRange == null
                        ? 'All Time'
                        : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedExerciseType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Types')),
                    const DropdownMenuItem(value: 'strength', child: Text('Strength')),
                    const DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedExerciseType = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final filteredExercises = _filteredExercises;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (filteredExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No exercises found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or log some exercises!',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    
    // Group exercises by date
    final groupedByDate = <String, List<Map<String, dynamic>>>{};
    for (final exercise in filteredExercises) {
      final dateKey = exercise['exercise_date'].toString().split('T')[0];
      groupedByDate.putIfAbsent(dateKey, () => []).add(exercise);
    }
    
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayExercises = groupedByDate[date]!;
        final parsedDate = DateTime.parse(date);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              DateFormat('EEEE, MMM d, yyyy').format(parsedDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${dayExercises.length} exercises • ${_calculateDayCalories(dayExercises).toInt()} calories',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            children: dayExercises.map((exercise) => _buildExerciseListTile(exercise)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildExerciseListTile(Map<String, dynamic> exercise) {
    final isStrength = exercise['exercise_type'] == 'strength';
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isStrength ? Colors.orange.shade100 : Colors.blue.shade100,
        child: Icon(
          isStrength ? Icons.fitness_center : Icons.favorite,
          color: isStrength ? Colors.orange : Colors.blue,
          size: 20,
        ),
      ),
      title: Text(exercise['exercise_name'] ?? 'Unknown'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isStrength) ...[
            Text('${exercise['sets']} sets × ${exercise['reps']} reps'),
            if (exercise['weight_kg'] != null && exercise['weight_kg'] > 0)
              Text('${exercise['weight_kg']}kg'),
          ] else ...[
            Text('${exercise['duration_minutes']} minutes'),
            if (exercise['distance_km'] != null && exercise['distance_km'] > 0)
              Text('${exercise['distance_km']}km'),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${((exercise['calories_burned'] ?? 0) as num).toInt()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'calories',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
      onLongPress: () => _showExerciseOptions(exercise),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final filteredExercises = _filteredExercises;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards - Use Row and Column instead of GridView
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Workouts',
                  filteredExercises.length.toString(),
                  Icons.fitness_center,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Calories',
                  _calculateTotalCalories(filteredExercises).toInt().toString(),
                  Icons.local_fire_department,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg per Week',
                  _calculateAvgWorkoutsPerWeek(filteredExercises).toStringAsFixed(1),
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Most Popular',
                  _getMostFrequentExercise(filteredExercises),
                  Icons.star,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Muscle group breakdown
          const Text(
            'Muscle Group Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildMuscleGroupChart(filteredExercises),
          
          const SizedBox(height: 24),
          
          // Weekly activity chart
          const Text(
            'Weekly Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildWeeklyChart(filteredExercises),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final strengthExercises = _filteredExercises
        .where((ex) => ex['exercise_type'] == 'strength')
        .toList();
    
    // Group by exercise name
    final exerciseProgress = <String, List<Map<String, dynamic>>>{};
    for (final exercise in strengthExercises) {
      final name = exercise['exercise_name'] as String;
      exerciseProgress.putIfAbsent(name, () => []).add(exercise);
    }
    
    // Sort each exercise's history by date
    for (final entry in exerciseProgress.entries) {
      entry.value.sort((a, b) => DateTime.parse(a['exercise_date'])
          .compareTo(DateTime.parse(b['exercise_date'])));
    }
    
    if (exerciseProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No strength training data',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Log some strength exercises to see progress!',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exerciseProgress.keys.length,
      itemBuilder: (context, index) {
        final exerciseName = exerciseProgress.keys.elementAt(index);
        final history = exerciseProgress[exerciseName]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(exerciseName),
            subtitle: Text('${history.length} sessions'),
            children: [
              _buildProgressChart(exerciseName, history),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupChart(List<Map<String, dynamic>> exercises) {
    final muscleGroupCount = <String, int>{};
    
    for (final exercise in exercises) {
      final group = (exercise['muscle_group'] ?? 'other').toString();
      muscleGroupCount[group] = (muscleGroupCount[group] ?? 0) + 1;
    }
    
    if (muscleGroupCount.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data')));
    }
    
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: muscleGroupCount.entries.map((entry) {
            final percentage = entry.value / exercises.length * 100;
            return PieChartSectionData(
              value: entry.value.toDouble(),
              title: '${percentage.toStringAsFixed(1)}%',
              color: _getMuscleGroupColor(entry.key),
              radius: 60,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(List<Map<String, dynamic>> exercises) {
    // Group exercises by week
    final weeklyData = <String, int>{};
    
    for (final exercise in exercises) {
      final date = DateTime.parse(exercise['exercise_date']);
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final weekKey = DateFormat('MMM d').format(weekStart);
      weeklyData[weekKey] = (weeklyData[weekKey] ?? 0) + 1;
    }
    
    if (weeklyData.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No data')));
    }
    
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: weeklyData.entries.toList().asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
              }).toList(),
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressChart(String exerciseName, List<Map<String, dynamic>> history) {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < history.length; i++) {
      final exercise = history[i];
      final sets = ((exercise['sets'] ?? 0) as num).toDouble();
      final reps = ((exercise['reps'] ?? 0) as num).toDouble();
      final weight = ((exercise['weight_kg'] ?? 0.0) as num).toDouble();
      final volume = sets * reps * weight;
      spots.add(FlSpot(i.toDouble(), volume));
    }
    
    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getMuscleGroupColor(String muscleGroup) {
    final colors = {
      'chest': Colors.red,
      'back': Colors.blue,
      'shoulders': Colors.green,
      'arms': Colors.purple,
      'legs': Colors.orange,
      'core': Colors.teal,
      'cardio': Colors.pink,
    };
    return colors[muscleGroup.toLowerCase()] ?? Colors.grey;
  }

  double _calculateTotalCalories(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty) return 0.0;
    
    try {
      return exercises.fold(0.0, (sum, ex) {
        final calories = ex['calories_burned'];
        if (calories == null) return sum;
        if (calories is int) return sum + calories.toDouble();
        if (calories is double) return sum + calories;
        if (calories is String) return sum + (double.tryParse(calories) ?? 0.0);
        return sum;
      });
    } catch (e) {
      print('Error calculating total calories: $e');
      return 0.0;
    }
  }

  double _calculateDayCalories(List<Map<String, dynamic>> exercises) {
    return exercises.fold(0.0, (sum, ex) => 
      sum + ((ex['calories_burned'] ?? 0) as num).toDouble());
  }

  double _calculateAvgWorkoutsPerWeek(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty) return 0.0;
    
    try {
      final dates = exercises
          .map((e) => DateTime.tryParse(e['exercise_date']?.toString() ?? ''))
          .whereType<DateTime>()
          .toList();
      
      if (dates.isEmpty) return 0.0;
      
      dates.sort();
      final daysDiff = dates.last.difference(dates.first).inDays;
      final weeks = ((daysDiff / 7).ceil()).clamp(1, 1000);
      
      return exercises.length / weeks;
    } catch (e) {
      print('Error calculating avg workouts per week: $e');
      return 0.0;
    }
  }

  String _getMostFrequentExercise(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty) return 'N/A';
    
    try {
      final frequency = <String, int>{};
      for (final ex in exercises) {
        final name = ex['exercise_name']?.toString() ?? 'Unknown';
        frequency[name] = (frequency[name] ?? 0) + 1;
      }
      
      if (frequency.isEmpty) return 'N/A';
      
      final mostFrequent = frequency.entries.reduce(
        (a, b) => a.value > b.value ? a : b
      );
      return mostFrequent.key;
    } catch (e) {
      print('Error calculating most frequent exercise: $e');
      return 'N/A';
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadData();
    }
  }

  void _showExerciseOptions(Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Exercise'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement edit functionality
              },
            ),
            Builder(
              builder: (context) {
                final isShared = exercise['shared_with_chat'] != false;
                return ListTile(
                  leading: Icon(
                    isShared ? Icons.visibility_off : Icons.visibility,
                    color: Colors.purple,
                  ),
                  title: Text(isShared ? 'Hide from coach' : 'Share with coach'),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleExerciseSharing(exercise);
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Exercise'),
              onTap: () {
                Navigator.pop(context);
                _deleteExercise(exercise);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleExerciseSharing(Map<String, dynamic> exercise) async {
    final wasShared = exercise['shared_with_chat'] != false;
    final newShared = !wasShared;
    setState(() => exercise['shared_with_chat'] = newShared);

    final ok = await _sharingApi.setEntrySharing(
      userId: widget.userProfile.id!,
      activityType: 'exercise',
      itemId: exercise['id'].toString(),
      shared: newShared,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() => exercise['shared_with_chat'] = wasShared);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update sharing. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newShared ? 'Exercise shared with coach' : 'Exercise hidden from coach'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _deleteExercise(Map<String, dynamic> exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Exercise'),
        content: Text('Are you sure you want to delete "${exercise['exercise_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteExerciseLog(exercise['id'], widget.userProfile.id!);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete exercise: $e')),
        );
      }
    }
  }
}