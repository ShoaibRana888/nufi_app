// lib/features/home/widgets/metrics_card.dart

import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/metrics/screens/detailed_metrics_screen.dart';

class MetricsCard extends StatelessWidget {
  final UserProfile userProfile;
  
  const MetricsCard({
    Key? key,
    required this.userProfile,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Extract metrics from user profile
    final bmi = userProfile.formData['bmi'] as double? ?? 0.0;
    final bmr = userProfile.formData['bmr'] as double? ?? 0.0;
    final tdee = userProfile.formData['tdee'] as double? ?? 0.0;
    
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
          const Text(
            'Health Metrics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric(
                'BMI', 
                bmi.toStringAsFixed(1), 
                _getBmiStatus(bmi),
                _getBmiColor(bmi),
              ),
              _buildMetric(
                'BMR', 
                '${bmr.toInt()}', 
                'calories/day',
                Colors.blue,
              ),
              _buildMetric(
                'TDEE', 
                '${tdee.toInt()}', 
                'calories/day',
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailedMetricsScreen(
                      userProfile: userProfile,
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.assessment,
                size: 16,
              ),
              label: const Text('View Detailed Analytics'),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetric(String name, String value, String status, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  String _getBmiStatus(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
  
  Color _getBmiColor(double bmi) {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25) return Colors.green;
    if (bmi < 30) return Colors.orange;
    return Colors.red;
  }
}