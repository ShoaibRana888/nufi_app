import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/day_snapshot.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/tracking/screens/sleep_logging_page.dart';
import 'package:user_onboarding/data/services/api/sleep_api.dart';
import 'package:intl/intl.dart';

class CompactSleepTracker extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onUpdate;

  /// The dashboard's one read of today; tonight's entry comes from it. When
  /// there is none, last night's is a different day and stays a request of
  /// its own.
  final Future<DaySnapshot> day;

  /// Ask the dashboard to read the day again (after this card wrote to it).
  final Future<void> Function() refreshDay;

  const CompactSleepTracker({
    Key? key,
    required this.userProfile,
    required this.day,
    required this.refreshDay,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<CompactSleepTracker> createState() => _CompactSleepTrackerState();
}

class _CompactSleepTrackerState extends State<CompactSleepTracker> 
    with SingleTickerProviderStateMixin {
  final SleepApi _apiService = SleepApi();
  double _lastNightHours = 0;
  String _sleepQuality = '';
  bool _isLoading = true;
  // True once the first load attempt completes — keeps existing data on screen
  // during later refreshes instead of flashing a spinner.
  bool _hasLoaded = false;
  late double _sleepGoal;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  DateTime? _sleepDate;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _initializeSleepGoal();
    _loadSleepData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeSleepGoal() {
    _sleepGoal = widget.userProfile.sleepHours?.toDouble() ?? 8.0;
    _sleepGoal = _sleepGoal.clamp(4.0, 12.0);
  }

  @override
  void didUpdateWidget(CompactSleepTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _initializeSleepGoal();
    }
    if (oldWidget.userProfile != widget.userProfile ||
        !identical(oldWidget.day, widget.day)) {
      _loadSleepData();
    }
  }

  Future<void> _loadSleepData() async {
    setState(() => _isLoading = true);
    
    try {
      // Today's entry from the day the dashboard already read.
      final today = DateTime.now();
      final todayEntry = (await widget.day).sleep.value;
      double? hours;
      double? qualityScore;

      if (todayEntry != null) {
        _sleepDate = today;
        hours = todayEntry.totalHours;
        qualityScore = todayEntry.qualityScore;
      } else {
        // No entry for today: last night's. A different day, so its own read.
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
        final sleepLog = await _apiService.getSleepEntryByDate(
          widget.userProfile.id, yesterdayStr);
        _sleepDate = yesterday;
        if (sleepLog != null && sleepLog['success'] == true && sleepLog['entry'] != null) {
          final entry = sleepLog['entry'];
          hours = (entry['total_hours'] as num?)?.toDouble() ?? 0;
          qualityScore = (entry['quality_score'] as num?)?.toDouble() ?? 0;
        }
      }
      if (!mounted) return;

      if (hours != null) {
        final loadedHours = hours;
        final loadedScore = qualityScore ?? 0;
        setState(() {
          _lastNightHours = loadedHours;
          _sleepQuality = _getQualityFromScore(loadedScore);
        });
        
        // Animate progress after data loads
        _animationController.forward();
      } else {
        setState(() {
          _lastNightHours = 0;
          _sleepQuality = '';
        });
      }
    } catch (e) {
      print('Error loading sleep data: $e');
      // Don't wipe the last-known values to 0 on a failed/timed-out refresh —
      // that was blanking the card. Keep whatever we already showed.
    } finally {
      if (mounted) setState(() {
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  String _getQualityFromScore(double score) {
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.7) return 'Good';
    if (score >= 0.5) return 'Fair';
    return 'Poor';
  }

  void _navigateToSleepLogging() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SleepLoggingPage(
          userProfile: widget.userProfile,
        ),
      ),
    ).then((_) {
      widget.refreshDay();
      widget.onUpdate?.call();
    });
  }

  Color _getQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getQualityIcon(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return Icons.sentiment_very_satisfied;
      case 'good':
        return Icons.sentiment_satisfied;
      case 'fair':
        return Icons.sentiment_neutral;
      case 'poor':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.bedtime;
    }
  }

  Widget _buildSleepRing() {
    final progress = (_lastNightHours / _sleepGoal).clamp(0.0, 1.0);
    
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background ring
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.transparent),
              ),
            ),
            // Progress ring
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: progress * _progressAnimation.value,
                strokeWidth: 8,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            // Center content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.nightlight_round,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_lastNightHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_lastNightHours / _sleepGoal).clamp(0.0, 1.0);
    final bool goalMet = _lastNightHours >= _sleepGoal;
    final isToday = _sleepDate != null && 
        DateFormat('yyyy-MM-dd').format(_sleepDate!) == 
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B5ACF),
            const Color(0xFF8B7FD6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5ACF).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _navigateToSleepLogging,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: (_isLoading && !_hasLoaded)
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.bedtime,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sleep Tracker',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Goal: ${_sleepGoal.toStringAsFixed(0)} hours',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_lastNightHours > 0 && goalMet)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Goal Met',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Main content
                      Row(
                        children: [
                          // Sleep ring
                          _buildSleepRing(),
                          
                          const SizedBox(width: 20),
                          
                          // Sleep details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isToday ? 'Last Night' : 
                                        DateFormat('MMM d').format(_sleepDate ?? DateTime.now()),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                if (_lastNightHours > 0) ...[
                                  Text(
                                    '${_lastNightHours.toStringAsFixed(1)} hrs',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getQualityColor(_sleepQuality).withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getQualityIcon(_sleepQuality),
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Quality: $_sleepQuality',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Not logged',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to track your sleep',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Progress bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sleep Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Action button — translucent "glass" pill on the gradient.
                      Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _navigateToSleepLogging,
                            borderRadius: BorderRadius.circular(22),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _lastNightHours > 0 ? Icons.edit : Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _lastNightHours > 0 ? 'Update Sleep' : 'Log Sleep',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}