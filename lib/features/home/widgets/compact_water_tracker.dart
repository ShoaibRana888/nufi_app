// lib/features/home/widgets/compact_water_tracker.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/repositories/water_repository.dart';
import 'package:user_onboarding/features/tracking/screens/water_logging_page.dart';

class CompactWaterTracker extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onUpdate;

  const CompactWaterTracker({
    Key? key,
    required this.userProfile,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<CompactWaterTracker> createState() => _CompactWaterTrackerState();
}

class _CompactWaterTrackerState extends State<CompactWaterTracker> 
    with SingleTickerProviderStateMixin {
  WaterEntry? _todayEntry;
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;
  late Animation<double> _fillAnimation;

  static const double mlPerGlass = 250.0;

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
    _loadTodayEntry();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayEntry() async {
    try {
      setState(() => _isLoading = true);
      
      final entry = await WaterRepository.getTodayWaterEntry(widget.userProfile.id);
      
      if (entry != null) {
        setState(() {
          _todayEntry = entry;
        });
      } else {
        // Create a new entry for today if none exists
        final targetGlasses = widget.userProfile.formData['waterIntakeGlasses'] ?? 8;
        setState(() {
          _todayEntry = WaterEntry(
            userId: widget.userProfile.id,
            date: DateTime.now(),
            glassesConsumed: 0,
            totalMl: 0,
            targetMl: targetGlasses * 250.0,
            notes: '',
          );
        });
      }
      
      // Start the animation after data is loaded
      _animationController.forward();
      
    } catch (e) {
      print('Error loading today\'s water entry: $e');
      // Still create a default entry on error
      final targetGlasses = widget.userProfile.formData['waterIntakeGlasses'] ?? 8;
      setState(() {
        _todayEntry = WaterEntry(
          userId: widget.userProfile.id,
          date: DateTime.now(),
          glassesConsumed: 0,
          totalMl: 0,
          targetMl: targetGlasses * 250.0,
          notes: '',
        );
      });
      
      // Start animation even on error
      _animationController.forward();
      
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _quickAddGlass() async {
    await _addGlasses(1);
  }

  Future<void> _addGlasses(int count) async {
    if (_todayEntry == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final updatedEntry = _todayEntry!.copyWith(
        glassesConsumed: _todayEntry!.glassesConsumed + count,
        totalMl: (_todayEntry!.glassesConsumed + count) * mlPerGlass,
      );

      await WaterRepository.saveWaterEntry(updatedEntry);
      
      setState(() {
        _todayEntry = updatedEntry;
        _isSaving = false;
      });

      // Don't recreate the animation, just reset and play it
      _animationController.forward(from: 0);

      // Haptic feedback
      HapticFeedback.lightImpact();

      // Call the update callback
      widget.onUpdate?.call();

      // Show achievement message if goal reached
      final targetGlasses = widget.userProfile.waterIntakeGlasses ?? 8;
      if (updatedEntry.glassesConsumed >= targetGlasses && 
          (_todayEntry!.glassesConsumed - count) < targetGlasses) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Daily water goal achieved!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving water entry: $e');
      setState(() => _isSaving = false);
    }
  }

  void _showQuickLogDialog() {
    final targetGlasses = widget.userProfile.waterIntakeGlasses ?? 8;
    final glassesConsumed = _todayEntry?.glassesConsumed ?? 0;
    final remaining = targetGlasses - glassesConsumed;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickLogBottomSheet(
        currentGlasses: glassesConsumed,
        targetGlasses: targetGlasses,
        remainingGlasses: remaining,
        onAddGlasses: (count) {
          Navigator.pop(context);
          _addGlasses(count);
        },
        onFillAll: () {
          Navigator.pop(context);
          if (remaining > 0) {
            _addGlasses(remaining);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    final targetGlasses = widget.userProfile.waterIntakeGlasses ?? 8;
    final glassesConsumed = _todayEntry?.glassesConsumed ?? 0;
    final progress = (glassesConsumed / targetGlasses).clamp(0.0, 1.0);
    final isGoalReached = glassesConsumed >= targetGlasses;

    return Container(
      child: Material(
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WaterLoggingPage(
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
                // Water icon with animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.water_drop,
                    color: isGoalReached ? Colors.green : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Progress info and bar
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Water',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '$glassesConsumed / $targetGlasses glasses',
                            style: TextStyle(
                              fontSize: 12,
                              color: isGoalReached ? Colors.green : Colors.grey[600],
                              fontWeight: isGoalReached ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Progress bar
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              AnimatedBuilder(
                                animation: _fillAnimation,
                                builder: (context, child) {
                                  // Calculate the actual width based on current progress
                                  final fillWidth = constraints.maxWidth * progress * _fillAnimation.value;
                                  
                                  return Container(
                                    height: 8,
                                    width: fillWidth,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        colors: isGoalReached
                                            ? [Colors.green, Colors.green.shade600]
                                            : [Colors.blue, Colors.blue.shade600],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      boxShadow: [
                                        if (fillWidth > 0)
                                          BoxShadow(
                                            color: Colors.blue.withOpacity(0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick add single glass
                    IconButton(
                      onPressed: _isSaving || isGoalReached ? null : _quickAddGlass,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            )
                          : Icon(
                              Icons.add_circle_outline,
                              color: isGoalReached 
                                  ? Colors.grey.shade400 
                                  : Colors.blue,
                              size: 22,
                            ),
                      tooltip: 'Add 1 glass',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    
                    // More options button
                    IconButton(
                      onPressed: _isSaving ? null : _showQuickLogDialog,
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey[600],
                        size: 22,
                      ),
                      tooltip: 'More options',
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Bottom sheet for quick logging options
class _QuickLogBottomSheet extends StatelessWidget {
  final int currentGlasses;
  final int targetGlasses;
  final int remainingGlasses;
  final Function(int) onAddGlasses;
  final VoidCallback onFillAll;

  const _QuickLogBottomSheet({
    Key? key,
    required this.currentGlasses,
    required this.targetGlasses,
    required this.remainingGlasses,
    required this.onAddGlasses,
    required this.onFillAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          const Text(
            'Quick Water Log',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Current status
          Text(
            '$currentGlasses of $targetGlasses glasses',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          // Quick add options
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickAddButton(
                label: '+2',
                subtitle: 'glasses',
                onTap: () => onAddGlasses(2),
                color: Colors.blue,
              ),
              _QuickAddButton(
                label: '+3',
                subtitle: 'glasses',
                onTap: () => onAddGlasses(3),
                color: Colors.blue,
              ),
              _QuickAddButton(
                label: '+4',
                subtitle: 'glasses',
                onTap: () => onAddGlasses(4),
                color: Colors.blue,
              ),
              _QuickAddButton(
                label: '+5',
                subtitle: 'glasses',
                onTap: () => onAddGlasses(5),
                color: Colors.blue,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Fill remaining button
          if (remainingGlasses > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onFillAll,
                icon: const Icon(Icons.water_drop),
                label: Text(
                  'Fill remaining ($remainingGlasses glasses)',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Goal Achieved! 🎉',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Custom amount input
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showCustomAmountDialog(context);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Custom amount'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showCustomAmountDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter glasses'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Number of glasses',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.water_drop),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text);
              if (count != null && count > 0) {
                Navigator.pop(context);
                onAddGlasses(count);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _QuickAddButton({
    Key? key,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}