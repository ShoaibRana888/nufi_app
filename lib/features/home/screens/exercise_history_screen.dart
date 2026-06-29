// lib/features/home/screens/exercise_history_screen.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ExerciseHistoryScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<Map<String, dynamic>> exercises;

  const ExerciseHistoryScreen({
    Key? key,
    required this.userProfile,
    required this.exercises,
  }) : super(key: key);

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDateFilter = 'Last Month';
  String _selectedCategoryFilter = 'All Categories';
  String _sortBy = 'Date (Recent First)';
  
  final List<String> _dateFilters = ['Last 7 Days', 'Last Month', 'Last 3 Months', 'All Time'];
  List<String> _categoryFilters = ['All Categories'];
  
  final List<String> _sortOptions = [
    'Date (Recent First)', 
    'Date (Oldest First)', 
    'Duration (Highest First)', 
    'Calories (Highest First)',
    'Name (A-Z)'
  ];
  
  // Color list for charts
  final List<Color> _chartColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.indigo,
    Colors.pink,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize category filters based on unique exercise categories
    final categories = widget.exercises
        .map((e) => e['category'] as String)
        .toSet()
        .toList();
    _categoryFilters = ['All Categories', ...categories];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getFilteredExercises() {
    final now = DateTime.now();
    
    // First, filter by date
    List<Map<String, dynamic>> dateFiltered = widget.exercises.where((exercise) {
      final exerciseDate = exercise['date'] as DateTime;
      
      switch (_selectedDateFilter) {
        case 'Last 7 Days':
          return exerciseDate.isAfter(now.subtract(const Duration(days: 7)));
        case 'Last Month':
          return exerciseDate.isAfter(now.subtract(const Duration(days: 30)));
        case 'Last 3 Months':
          return exerciseDate.isAfter(now.subtract(const Duration(days: 90)));
        case 'All Time':
          return true;
        default:
          return true;
      }
    }).toList();
    
    // Then, filter by category
    if (_selectedCategoryFilter != 'All Categories') {
      dateFiltered = dateFiltered.where((e) => e['category'] == _selectedCategoryFilter).toList();
    }
    
    // Finally, sort the results
    switch (_sortBy) {
      case 'Date (Recent First)':
        dateFiltered.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        break;
      case 'Date (Oldest First)':
        dateFiltered.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
        break;
      case 'Duration (Highest First)':
        dateFiltered.sort((a, b) => (b['duration'] as int).compareTo(a['duration'] as int));
        break;
      case 'Calories (Highest First)':
        dateFiltered.sort((a, b) => (b['caloriesBurned'] as int).compareTo(a['caloriesBurned'] as int));
        break;
      case 'Name (A-Z)':
        dateFiltered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        break;
    }
    
    return dateFiltered;
  }

  // Calculate summary statistics
  Map<String, dynamic> calculateSummary(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty) {
      return {
        'totalExercises': 0,
        'totalDuration': 0,
        'totalCalories': 0,
        'avgCaloriesPerWorkout': 0,
        'mostFrequentCategory': 'N/A',
      };
    }
    
    final totalExercises = exercises.length;
    final totalDuration = exercises.fold<int>(0, (sum, e) => sum + (e['duration'] as int));
    final totalCalories = exercises.fold<int>(0, (sum, e) => sum + (e['caloriesBurned'] as int));
    final avgCaloriesPerWorkout = totalCalories / totalExercises;
    
    // Find most frequent category
    final categoryCount = <String, int>{};
    for (final exercise in exercises) {
      final category = exercise['category'] as String;
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
    }
    
    String mostFrequentCategory = 'N/A';
    int maxCount = 0;
    categoryCount.forEach((category, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequentCategory = category;
      }
    });
    
    return {
      'totalExercises': totalExercises,
      'totalDuration': totalDuration,
      'totalCalories': totalCalories,
      'avgCaloriesPerWorkout': avgCaloriesPerWorkout,
      'mostFrequentCategory': mostFrequentCategory,
      'categoryData': categoryCount,
    };
  }

  // Data preparation for fl_chart - Bar Chart
  List<BarChartGroupData> _prepareCategoryChartData(Map<String, int> categoryCounts) {
    int index = 0;
    final List<BarChartGroupData> barGroups = [];
    
    categoryCounts.forEach((category, count) {
      final colorIndex = index % _chartColors.length;
      
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: _chartColors[colorIndex],
              width: 22,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
      
      index++;
    });
    
    return barGroups;
  }

  // Data preparation for fl_chart - Line Chart
  List<FlSpot> _prepareTrendChartData(List<Map<String, dynamic>> exercises) {
    // Sort exercises by date
    final sorted = List<Map<String, dynamic>>.from(exercises)
      ..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    // Group by day and sum calories
    final dailyData = <DateTime, int>{};
    
    for (final exercise in sorted) {
      final date = (exercise['date'] as DateTime);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final calories = exercise['caloriesBurned'] as int;
      dailyData[dateOnly] = (dailyData[dateOnly] ?? 0) + calories;
    }
    
    // Convert to FlSpot format for LineChart
    final List<FlSpot> spots = [];
    if (dailyData.isNotEmpty) {
      // Find the earliest date to use as x = 0
      final firstDate = dailyData.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      
      dailyData.forEach((date, calories) {
        // X value is days since first date
        final x = date.difference(firstDate).inDays.toDouble();
        spots.add(FlSpot(x, calories.toDouble()));
      });
      
      // Sort spots by x value
      spots.sort((a, b) => a.x.compareTo(b.x));
    }
    
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = getFilteredExercises();
    final summary = calculateSummary(filteredExercises);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise History'),
        backgroundColor: Colors.green,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activities'),
            Tab(text: 'Statistics'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Time Period',
                          isDense: true,
                        ),
                        value: _selectedDateFilter,
                        items: _dateFilters.map((filter) {
                          return DropdownMenuItem<String>(
                            value: filter,
                            child: Text(filter, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDateFilter = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          isDense: true,
                        ),
                        value: _selectedCategoryFilter,
                        items: _categoryFilters.map((filter) {
                          return DropdownMenuItem<String>(
                            value: filter,
                            child: Text(filter, style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryFilter = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    isDense: true,
                  ),
                  value: _sortBy,
                  items: _sortOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Activities Tab
                _buildActivitiesTab(filteredExercises),
                
                // Statistics Tab
                _buildStatisticsTab(filteredExercises, summary),
                
                // Trends Tab
                _buildTrendsTab(filteredExercises),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No exercises found for the selected filters',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Exercise'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        final date = exercise['date'] as DateTime;
        
        return Dismissible(
          key: Key('exercise-${exercise.hashCode}'),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            setState(() {
              widget.exercises.remove(exercise);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${exercise['name']} deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    setState(() {
                      widget.exercises.add(exercise);
                    });
                  },
                ),
              ),
            );
          },
          child: Card(
            elevation: 2,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withOpacity(0.2),
                child: Icon(
                  Icons.directions_run,
                  color: Colors.green,
                ),
              ),
              title: Text(
                exercise['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${exercise['category']} • ${exercise['duration']} min • ${DateFormat.yMMMd().format(date)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              trailing: Text(
                '${exercise['caloriesBurned']} cal',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(Icons.access_time, 'Time', exercise['time']),
                    _buildInfoItem(Icons.calendar_today, 'Date', DateFormat.yMMMEd().format(date)),
                    _buildInfoItem(Icons.local_fire_department, 'Calories', '${exercise['caloriesBurned']} cal'),
                  ],
                ),
                const SizedBox(height: 16),
                if (exercise['notes'] != null && exercise['notes'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exercise['notes'],
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      onPressed: () {
                        // Show edit dialog
                        _showEditExerciseDialog(exercise);
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          widget.exercises.remove(exercise);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab(List<Map<String, dynamic>> exercises, Map<String, dynamic> summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Summary: $_selectedDateFilter',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Total Workouts',
                        '${summary['totalExercises']}',
                        Icons.fitness_center,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Total Minutes',
                        '${summary['totalDuration']}',
                        Icons.timer,
                        Colors.orange,
                      ),
                      _buildStatCard(
                        'Calories Burned',
                        '${summary['totalCalories']}',
                        Icons.local_fire_department,
                        Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Category Breakdown
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (exercises.isEmpty) 
                    const Center(
                      child: Text('No exercise data to display'),
                    )
                  else
                    SizedBox(
                      height: 250,
                      child: _buildCategoryChart(summary),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Most frequent activity: ${summary['mostFrequentCategory']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Additional Stats
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildStatRow(
                    'Average Calories per Workout',
                    '${summary['avgCaloriesPerWorkout'].toStringAsFixed(1)} cal',
                  ),
                  _buildStatRow(
                    'Average Workout Duration',
                    summary['totalExercises'] > 0
                        ? '${(summary['totalDuration'] / summary['totalExercises']).toStringAsFixed(1)} min'
                        : '0 min',
                  ),
                  _buildStatRow(
                    'Average Workouts per Week',
                    summary['totalExercises'] > 0
                        ? _calculateAvgWorkoutsPerWeek(exercises).toStringAsFixed(1)
                        : '0',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(Map<String, dynamic> summary) {
    final categoryData = summary['categoryData'] as Map<String, int>? ?? {};
    
    if (categoryData.isEmpty) {
      return const Center(child: Text('No category data available'));
    }
    
    // Create a list of categories for bottom titles
    final categories = categoryData.keys.toList();
    final barGroups = _prepareCategoryChartData(categoryData);
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: categoryData.values.reduce((a, b) => a > b ? a : b) * 1.2, // Some extra space at top
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= categories.length) {
                  return const Text('');
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    categories[value.toInt()],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const Text('');
                }
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildTrendsTab(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty || exercises.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              exercises.isEmpty 
                  ? 'No exercise data to display'
                  : 'Need more data to show trends',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories Burned Over Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildTrendLineChart(exercises),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildWeeklyComparisonChart(exercises),
                  const SizedBox(height: 16),
                  const Text(
                    'Compared to previous period:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildWeeklyComparison(exercises),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLineChart(List<Map<String, dynamic>> exercises) {
    final spots = _prepareTrendChartData(exercises);
    
    if (spots.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }
    
    return LineChart(
      LineChartData(
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 3 != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Day ${value.toInt()}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(
              show: true,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyComparisonChart(List<Map<String, dynamic>> exercises) {
    // This would be a chart showing week by week comparison
    // Simplified placeholder for now
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Week-by-week comparison chart would go here',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildWeeklyComparison(List<Map<String, dynamic>> exercises) {
    // This would show comparison statistics
    // Simplified placeholder for now
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildComparisonItem('+12%', 'Workouts', Colors.green),
        _buildComparisonItem('+20%', 'Duration', Colors.green),
        _buildComparisonItem('-5%', 'Calories/Workout', Colors.red),
      ],
    );
  }

  Widget _buildComparisonItem(String percentage, String label, Color color) {
    return Column(
      children: [
        Text(
          percentage,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAvgWorkoutsPerWeek(List<Map<String, dynamic>> exercises) {
    if (exercises.isEmpty) return 0;
    
    // Find earliest and latest dates
    DateTime? earliest;
    DateTime? latest;
    
    for (final exercise in exercises) {
      final date = exercise['date'] as DateTime;
      
      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
      
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    
    if (earliest == null || latest == null) return 0;
    
    // Calculate number of weeks
    final difference = latest.difference(earliest).inDays;
    final weeks = difference / 7.0;
    
    // If less than a week, return number of exercises
    if (weeks < 1) return exercises.length.toDouble();
    
    return exercises.length / weeks;
  }

  void _showEditExerciseDialog(Map<String, dynamic> exercise) {
    final nameController = TextEditingController(text: exercise['name']);
    final durationController = TextEditingController(text: exercise['duration'].toString());
    final caloriesController = TextEditingController(text: exercise['caloriesBurned'].toString());
    final timeController = TextEditingController(text: exercise['time']);
    final notesController = TextEditingController(text: exercise['notes'] ?? '');
    String selectedCategory = exercise['category'];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Edit Exercise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Exercise Category',
                    ),
                    items: _categoryFilters.where((c) => c != 'All Categories').map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: caloriesController,
                    decoration: const InputDecoration(
                      labelText: 'Calories Burned',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
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
                  
                  // Update exercise
                  setState(() {
                    exercise['name'] = nameController.text;
                    exercise['category'] = selectedCategory;
                    exercise['duration'] = int.parse(durationController.text);
                    exercise['caloriesBurned'] = int.parse(caloriesController.text);
                    exercise['time'] = timeController.text;
                    exercise['notes'] = notesController.text;
                  });
                  
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}