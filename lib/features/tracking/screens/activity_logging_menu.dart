// lib/features/tracking/screens/activity_logging_menu.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/tracking/screens/meal_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/sleep_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/water_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/exercise_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/period_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/weight_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/steps_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/supplements_logging_page.dart';

class ActivityLoggingMenu extends StatelessWidget {
  final UserProfile userProfile;

  const ActivityLoggingMenu({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activities = _getActivities();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Logging'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.blue.shade50],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _buildActivityCard(
                        context,
                        activity['title'] as String,
                        activity['subtitle'] as String,
                        activity['icon'] as IconData,
                        activity['color'] as Color,
                        activity['page'] as Widget,
                      );
                    },
                  ),
                ),  
              ),
              _buildQuickStats(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getActivities() {
    final baseActivities = [
      {
        'title': 'Meals',
        'subtitle': 'Track nutrition & calories',
        'icon': Icons.restaurant,
        'color': Colors.green,
        'page': EnhancedMealLoggingPage(userProfile: userProfile),
      },
      {
        'title': 'Water',
        'subtitle': 'Monitor hydration',
        'icon': Icons.water_drop,
        'color': Colors.blue,
        'page': WaterLoggingPage(userProfile: userProfile),
      },
      {
        'title': 'Sleep',
        'subtitle': 'Log sleep patterns',
        'icon': Icons.bedtime,
        'color': Colors.purple,
        'page': SleepLoggingPage(userProfile: userProfile),
      },
      {
        'title': 'Exercise',
        'subtitle': 'Record workouts',
        'icon': Icons.fitness_center,
        'color': Colors.orange,
        'page': EnhancedExerciseLoggingPage(userProfile: userProfile),
      },
      {
        'title': 'Steps',
        'subtitle': 'Daily step count',
        'icon': Icons.directions_walk,
        'color': Colors.green.shade700,
        'page': StepsLoggingPage(userProfile: userProfile),
      },
      {
        'title': 'Weight',
        'subtitle': 'Monitor progress',
        'icon': Icons.monitor_weight,
        'color': Colors.indigo,
        'page': WeightLoggingPage(userProfile: userProfile),
      },
      {
        'title': 'Supplements',
        'subtitle': 'Track daily vitamins',
        'icon': Icons.medication,
        'color': Colors.teal,
        'page': SupplementLoggingPage(userProfile: userProfile),
      },
    ];

    // Add period tracking for female users
    if (userProfile.gender?.toLowerCase() == 'female') {
      baseActivities.add({
        'title': 'Period',
        'subtitle': 'Menstrual cycle',
        'icon': Icons.favorite,
        'color': Colors.pink,
        'page': PeriodCalendarPage(),
      });
    }

    return baseActivities;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'What would you like to log?',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an activity to track your daily progress',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        ),
        borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
            ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Quick Stats',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickStat('Meals', '2/3', Icons.restaurant, Colors.green),
              _buildQuickStat('Water', '1.2L', Icons.water_drop, Colors.blue),
              _buildQuickStat('Steps', '8.5K', Icons.directions_walk, Colors.orange),
              _buildQuickStat('Sleep', '7.5h', Icons.bedtime, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}