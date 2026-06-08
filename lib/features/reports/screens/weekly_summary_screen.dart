// lib/features/reports/screens/weekly_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/reports/screens/trends_screen.dart';

class WeeklySummaryScreen extends StatefulWidget {
  final UserProfile userProfile;
  
  const WeeklySummaryScreen({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  final ChatApi _apiService = ChatApi();
  Map<String, dynamic>? _currentWeekData;
  List<Map<String, dynamic>> _recentWeeks = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }
  
  Future<void> _loadWeeklyData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load current week
      final currentWeek = await _apiService.getWeeklyContext(
        widget.userProfile.id!,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      );
      
      // Load recent weeks for trends
      final recentWeeks = await _apiService.getRecentWeeks(
        widget.userProfile.id!,
        weeks: 4,
      );
      
      setState(() {
        _currentWeekData = currentWeek;
        _recentWeeks = recentWeeks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading weekly data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrendsScreen(
                    userId: widget.userProfile.id!,
                  ),
                ),
              );
            },
            tooltip: 'View Trends',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectWeek,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentWeekData == null
              ? const Center(child: Text('No data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWeekHeader(),
                      const SizedBox(height: 20),
                      _buildQuickStats(),
                      const SizedBox(height: 20),
                      _buildNutritionCard(),
                      const SizedBox(height: 16),
                      _buildExerciseCard(),
                      const SizedBox(height: 16),
                      _buildHydrationSleepCard(),
                      const SizedBox(height: 16),
                      _buildWeightProgressCard(),
                      const SizedBox(height: 16),
                      _buildInsightsCard(),
                      const SizedBox(height: 16),
                      _buildTrendsChart(),
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildWeekHeader() {
    final weekData = _currentWeekData!['weekly_context'];
    final weekInfo = weekData['week_info'];
    
    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week ${weekInfo['week_number']} of ${weekInfo['year']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatDate(weekInfo['start_date'])} - ${_formatDate(weekInfo['end_date'])}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: weekInfo['days_logged'] / 7,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                weekInfo['days_logged'] >= 5 
                    ? Colors.green 
                    : weekInfo['days_logged'] >= 3 
                        ? Colors.orange 
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${weekInfo['days_logged']}/7 days logged',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickStats() {
    final weekData = _currentWeekData!['weekly_context'];
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_fire_department,
            title: 'Avg Calories',
            value: '${weekData['nutrition_summary']['avg_daily_calories']}',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.fitness_center,
            title: 'Workouts',
            value: '${weekData['exercise_summary']['total_workouts']}',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            icon: Icons.bedtime,
            title: 'Avg Sleep',
            value: '${weekData['sleep_summary']['avg_nightly_hours']}h',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNutritionCard() {
    final nutrition = _currentWeekData!['weekly_context']['nutrition_summary'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Nutrition',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNutrientRow('Calories', nutrition['avg_daily_calories'], 'kcal'),
            _buildNutrientRow('Protein', nutrition['avg_daily_protein'], 'g'),
            _buildNutrientRow('Carbs', nutrition['avg_daily_carbs'], 'g'),
            _buildNutrientRow('Fat', nutrition['avg_daily_fat'], 'g'),
            const SizedBox(height: 12),
            Text(
              '${nutrition['total_meals_logged']} meals logged this week',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _buildDailyBreakdownChart(nutrition['daily_breakdown']),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNutrientRow(String label, dynamic value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$value $unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExerciseCard() {
    final exercise = _currentWeekData!['weekly_context']['exercise_summary'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Exercise',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildExerciseStat('Workouts', '${exercise['total_workouts']}'),
                _buildExerciseStat('Minutes', '${exercise['total_minutes']}'),
                _buildExerciseStat('Calories', '${exercise['total_calories_burned']}'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Muscle Groups Worked:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (exercise['muscle_groups_worked'] as Map<String, dynamic>)
                  .entries
                  .map((entry) => Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        backgroundColor: Colors.blue.withOpacity(0.1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: exercise['workout_days'].length / 7,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 4),
            Text(
              '${exercise['workout_days'].length} active days, ${exercise['rest_days']} rest days',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExerciseStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
  
  Widget _buildHydrationSleepCard() {
    final hydration = _currentWeekData!['weekly_context']['hydration_summary'];
    final sleep = _currentWeekData!['weekly_context']['sleep_summary'];
    
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: Colors.cyan),
                      const SizedBox(width: 8),
                      const Text('Hydration'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${hydration['avg_daily_glasses']}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('glasses/day'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: hydration['hydration_consistency'] / 100,
                    backgroundColor: Colors.grey[300],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hydration['hydration_consistency']}% consistency',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bedtime, color: Colors.purple),
                      const SizedBox(width: 8),
                      const Text('Sleep'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${sleep['avg_nightly_hours']}h',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('avg/night'),
                  const SizedBox(height: 8),
                  if (sleep['best_night'] != null)
                    Text(
                      'Best: ${sleep['best_night']['hours']}h',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  if (sleep['worst_night'] != null)
                    Text(
                      'Worst: ${sleep['worst_night']['hours']}h',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildWeightProgressCard() {
    final weight = _currentWeekData!['weekly_context']['weight_progress'];
    
    if (weight['starting_weight'] == null && weight['ending_weight'] == null) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_weight, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Weight Progress',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (weight['starting_weight'] != null && weight['ending_weight'] != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      const Text('Start'),
                      Text(
                        '${weight['starting_weight']} kg',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    weight['weight_change'] > 0 
                        ? Icons.trending_up 
                        : weight['weight_change'] < 0 
                            ? Icons.trending_down 
                            : Icons.trending_flat,
                    color: weight['weight_change'] > 0 
                        ? Colors.red 
                        : weight['weight_change'] < 0 
                            ? Colors.green 
                            : Colors.grey,
                    size: 32,
                  ),
                  Column(
                    children: [
                      const Text('End'),
                      Text(
                        '${weight['ending_weight']} kg',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: weight['weight_change'] > 0 
                        ? Colors.red.withOpacity(0.1)
                        : weight['weight_change'] < 0 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    weight['weight_change'] > 0 
                        ? '+${weight['weight_change']} kg'
                        : weight['weight_change'] < 0 
                            ? '${weight['weight_change']} kg'
                            : 'No change',
                    style: TextStyle(
                      color: weight['weight_change'] > 0 
                          ? Colors.red 
                          : weight['weight_change'] < 0 
                              ? Colors.green 
                              : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInsightsCard() {
    final insights = _currentWeekData!['weekly_context']['insights'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Weekly Insights',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (insights['achievements'].isNotEmpty) ...[
              Text(
                'Achievements 🎉',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              ...insights['achievements'].map<Widget>((achievement) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(achievement)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (insights['improvements'].isNotEmpty) ...[
              Text(
                'Areas for Improvement',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              ...insights['improvements'].map<Widget>((improvement) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(improvement)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (insights['recommendations'].isNotEmpty) ...[
              Text(
                'Recommendations',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              ...insights['recommendations'].map<Widget>((rec) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDailyBreakdownChart(Map<String, dynamic> dailyData) {
    if (dailyData.isEmpty) return const SizedBox.shrink();
    
    final sortedDates = dailyData.keys.toList()..sort();
    
    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                    final date = DateTime.parse(sortedDates[value.toInt()]);
                    return Text(
                      DateFormat('E').format(date),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: sortedDates.asMap().entries.map((entry) {
                final data = dailyData[entry.value] as Map<String, dynamic>;
                return FlSpot(
                  entry.key.toDouble(),
                  (data['calories'] ?? 0).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrendsChart() {
    if (_recentWeeks.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  '4-Week Trends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: _buildMultiWeekChart(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMultiWeekChart() {
    final weeks = _recentWeeks.take(4).toList().reversed.toList();
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: weeks.map((w) => 
          (w['summary']?['avg_calories'] ?? 0).toDouble()
        ).reduce((a, b) => a > b ? a : b) * 1.2,
        barGroups: weeks.asMap().entries.map((entry) {
          final weekData = entry.value['summary'] ?? {};
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (weekData['avg_calories'] ?? 0).toDouble(),
                color: Colors.blue,
                width: 20,
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < weeks.length) {
                  final week = weeks[value.toInt()];
                  return Text(
                    'W${week['summary']?['week_number'] ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
  
  void _selectWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadWeeklyData();
    }
  }
  
  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM d').format(date);
  }
}