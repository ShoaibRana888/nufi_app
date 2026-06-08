// lib/features/reports/screens/trends_screen.dart

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

class TrendsScreen extends StatefulWidget {
  final String userId;
  
  const TrendsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  final ChatApi _apiService = ChatApi();
  List<Map<String, dynamic>> _summaries = [];
  String _selectedMetric = 'calories';
  bool _isLoading = true;
  
  final Map<String, String> _metrics = {
    'calories': 'Average Calories',
    'workouts': 'Total Workouts',
    'sleep': 'Average Sleep',
    'weight': 'Weight Change',
  };
  
  @override
  void initState() {
    super.initState();
    _loadTrends();
  }
  
  Future<void> _loadTrends() async {
    setState(() => _isLoading = true);
    
    try {
      final summaries = await _apiService.getWeeklySummaries(
        widget.userId,
        weeks: 12,
      );
      
      setState(() {
        _summaries = summaries.reversed.toList(); // Oldest to newest
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading trends: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('12-Week Trends'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedMetric,
            onSelected: (value) {
              setState(() {
                _selectedMetric = value;
              });
            },
            itemBuilder: (context) => _metrics.entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(_metrics[_selectedMetric]!),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? const Center(child: Text('No data available'))
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildTrendChart(),
                      ),
                    ),
                    _buildStatsSummary(),
                  ],
                ),
    );
  }
  
  Widget _buildTrendChart() {
    final data = _getChartData();
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getInterval(),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatYAxisValue(value),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
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
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < _summaries.length) {
                  final week = _summaries[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'W${week['week_number']}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Theme.of(context).primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final week = _summaries[spot.x.toInt()];
                return LineTooltipItem(
                  '${_metrics[_selectedMetric]}\n${_formatYAxisValue(spot.y)}\nWeek ${week['week_number']}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsSummary() {
    final values = _summaries.map((s) => _getMetricValue(s)).where((v) => v != null).toList();
    
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final average = values.reduce((a, b) => a! + b!)! / values.length;
    final min = values.reduce((a, b) => a! < b! ? a : b)!;
    final max = values.reduce((a, b) => a! > b! ? a : b)!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Average', _formatYAxisValue(average)),
          _buildStatItem('Min', _formatYAxisValue(min)),
          _buildStatItem('Max', _formatYAxisValue(max)),
          _buildStatItem('Trend', _calculateTrend(values)),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
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
  
  List<FlSpot> _getChartData() {
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < _summaries.length; i++) {
      final value = _getMetricValue(_summaries[i]);
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    
    return spots;
  }
  
  double? _getMetricValue(Map<String, dynamic> summary) {
    switch (_selectedMetric) {
      case 'calories':
        return summary['avg_calories']?.toDouble();
      case 'workouts':
        return summary['total_workouts']?.toDouble();
      case 'sleep':
        return summary['avg_sleep']?.toDouble();
      case 'weight':
        return summary['weight_change']?.toDouble();
      default:
        return null;
    }
  }
  
  String _formatYAxisValue(double value) {
    switch (_selectedMetric) {
      case 'calories':
        return value.toInt().toString();
      case 'workouts':
        return value.toInt().toString();
      case 'sleep':
        return '${value.toStringAsFixed(1)}h';
      case 'weight':
        return '${value.toStringAsFixed(1)}kg';
      default:
        return value.toStringAsFixed(1);
    }
  }
  
  double _getInterval() {
    switch (_selectedMetric) {
      case 'calories':
        return 500;
      case 'workouts':
        return 1;
      case 'sleep':
        return 2;
      case 'weight':
        return 1;
      default:
        return 10;
    }
  }
  
  String _calculateTrend(List<double?> values) {
    if (values.length < 2) return 'N/A';
    
    final recent = values.skip(values.length ~/ 2).where((v) => v != null).toList();
    final older = values.take(values.length ~/ 2).where((v) => v != null).toList();
    
    if (recent.isEmpty || older.isEmpty) return 'N/A';
    
    final recentAvg = recent.reduce((a, b) => a! + b!)! / recent.length;
    final olderAvg = older.reduce((a, b) => a! + b!)! / older.length;
    
    if (recentAvg > olderAvg * 1.05) {
      return '↗️ Up';
    } else if (recentAvg < olderAvg * 0.95) {
      return '↘️ Down';
    } else {
      return '→ Stable';
    }
  }
}