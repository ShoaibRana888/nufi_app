import 'package:flutter/material.dart';

class StrengthProgressCard extends StatelessWidget {
  final List<Map<String, dynamic>> lifts;
  
  const StrengthProgressCard({
    Key? key,
    required this.lifts,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
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
            'Strength Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...lifts.map((lift) => _buildLiftProgress(context, lift)).toList(),
        ],
      ),
    );
  }
  
  Widget _buildLiftProgress(BuildContext context, Map<String, dynamic> lift) {
    final String name = lift['name'];
    final double current = lift['current'];
    final double previous = lift['previous'];
    final String unit = lift['unit'] ?? 'kg';
    
    // Calculate percentage increase
    final double increase = current - previous;
    final double percentageIncrease = (previous > 0) ? (increase / previous) * 100 : 0;
    final bool isImproved = current > previous;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${current.toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isImproved ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isImproved ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  Text(
                    '${percentageIncrease.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isImproved ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // Use constraints.maxWidth instead of MediaQuery
              final maxWidth = constraints.maxWidth;
              
              return Stack(
                children: [
                  // Background
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Previous value
                  Container(
                    height: 8,
                    width: maxWidth * (previous / (current > previous ? current : previous + 10)),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Current value
                  Container(
                    height: 8,
                    width: maxWidth * (current / (current > previous ? current : previous + 10)),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            }
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Previous: ${previous.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              if (isImproved)
                Text(
                  '+${increase.toStringAsFixed(1)} $unit',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}