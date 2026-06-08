// lib/features/tracking/screens/nutrition_trends_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';

class NutritionTrendsScreen extends StatefulWidget {
  final UserProfile userProfile;

  const NutritionTrendsScreen({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<NutritionTrendsScreen> createState() => _NutritionTrendsScreenState();
}

class _NutritionTrendsScreenState extends State<NutritionTrendsScreen>
    with SingleTickerProviderStateMixin {
  final MealApi _apiService = MealApi();
  late TabController _tabController;

  Map<String, dynamic>? _trendsData;
  Map<String, dynamic>? _macroData;
  bool _isLoading = true;
  int _selectedDays = 30;
  String _selectedMetric = 'calories';

  final Map<String, Color> _metricColors = {
    'calories': Colors.orange,
    'protein': Colors.red,
    'carbs': Colors.blue,
    'fat': Colors.yellow[700]!,
    'net_calories': Colors.green,
  };

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
    if (widget.userProfile.id == null) return;

    setState(() => _isLoading = true);

    try {
      final trendsData = await _apiService.getNutritionTrends(
        widget.userProfile.id!,
        days: _selectedDays,
      );

      final macroData = await _apiService.getMacroBreakdown(
        widget.userProfile.id!,
        days: _selectedDays,
      );

      if (mounted) {
        setState(() {
          _trendsData = trendsData;
          _macroData = macroData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading trends: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trends: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Trends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Trends', icon: Icon(Icons.show_chart)),
            Tab(text: 'Macros', icon: Icon(Icons.pie_chart)),
            Tab(text: 'Summary', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: _selectedDays,
            onSelected: (value) {
              setState(() => _selectedDays = value);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 14, child: Text('Last 14 days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('$_selectedDays days'),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrendsTab(),
                _buildMacrosTab(),
                _buildSummaryTab(),
              ],
            ),
    );
  }

  Widget _buildTrendsTab() {
    if (_trendsData == null) {
      return const Center(child: Text('No data available'));
    }

    final trendData = List<Map<String, dynamic>>.from(_trendsData!['trend_data'] ?? []);
    final averages = _trendsData!['averages'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric selector
          _buildMetricSelector(),
          const SizedBox(height: 16),

          // Main chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getMetricTitle(_selectedMetric),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Avg: ${_getAverageValue(averages)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: _buildLineChart(trendData),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Weekly summaries
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._buildWeeklySummaries(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMetricChip('calories', 'Calories'),
          _buildMetricChip('protein', 'Protein'),
          _buildMetricChip('carbs', 'Carbs'),
          _buildMetricChip('fat', 'Fat'),
          _buildMetricChip('net_calories', 'Net Cals'),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String metric, String label) {
    final isSelected = _selectedMetric == metric;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: _metricColors[metric]?.withOpacity(0.3),
        onSelected: (selected) {
          setState(() => _selectedMetric = metric);
        },
      ),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    // Filter out days with no data for cleaner chart
    final filteredData = data.where((d) => d['meals_logged'] > 0).toList();
    if (filteredData.isEmpty) {
      return const Center(child: Text('No meals logged in this period'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < filteredData.length; i++) {
      double value;
      switch (_selectedMetric) {
        case 'calories':
          value = (filteredData[i]['calories_consumed'] ?? 0).toDouble();
          break;
        case 'protein':
          value = (filteredData[i]['protein_g'] ?? 0).toDouble();
          break;
        case 'carbs':
          value = (filteredData[i]['carbs_g'] ?? 0).toDouble();
          break;
        case 'fat':
          value = (filteredData[i]['fat_g'] ?? 0).toDouble();
          break;
        case 'net_calories':
          value = (filteredData[i]['net_calories'] ?? 0).toDouble();
          break;
        default:
          value = 0;
      }
      spots.add(FlSpot(i.toDouble(), value));
    }

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 5,
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (filteredData.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < filteredData.length) {
                  final date = DateTime.parse(filteredData[index]['date']);
                  return Text(
                    DateFormat('M/d').format(date),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _metricColors[_selectedMetric],
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: filteredData.length <= 14,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: _metricColors[_selectedMetric]?.withOpacity(0.2),
            ),
          ),
        ],
        minY: minY > 0 ? minY * 0.9 : minY * 1.1,
        maxY: maxY * 1.1,
      ),
    );
  }

  String _getMetricTitle(String metric) {
    switch (metric) {
      case 'calories':
        return 'Daily Calories';
      case 'protein':
        return 'Daily Protein (g)';
      case 'carbs':
        return 'Daily Carbs (g)';
      case 'fat':
        return 'Daily Fat (g)';
      case 'net_calories':
        return 'Net Calories (Food - Exercise)';
      default:
        return metric;
    }
  }

  String _getAverageValue(Map<String, dynamic> averages) {
    switch (_selectedMetric) {
      case 'calories':
        return '${averages['avg_calories']?.round() ?? 0} kcal/day';
      case 'protein':
        return '${averages['avg_protein']?.toStringAsFixed(1) ?? 0}g/day';
      case 'carbs':
        return '${averages['avg_carbs']?.toStringAsFixed(1) ?? 0}g/day';
      case 'fat':
        return '${averages['avg_fat']?.toStringAsFixed(1) ?? 0}g/day';
      case 'net_calories':
        return '${averages['avg_net_calories']?.round() ?? 0} kcal/day';
      default:
        return '';
    }
  }

  List<Widget> _buildWeeklySummaries() {
    final summaries = List<Map<String, dynamic>>.from(
      _trendsData?['weekly_summaries'] ?? [],
    );

    return summaries.map((week) {
      final weekStart = DateTime.parse(week['week_start']);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Week of ${DateFormat('MMM d').format(weekStart)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Text(
                '${week['avg_calories']} cal',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                '${week['days_logged']} days',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildMacrosTab() {
    if (_macroData == null) {
      return const Center(child: Text('No data available'));
    }

    final percentages = _macroData!['macro_percentages'] ?? {};
    final totals = _macroData!['totals'] ?? {};
    final mealBreakdown = Map<String, dynamic>.from(
      _macroData!['meal_type_breakdown'] ?? {},
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Macro pie chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Macro Distribution',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildMacroPieChart(percentages),
                  ),
                  const SizedBox(height: 16),
                  _buildMacroLegend(percentages, totals),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Calories by meal type
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories by Meal Type',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildMealTypeBarChart(mealBreakdown),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPieChart(Map<String, dynamic> percentages) {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          PieChartSectionData(
            color: Colors.red,
            value: (percentages['protein'] ?? 0).toDouble(),
            title: '${percentages['protein']?.toStringAsFixed(0) ?? 0}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: Colors.blue,
            value: (percentages['carbs'] ?? 0).toDouble(),
            title: '${percentages['carbs']?.toStringAsFixed(0) ?? 0}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: Colors.yellow[700],
            value: (percentages['fat'] ?? 0).toDouble(),
            title: '${percentages['fat']?.toStringAsFixed(0) ?? 0}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroLegend(Map<String, dynamic> percentages, Map<String, dynamic> totals) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildLegendItem('Protein', Colors.red, '${totals['protein_g']?.toStringAsFixed(0) ?? 0}g'),
        _buildLegendItem('Carbs', Colors.blue, '${totals['carbs_g']?.toStringAsFixed(0) ?? 0}g'),
        _buildLegendItem('Fat', Colors.yellow[700]!, '${totals['fat_g']?.toStringAsFixed(0) ?? 0}g'),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(label),
          ],
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

  Widget _buildMealTypeBarChart(Map<String, dynamic> mealBreakdown) {
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    final colors = [Colors.orange, Colors.green, Colors.blue, Colors.purple];

    final bars = <BarChartGroupData>[];
    for (int i = 0; i < mealTypes.length; i++) {
      final data = mealBreakdown[mealTypes[i]] ?? {'calories': 0};
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (data['calories'] ?? 0).toDouble(),
              color: colors[i],
              width: 30,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: bars,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < mealTypes.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      mealTypes[index].substring(0, 1).toUpperCase() +
                          mealTypes[index].substring(1),
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildSummaryTab() {
    if (_trendsData == null) {
      return const Center(child: Text('No data available'));
    }

    final averages = _trendsData!['averages'] ?? {};
    final calorieGoal = averages['calorie_goal'] ?? 2000;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Key stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Logging Streak',
                  '${averages['logging_streak'] ?? 0} days',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Days Logged',
                  '${averages['days_logged'] ?? 0} / $_selectedDays',
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Avg Calories',
                  '${averages['avg_calories']?.round() ?? 0}',
                  Icons.restaurant,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'vs Goal',
                  '${((averages['avg_calories'] ?? 0) - calorieGoal).round()}',
                  Icons.flag,
                  ((averages['avg_calories'] ?? 0) <= calorieGoal)
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Average macros card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Averages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAverageRow('Calories', '${averages['avg_calories']?.round() ?? 0}', 'kcal'),
                  _buildAverageRow('Protein', '${averages['avg_protein']?.toStringAsFixed(1) ?? 0}', 'g'),
                  _buildAverageRow('Carbs', '${averages['avg_carbs']?.toStringAsFixed(1) ?? 0}', 'g'),
                  _buildAverageRow('Fat', '${averages['avg_fat']?.toStringAsFixed(1) ?? 0}', 'g'),
                  _buildAverageRow('Fiber', '${averages['avg_fiber']?.toStringAsFixed(1) ?? 0}', 'g'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
}