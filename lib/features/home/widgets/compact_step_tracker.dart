// lib/features/home/widgets/compact_step_tracker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/repositories/step_repository.dart';
import 'package:user_onboarding/data/services/notification_service.dart';
import 'package:user_onboarding/features/tracking/screens/steps_logging_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:user_onboarding/data/services/step_counter_service.dart';

class CompactStepTracker extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onUpdate;

  const CompactStepTracker({
    Key? key,
    required this.userProfile,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<CompactStepTracker> createState() => _CompactStepTrackerState();
}

class _CompactStepTrackerState extends State<CompactStepTracker> 
    with SingleTickerProviderStateMixin {
  StepEntry? _todayEntry;
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;
  final TextEditingController _quickAddController = TextEditingController();
  final NotificationService _notificationService = NotificationService();
  final StepCounterService _stepCounterService = StepCounterService();
  bool _hasPedometerPermission = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fillAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _checkPermissionAndInitialize();
    _stepCounterService.addListener(_onStepCountUpdate);
  }

  void _onStepCountUpdate() {
    if (_stepCounterService.isPedometerAvailable && mounted) {
      _loadTodayEntry();
    }
  }

  Future<void> _checkPermissionAndInitialize() async {
    final status = await Permission.activityRecognition.status;
    setState(() {
      _hasPedometerPermission = status.isGranted;
    });
    
    if (_hasPedometerPermission && widget.userProfile.id != null) {
      await _stepCounterService.initialize(widget.userProfile.id!);
    }
    
    await _loadTodayEntry();
  }

  Future<void> _requestPedometerPermission() async {
    if (widget.userProfile.id == null) return;
    
    final granted = await _stepCounterService.requestPermissionAndStart(
      widget.userProfile.id!
    );
    
    setState(() {
      _hasPedometerPermission = granted;
    });
    
    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Step tracking enabled! Steps will sync automatically.'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      await _loadTodayEntry();
    } else {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_walk, color: Colors.orange),
            SizedBox(width: 8),
            Text('Step Tracking'),
          ],
        ),
        content: const Text(
          'Enable activity recognition to automatically track your steps.\n\n'
          'You can continue using manual step logging if you prefer not to grant this permission.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Use Manual'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto Step Tracking',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Enable to sync steps automatically',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _requestPedometerPermission,
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stepCounterService.removeListener(_onStepCountUpdate);
    _animationController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayEntry() async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final entry = await StepRepository.getTodayStepEntry(widget.userProfile.id!);
      final stepGoal = widget.userProfile.dailyStepGoal ?? 
                      (widget.userProfile.dailyStepGoal as int?) ?? 
                      10000;
      
      setState(() {
        _todayEntry = entry ?? StepEntry(
          userId: widget.userProfile.id!,
          date: DateTime.now(),
          steps: 0,
          goal: stepGoal,
          sourceType: 'manual',
        );
        _isLoading = false;
      });
      
      if (_todayEntry != null) {
        final progress = (_todayEntry!.steps / _todayEntry!.goal).clamp(0.0, 1.0);
        _fillAnimation = Tween<double>(
          begin: 0.0,
          end: progress,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ));
        _animationController.forward(from: 0);
      }
    } catch (e) {
      print('Error loading step entry: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showQuickAddDialog() {
    _quickAddController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Add Steps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quickAddController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps to add',
                hintText: 'e.g., 1000',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [500, 1000, 2000, 5000].map((steps) {
                return ActionChip(
                  label: Text('+$steps'),
                  onPressed: () {
                    Navigator.pop(context);
                    _quickAddSteps(steps);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final steps = int.tryParse(_quickAddController.text);
              if (steps != null && steps > 0) {
                Navigator.pop(context);
                _quickAddSteps(steps);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }  

  Future<void> _quickAddSteps(int stepsToAdd) async {
    if (_todayEntry == null || _isSaving) return;
    
    setState(() => _isSaving = true);
    
    final previousSteps = _todayEntry!.steps;
    final newSteps = previousSteps + stepsToAdd;
    final goalSteps = _todayEntry!.goal;
    
    // Optimistically update UI
    setState(() {
      _todayEntry = _todayEntry!.copyWith(
        steps: newSteps,
      );
    });
    
    try {
      // Save to database
      await StepRepository.saveStepEntry(
        _todayEntry!.copyWith(steps: newSteps),
      );
      
      // Check for milestone notifications
      await _checkStepMilestones(previousSteps, newSteps, goalSteps);
      
      widget.onUpdate?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $stepsToAdd steps!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving step entry: $e');
      // Revert on error
      setState(() {
        _todayEntry = _todayEntry!.copyWith(
          steps: previousSteps,
        );
      });
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _checkStepMilestones(int previousSteps, int currentSteps, int goalSteps) async {
    if (widget.userProfile.id == null) return;
    
    final previousProgress = (previousSteps / goalSteps * 100).round();
    final currentProgress = (currentSteps / goalSteps * 100).round();
    
    // Get SharedPreferences to track if we've already shown notification today
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';
    
    // Check 50% milestone
    if (previousProgress < 50 && currentProgress >= 50) {
      final notified50Key = 'step_milestone_50_$todayKey';
      final alreadyNotified = prefs.getBool(notified50Key) ?? false;
      
      if (!alreadyNotified) {
        await _notificationService.showMilestoneNotification(
          id: NotificationService.stepMilestone50Id,
          title: '🎯 Halfway There!',
          body: 'You\'ve reached 50% of your step goal! Keep going!',
          userId: widget.userProfile.id!,
          milestoneType: 'steps_50',
        );
        await prefs.setBool(notified50Key, true);
      }
    }
    
    // Check 100% milestone
    if (previousProgress < 100 && currentProgress >= 100) {
      final notified100Key = 'step_milestone_100_$todayKey';
      final alreadyNotified = prefs.getBool(notified100Key) ?? false;
      
      if (!alreadyNotified) {
        await _notificationService.showMilestoneNotification(
          id: NotificationService.stepMilestone100Id,
          title: '🎉 Goal Achieved!',
          body: 'Congratulations! You\'ve reached your daily step goal of ${_formatSteps(goalSteps)} steps!',
          userId: widget.userProfile.id!,
          milestoneType: 'steps_100',
        );
        await prefs.setBool(notified100Key, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_todayEntry == null) return const SizedBox.shrink();

    final steps = _todayEntry!.steps;
    final goal = _todayEntry!.goal;
    final progress = (steps / goal).clamp(0.0, 1.0);
    final isGoalReached = steps >= goal;
    final formatter = NumberFormat('#,###');

    return Column(
      children: [
        // Show permission banner if pedometer not enabled
        if (!_hasPedometerPermission)
          _buildPermissionBanner(),
        
        // Existing step tracker card
        Container(
          child: Material(
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StepsLoggingPage(
                      userProfile: widget.userProfile,
                    ),
                  ),
                ).then((_) => _loadTodayEntry());
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  children: [
                    // Step icon with animation and source indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.directions_walk,
                            color: isGoalReached ? Colors.green : Colors.orange.shade400,
                            size: 24,
                          ),
                          if (isGoalReached)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Show sync icon if using pedometer
                          if (_hasPedometerPermission && _stepCounterService.isPedometerAvailable)
                            Positioned(
                              left: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.sync,
                                  size: 8,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Progress content (existing code - keep as is)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${formatter.format(steps)} / ${_formatSteps(goal)} steps',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              if (isGoalReached) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '🎯 Goal!',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          // Animated progress bar (existing code - keep as is)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return AnimatedBuilder(
                                animation: _fillAnimation,
                                builder: (context, child) {
                                  final fillWidth = constraints.maxWidth * progress * _fillAnimation.value;
                                  
                                  return Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          color: Colors.grey.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      Container(
                                        height: 8,
                                        width: fillWidth,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(4),
                                          gradient: LinearGradient(
                                            colors: isGoalReached 
                                                ? [Colors.green, Colors.green.shade600]
                                                : progress > 0.7
                                                    ? [Colors.orange.shade400, Colors.orange.shade500]
                                                    : [Colors.orange.shade300, Colors.orange.shade400],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            if (progress > 0)
                                              BoxShadow(
                                                color: (isGoalReached ? Colors.green : Colors.orange)
                                                    .withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Quick add button (existing code - keep as is)
                    IconButton(
                      onPressed: _isSaving ? null : _showQuickAddDialog,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                              ),
                            )
                          : Icon(
                              Icons.add_circle,
                              color: Colors.orange.shade500,
                            ),
                      tooltip: 'Quick add steps',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}