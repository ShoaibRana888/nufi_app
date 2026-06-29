import 'package:flutter/material.dart';

class SleepQualityTracker extends StatelessWidget {
  final double sleepHours;
  final double sleepQuality;
  final double deepSleepPercentage;
  final double remSleepPercentage;
  
  const   SleepQualityTracker({
    Key? key,
    required this.sleepHours,
    required this.sleepQuality,
    required this.deepSleepPercentage,
    required this.remSleepPercentage,
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
          Row(
            children: [
              const Icon(
                Icons.nightlight_round,
                color: Colors.indigo,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sleep Quality',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSleepQualityColor(sleepQuality).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getSleepQualityText(sleepQuality),
                  style: TextStyle(
                    color: _getSleepQualityColor(sleepQuality),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Sleep duration and quality
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duration',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          sleepHours.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'hours',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 70,
                      width: 70,
                      child: CircularProgressIndicator(
                        value: sleepQuality,
                        strokeWidth: 8,
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        valueColor: AlwaysStoppedAnimation<Color>(_getSleepQualityColor(sleepQuality)),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${(sleepQuality * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Text(
                          'Quality',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Sleep stages
          const Text(
            'Sleep Stages',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSleepStage(
                  'Deep Sleep',
                  deepSleepPercentage,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSleepStage(
                  'REM Sleep',
                  remSleepPercentage,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSleepStage(
                  'Light Sleep',
                  1 - deepSleepPercentage - remSleepPercentage,
                  Colors.blue.shade300,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Sleep pattern
          const Text(
            'Last Night\'s Pattern',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: SleepPatternPainter(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bedtime and wake-up
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeInfo('Bedtime', '11:30 PM', Icons.bedtime, Colors.indigo),
              _buildTimeInfo('Wakeup', '7:00 AM', Icons.wb_sunny, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSleepStage(String stageName, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stageName,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(percentage * 100).toInt()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Color _getSleepQualityColor(double quality) {
    if (quality < 0.5) {
      return Colors.red;
    } else if (quality < 0.7) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
  
  String _getSleepQualityText(double quality) {
    if (quality < 0.5) {
      return 'Poor';
    } else if (quality < 0.7) {
      return 'Fair';
    } else if (quality < 0.9) {
      return 'Good';
    } else {
      return 'Excellent';
    }
  }
}

// Custom painter for sleep pattern
class SleepPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.indigo
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final path = Path();
    
    // Draw a simulated sleep pattern wave
    path.moveTo(0, size.height * 0.5);
    
    // Light sleep
    path.cubicTo(
      size.width * 0.1, size.height * 0.3,
      size.width * 0.15, size.height * 0.3,
      size.width * 0.2, size.height * 0.4,
    );
    
    // Deep sleep
    path.cubicTo(
      size.width * 0.25, size.height * 0.8,
      size.width * 0.35, size.height * 0.8,
      size.width * 0.4, size.height * 0.7,
    );
    
    // REM sleep
    path.cubicTo(
      size.width * 0.45, size.height * 0.3,
      size.width * 0.5, size.height * 0.3,
      size.width * 0.55, size.height * 0.5,
    );
    
    // Deep sleep again
    path.cubicTo(
      size.width * 0.6, size.height * 0.8,
      size.width * 0.7, size.height * 0.8,
      size.width * 0.75, size.height * 0.6,
    );
    
    // Light sleep to wake
    path.cubicTo(
      size.width * 0.8, size.height * 0.3,
      size.width * 0.9, size.height * 0.3,
      size.width, size.height * 0.5,
    );
    
    canvas.drawPath(path, paint);
    
    // Fill the area under the curve
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    final fillPaint = Paint()
      ..color = Colors.indigo.withOpacity(0.1)
      ..style = PaintingStyle.fill;
      
    canvas.drawPath(fillPath, fillPaint);
    
    // Add markers for sleep stages
    final deepSleepPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;
      
    final remSleepPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;
      
    // Deep sleep markers
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.8), 3, deepSleepPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.8), 3, deepSleepPaint);
    
    // REM sleep markers
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.3), 3, remSleepPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}