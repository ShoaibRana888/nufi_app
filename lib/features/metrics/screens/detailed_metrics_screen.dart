// lib/features/metrics/screens/detailed_metrics_screen.dart

import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';

class DetailedMetricsScreen extends StatefulWidget {
  final UserProfile userProfile;
  
  const DetailedMetricsScreen({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<DetailedMetricsScreen> createState() => _DetailedMetricsScreenState();
}

class _DetailedMetricsScreenState extends State<DetailedMetricsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Extract metrics from user profile
    final bmi = widget.userProfile.formData['bmi'] as double? ?? 0.0;
    final bmr = widget.userProfile.formData['bmr'] as double? ?? 0.0;
    final tdee = widget.userProfile.formData['tdee'] as double? ?? 0.0;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Health Metrics', 
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              ), 
          ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Health Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().toString().substring(0, 10)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // BMI Section
                  _buildMetricCard(
                    icon: Icons.monitor_weight,
                    title: 'Body Mass Index (BMI)',
                    value: bmi,
                    valueText: bmi.toStringAsFixed(1),
                    maxValue: 40, // Reasonable max for visualization
                    color: _getBmiColor(bmi),
                    description: _getBmiDescription(bmi),
                    rangeText: _getBmiRangeText(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // BMR Section
                  _buildMetricCard(
                    icon: Icons.whatshot,
                    title: 'Basal Metabolic Rate (BMR)',
                    value: bmr,
                    valueText: '${bmr.toInt()}\ncalories/day',
                    maxValue: 3000, // Reasonable max for visualization
                    color: Colors.blue,
                    description: 'This is the number of calories your body needs to maintain basic functions at rest.',
                    rangeText: 'Typical range: 1200-2500 calories/day depending on gender, age, and body composition.',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // TDEE Section
                  _buildMetricCard(
                    icon: Icons.local_fire_department,
                    title: 'Total Daily Energy Expenditure (TDEE)',
                    value: tdee,
                    valueText: '${tdee.toInt()}\ncalories/day',
                    maxValue: 4000, // Reasonable max for visualization
                    color: Colors.green,
                    description: 'This is your estimated daily calorie needs based on your BMR and activity level.',
                    rangeText: 'Values vary based on activity: Sedentary (x1.2 BMR), Moderate (x1.55 BMR), Very Active (x1.9 BMR)',
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Understanding Section
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.lightbulb, color: Colors.amber),
                              SizedBox(width: 10),
                              Text(
                                'Understanding Your Metrics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'These metrics provide valuable insights into your health and can help guide your fitness journey.',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '• BMI helps assess your weight category',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '• BMR shows your resting calorie needs',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '• TDEE guides your daily calorie targets',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 15),
                          const Text(
                            'Remember, these are estimates to guide you. For personalized advice, consult a healthcare professional.',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required double value,
    required String valueText,
    required double maxValue,
    required Color color,
    required String description,
    required String rangeText,
  }) {
    final progress = (value / maxValue).clamp(0.0, 1.0);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Metric value in circle
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.7),
                            color,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          valueText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),
                
                // Progress indicator
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: progress * _animation.value,
                            minHeight: 10,
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            borderRadius: BorderRadius.circular(5),
                          );
                        }
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rangeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            // Action hint based on value
            Row(
              children: [
                Icon(
                  Icons.info_outline, 
                  color: color.withOpacity(0.7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getActionHint(title, value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _getActionHint(String metricType, double value) {
    if (metricType.contains('BMI')) {
      if (value < 18.5) {
        return 'Consider focusing on gaining some weight through healthy diet choices.';
      } else if (value < 25) {
        return 'Your BMI is in the healthy range. Maintain your current habits.';
      } else if (value < 30) {
        return 'Light to moderate exercise and slight calorie reduction may help.';
      } else {
        return 'Consider a gradual weight loss plan with regular exercise.';
      }
    } else if (metricType.contains('BMR')) {
      return 'This is your minimum calorie needs. Never eat below this level.';
    } else if (metricType.contains('TDEE')) {
      return 'For weight maintenance, aim to consume this many calories daily.';
    }
    return '';
  }
  
  String _getBmiDescription(double bmi) {
    if (bmi < 18.5) {
      return 'Your BMI indicates that you are underweight. Consider consulting with a healthcare professional about healthy weight gain strategies.';
    } else if (bmi < 25) {
      return 'Your BMI is in the normal range, which is associated with good health outcomes.';
    } else if (bmi < 30) {
      return 'Your BMI indicates that you are overweight. Small lifestyle changes can help you achieve a healthier weight.';
    } else {
      return 'Your BMI indicates obesity, which is associated with higher health risks. Consider consulting a healthcare professional.';
    }
  }
  
  String _getBmiRangeText() {
    return 'Underweight: <18.5 | Normal: 18.5-24.9 | Overweight: 25-29.9 | Obese: ≥30';
  }
  
  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}