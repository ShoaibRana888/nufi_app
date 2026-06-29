// lib/features/onboarding/screens/sleep_info_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class SleepInfoPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;

  const SleepInfoPage({
    Key? key,
    required this.formData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<SleepInfoPage> createState() => _SleepInfoPageState();
}

class _SleepInfoPageState extends State<SleepInfoPage> with SingleTickerProviderStateMixin {
  double _sleepHours = 8.0;
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 0); // 10:00 PM
  TimeOfDay _wakeupTime = const TimeOfDay(hour: 6, minute: 0); // 6:00 AM
  List<String> _selectedSleepIssues = [];
  bool _showValidationErrors = false;
  bool _adjustByBedtime = true; // true = adjust wake time, false = adjust bedtime
  
  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<Map<String, dynamic>> _sleepPresets = [
    {
      'name': 'Early Bird',
      'bedtime': const TimeOfDay(hour: 22, minute: 0),
      'wakeup': const TimeOfDay(hour: 6, minute: 0),
      'hours': 8.0,
      'icon': Icons.wb_sunny,
      'color': Colors.orange,
    },
    {
      'name': 'Night Owl',
      'bedtime': const TimeOfDay(hour: 0, minute: 0),
      'wakeup': const TimeOfDay(hour: 8, minute: 0),
      'hours': 8.0,
      'icon': Icons.nightlight_round,
      'color': Colors.indigo,
    },
    {
      'name': 'Standard',
      'bedtime': const TimeOfDay(hour: 23, minute: 0),
      'wakeup': const TimeOfDay(hour: 7, minute: 0),
      'hours': 8.0,
      'icon': Icons.schedule,
      'color': Colors.blue,
    },
  ];

  final List<Map<String, dynamic>> _sleepIssues = [
    {'id': 'None', 'icon': Icons.check_circle, 'color': Colors.green},
    {'id': 'Difficulty falling asleep', 'icon': Icons.bedtime_off, 'color': Colors.orange},
    {'id': 'Waking up during the night', 'icon': Icons.nights_stay, 'color': Colors.purple},
    {'id': 'Waking up too early', 'icon': Icons.alarm, 'color': Colors.amber},
    {'id': 'Snoring', 'icon': Icons.volume_up, 'color': Colors.blue},
    {'id': 'Sleep apnea', 'icon': Icons.air, 'color': Colors.red},
    {'id': 'Restless legs', 'icon': Icons.accessibility_new, 'color': Colors.teal},
    {'id': 'Insomnia', 'icon': Icons.visibility_off, 'color': Colors.indigo},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Load saved data
    _sleepHours = widget.formData['sleepHours'] ?? 8.0;
    
    // Parse bedtime
    final savedBedtime = widget.formData['bedtime'] ?? '10:00 PM';
    if (savedBedtime.isNotEmpty) {
      _bedtime = _parseTimeString(savedBedtime);
    }
    
    // Parse wakeup time
    final savedWakeup = widget.formData['wakeupTime'] ?? '6:00 AM';
    if (savedWakeup.isNotEmpty) {
      _wakeupTime = _parseTimeString(savedWakeup);
    }
    
    // Load sleep issues
    if (widget.formData['sleepIssues'] != null) {
      _selectedSleepIssues = List<String>.from(widget.formData['sleepIssues']);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.replaceAll(RegExp(r'[AP]M'), '').trim().split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      if (timeStr.contains('PM') && hour != 12) {
        hour += 12;
      } else if (timeStr.contains('AM') && hour == 12) {
        hour = 0;
      }
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 22, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _updateSleepTimes() {
    if (_adjustByBedtime) {
      // Calculate wake time based on bedtime and sleep hours
      final totalMinutes = (_bedtime.hour * 60 + _bedtime.minute + (_sleepHours * 60)).round();
      final wakeHour = (totalMinutes ~/ 60) % 24;
      final wakeMinute = totalMinutes % 60;
      _wakeupTime = TimeOfDay(hour: wakeHour, minute: wakeMinute);
    } else {
      // Calculate bedtime based on wake time and sleep hours
      final totalMinutes = (_wakeupTime.hour * 60 + _wakeupTime.minute - (_sleepHours * 60)).round();
      final bedHour = totalMinutes < 0 ? (totalMinutes + 1440) ~/ 60 : (totalMinutes ~/ 60) % 24;
      final bedMinute = totalMinutes < 0 ? (totalMinutes + 1440) % 60 : totalMinutes % 60;
      _bedtime = TimeOfDay(hour: bedHour, minute: bedMinute);
    }
    
    // Save data
    widget.onDataChanged('sleepHours', _sleepHours);
    widget.onDataChanged('bedtime', _formatTimeOfDay(_bedtime));
    widget.onDataChanged('wakeupTime', _formatTimeOfDay(_wakeupTime));
  }

  void _applyPreset(Map<String, dynamic> preset) {
    setState(() {
      _bedtime = preset['bedtime'] as TimeOfDay;
      _wakeupTime = preset['wakeup'] as TimeOfDay;
      _sleepHours = preset['hours'] as double;
      _showValidationErrors = false;
    });
    
    widget.onDataChanged('sleepHours', _sleepHours);
    widget.onDataChanged('bedtime', _formatTimeOfDay(_bedtime));
    widget.onDataChanged('wakeupTime', _formatTimeOfDay(_wakeupTime));
    
    // Add a little animation feedback
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _selectTime(bool isBedtime) async {
    final initialTime = isBedtime ? _bedtime : _wakeupTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: isBedtime ? 'Select Bedtime' : 'Select Wake Time',
    );
    
    if (picked != null) {
      setState(() {
        if (isBedtime) {
          _bedtime = picked;
          _adjustByBedtime = true;
        } else {
          _wakeupTime = picked;
          _adjustByBedtime = false;
        }
        _updateSleepTimes();
      });
    }
  }

  String _getSleepQualityMessage() {
    if (_sleepHours < 6) {
      return '⚠️ Less than recommended. Adults need 7-9 hours.';
    } else if (_sleepHours >= 6 && _sleepHours < 7) {
      return '💤 Slightly below recommended. Consider 7-9 hours.';
    } else if (_sleepHours >= 7 && _sleepHours <= 9) {
      return '✨ Perfect! This is the recommended range.';
    } else {
      return '😴 More than typical. Quality matters too!';
    }
  }

  Color _getSleepQualityColor() {
    if (_sleepHours < 6) return Colors.orange;
    if (_sleepHours >= 6 && _sleepHours < 7) return Colors.amber;
    if (_sleepHours >= 7 && _sleepHours <= 9) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Schedule',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A consistent sleep schedule is crucial for your health and fitness goals.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Quick Presets
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _sleepPresets.length,
              itemBuilder: (context, index) {
                final preset = _sleepPresets[index];
                return GestureDetector(
                  onTap: () => _applyPreset(preset),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (preset['color'] as Color).withOpacity(0.1),
                          (preset['color'] as Color).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (preset['color'] as Color).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          preset['icon'] as IconData,
                          color: preset['color'] as Color,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          preset['name'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: preset['color'] as Color,
                          ),
                        ),
                        Text(
                          '${preset['hours']}h sleep',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Visual Clock Display
          Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.9 + (_animation.value * 0.1),
                  child: Container(
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: SleepClockPainter(
                        bedtime: _bedtime,
                        wakeupTime: _wakeupTime,
                        animation: _animation.value,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bedtime,
                              size: 32,
                              color: Colors.indigo.withOpacity(0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_sleepHours.toStringAsFixed(1)}h',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'of sleep',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Sleep Duration Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sleep Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSleepQualityColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getSleepQualityColor()),
                    ),
                    child: Text(
                      '${_sleepHours.toStringAsFixed(1)} hours',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getSleepQualityColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _getSleepQualityColor(),
                  inactiveTrackColor: _getSleepQualityColor().withOpacity(0.2),
                  thumbColor: _getSleepQualityColor(),
                  overlayColor: _getSleepQualityColor().withOpacity(0.2),
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: _sleepHours,
                  min: 4,
                  max: 12,
                  divisions: 16,
                  onChanged: (value) {
                    setState(() {
                      _sleepHours = value;
                      _updateSleepTimes();
                    });
                  },
                ),
              ),
              Center(
                child: Text(
                  _getSleepQualityMessage(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getSleepQualityColor(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Time Selection with Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                // Toggle for adjustment mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Adjust by:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _adjustByBedtime = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _adjustByBedtime ? Colors.indigo : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Bedtime',
                                style: TextStyle(
                                  color: _adjustByBedtime ? Colors.white : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _adjustByBedtime = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: !_adjustByBedtime ? Colors.orange : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Wake Time',
                                style: TextStyle(
                                  color: !_adjustByBedtime ? Colors.white : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Time display buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _adjustByBedtime ? Colors.indigo.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _adjustByBedtime ? Colors.indigo : Colors.grey[300]!,
                              width: _adjustByBedtime ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.bedtime,
                                color: _adjustByBedtime ? Colors.indigo : Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bedtime',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimeOfDay(_bedtime),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _adjustByBedtime ? Colors.indigo : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _selectTime(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: !_adjustByBedtime ? Colors.orange.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_adjustByBedtime ? Colors.orange : Colors.grey[300]!,
                              width: !_adjustByBedtime ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.wb_sunny,
                                color: !_adjustByBedtime ? Colors.orange : Colors.grey[600],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Wake Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimeOfDay(_wakeupTime),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: !_adjustByBedtime ? Colors.orange : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sleep Issues Selection
          const Text(
            'Do you experience any sleep issues?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all that apply',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sleepIssues.map((issue) {
              final isSelected = _selectedSleepIssues.contains(issue['id']);
              final isNone = issue['id'] == 'None';
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isNone) {
                      _selectedSleepIssues.clear();
                      if (!isSelected) {
                        _selectedSleepIssues.add('None');
                      }
                    } else {
                      _selectedSleepIssues.remove('None');
                      if (isSelected) {
                        _selectedSleepIssues.remove(issue['id']);
                      } else {
                        _selectedSleepIssues.add(issue['id'] as String);
                      }
                    }
                  });
                  widget.onDataChanged('sleepIssues', _selectedSleepIssues);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (issue['color'] as Color).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? issue['color'] as Color
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        issue['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? issue['color'] as Color
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        issue['id'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? issue['color'] as Color
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the Sleep Clock
class SleepClockPainter extends CustomPainter {
  final TimeOfDay bedtime;
  final TimeOfDay wakeupTime;
  final double animation;

  SleepClockPainter({
    required this.bedtime,
    required this.wakeupTime,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Draw clock circle
    final circlePaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw hour markers
    final markerPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * (math.pi / 180);
      final start = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(start, end, markerPaint);
    }

    // Calculate angles for sleep arc
    final bedtimeAngle = ((bedtime.hour % 12) * 30 + bedtime.minute * 0.5 - 90) * (math.pi / 180);
    final wakeupAngle = ((wakeupTime.hour % 12) * 30 + wakeupTime.minute * 0.5 - 90) * (math.pi / 180);

    // Draw sleep arc
    final sleepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.indigo.withOpacity(0.3 * animation),
          Colors.blue.withOpacity(0.5 * animation),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round;

    double sweepAngle;
    if (wakeupAngle > bedtimeAngle) {
      sweepAngle = wakeupAngle - bedtimeAngle;
    } else {
      sweepAngle = (2 * math.pi) - (bedtimeAngle - wakeupAngle);
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 20),
      bedtimeAngle,
      sweepAngle * animation,
      false,
      sleepPaint,
    );

    // Draw bedtime indicator
    final bedtimePoint = Offset(
      center.dx + (radius - 20) * math.cos(bedtimeAngle),
      center.dy + (radius - 20) * math.sin(bedtimeAngle),
    );
    canvas.drawCircle(
      bedtimePoint,
      8 * animation,
      Paint()..color = Colors.indigo,
    );

    // Draw wakeup indicator
    final wakeupPoint = Offset(
      center.dx + (radius - 20) * math.cos(wakeupAngle),
      center.dy + (radius - 20) * math.sin(wakeupAngle),
    );
    canvas.drawCircle(
      wakeupPoint,
      8 * animation,
      Paint()..color = Colors.orange,
    );
  }

  @override
  bool shouldRepaint(SleepClockPainter oldDelegate) {
    return oldDelegate.bedtime != bedtime ||
        oldDelegate.wakeupTime != wakeupTime ||
        oldDelegate.animation != animation;
  }
}