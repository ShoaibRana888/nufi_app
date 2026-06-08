// lib/features/home/widgets/activity_drawer.dart
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
import 'package:user_onboarding/features/reports/screens/weekly_summary_screen.dart';
import 'package:user_onboarding/features/reports/screens/today_report_screen.dart';

class ActivityDrawer extends StatelessWidget {
  final UserProfile userProfile;
  

  const ActivityDrawer({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSectionHeader('Track Your Activities'),
                _buildActivityTile(
                  context,
                  'Meals',
                  'Log your food intake and nutrition',
                  Icons.restaurant,
                  Colors.green,
                  () => _navigateToPage(context, EnhancedMealLoggingPage(userProfile: userProfile)),
                ),
                _buildActivityTile(
                  context,
                  'Water',
                  'Track your daily water intake',
                  Icons.water_drop,
                  Colors.blue,
                  () => _navigateToPage(context, WaterLoggingPage(userProfile: userProfile)),
                ),
                _buildActivityTile(
                  context,
                  'Sleep',
                  'Monitor your sleep patterns',
                  Icons.bedtime,
                  Colors.purple,
                  () => _navigateToPage(context, SleepLoggingPage(userProfile: userProfile)),
                ),
                _buildActivityTile(
                  context,
                  'Exercise',
                  'Log your workouts and activities',
                  Icons.fitness_center,
                  Colors.orange,
                  () => _navigateToPage(context, EnhancedExerciseLoggingPage(userProfile: userProfile)),
                ),
                _buildActivityTile(
                  context,
                  'Steps',
                  'Track your daily step count',
                  Icons.directions_walk,
                  Colors.green.shade700,
                  () => _navigateToPage(context, StepsLoggingPage(userProfile: userProfile)),
                ),
                _buildActivityTile(
                  context,
                  'Weight',
                  'Monitor your weight progress',
                  Icons.monitor_weight,
                  Colors.indigo,
                  () => _navigateToPage(context, WeightLoggingPage(userProfile: userProfile)),
                ),
                _buildActivityTile(
                  context,
                  'Supplements',
                  'Track your daily supplements',
                  Icons.medication,
                  Colors.teal,
                  () => _navigateToPage(context, SupplementLoggingPage(userProfile: userProfile)),
                ),
                // Only show period tracking for female users
                if (userProfile.gender.toLowerCase() == 'female')
                  _buildActivityTile(
                    context,
                    'Period',
                    'Track your menstrual cycle',
                    Icons.favorite,
                    Colors.pink,
                    () => _navigateToPage(context, PeriodCalendarPage()),
                  ),

                _buildActivityTile(
                  context,
                  "Today's Report",
                  'View your daily activity summary',
                  Icons.analytics,
                  Colors.blue,
                  () => _navigateToPage(context, TodayReportScreen(userProfile: userProfile)),
                ),

                _buildActivityTile(
                  context,
                  'Weekly Summary',
                  'View your weekly progress and insights',
                  Icons.calendar_view_week,
                  Colors.deepPurple,
                  () => _navigateToPage(context, WeeklySummaryScreen(userProfile: userProfile)),
                ),
                
                const Divider(),
                
                _buildSectionHeader('Quick Actions'),
                _buildActionTile(
                  context,
                  'View All Data',
                  'See your complete activity history',
                  Icons.analytics,
                  () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Analytics page coming soon!')),
                    );
                  },
                ),
                _buildActionTile(
                  context,
                  'Export Data',
                  'Download your health data',
                  Icons.download,
                  () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export feature coming soon!')),
                    );
                  },
                ),
              ]
            )
          )
        ]
      )
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue, Colors.blue.shade700],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  userProfile.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                userProfile.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Track your daily activities',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.pop(context); // Close drawer first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}