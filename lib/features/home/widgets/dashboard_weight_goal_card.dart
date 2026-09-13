// lib/features/home/widgets/dashboard_weight_goal_card.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/weight_api.dart';
import 'package:user_onboarding/features/tracking/screens/weight_logging_page.dart';

class DashboardWeightGoalCard extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onUpdate;

  /// Injectable for tests; defaults to a real WeightApi. See ADR-0004.
  final WeightApi? weightApi;

  const DashboardWeightGoalCard({
    Key? key,
    required this.userProfile,
    this.onUpdate,
    this.weightApi,
  }) : super(key: key);
  
  @override
  State<DashboardWeightGoalCard> createState() => _DashboardWeightGoalCardState();
}

class _DashboardWeightGoalCardState extends State<DashboardWeightGoalCard> {
  late final WeightApi _weightApi = widget.weightApi ?? WeightApi();

  double? _currentWeight;
  double? _startingWeight;
  bool _isLoading = true;
  // True once the first load attempt completes — keeps the card populated on
  // later refreshes instead of flashing the spinner.
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadWeightData();
  }

  Future<void> _loadWeightData() async {
    try {
      // Get the full weight history so we can show the progress the user has
      // actually made (start → current), not just the latest reading.
      final weightHistory = await _weightApi.getWeightHistory(widget.userProfile.id);
      if (!mounted) return;

      setState(() {
        // Entries come back newest-first.
        _currentWeight = weightHistory.isNotEmpty
            ? weightHistory.first.weight
            : widget.userProfile.weight;

        // Prefer the locked-in starting weight from the profile; otherwise fall
        // back to the oldest logged entry, then the profile weight.
        _startingWeight = widget.userProfile.startingWeight ??
            (weightHistory.isNotEmpty
                ? weightHistory.last.weight
                : widget.userProfile.weight);

        _isLoading = false;
        _hasLoaded = true;
      });
    } catch (e) {
      print('Error loading weight data: $e');
      if (!mounted) return;
      setState(() {
        // Only fall back to the profile weight if we never loaded real data;
        // otherwise keep the last-known values so a failed refresh doesn't
        // reset the card.
        if (!_hasLoaded) {
          _currentWeight = widget.userProfile.weight;
          _startingWeight = widget.userProfile.startingWeight ?? _currentWeight;
        }
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final weightGoal = widget.userProfile.weightGoal;
    if (weightGoal.isEmpty) {
      return const SizedBox.shrink();
    }
    
    if (_isLoading && !_hasLoaded) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final currentWeight = _currentWeight ?? widget.userProfile.weight;
    final targetWeight = widget.userProfile.targetWeight;
    final startingWeight = _startingWeight ?? currentWeight;
    final totalChange = currentWeight - startingWeight;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and goal
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getWeightGoalColor(weightGoal).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getWeightGoalColor(weightGoal).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getWeightGoalIcon(weightGoal),
                  color: _getWeightGoalColor(weightGoal),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatWeightGoal(weightGoal),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getWeightGoalDescription(weightGoal),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Weight journey: Started → Current → Target with the change so far.
          _buildJourney(startingWeight, currentWeight, targetWeight, weightGoal, totalChange),

          // Progress bar for non-maintenance goals
          if (weightGoal != 'maintain_weight') ...[
            const SizedBox(height: 16),
            _buildProgressBar(currentWeight, targetWeight, weightGoal, startingWeight),
          ],

          const SizedBox(height: 16),

          // Log Weight button (full width for a clearer call to action)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeightLoggingPage(
                      userProfile: widget.userProfile,
                    ),
                  ),
                );

                // Refresh the weight after returning
                await _loadWeightData();

                // Call the parent's refresh callback if provided
                widget.onUpdate?.call();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log Weight'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getWeightGoalColor(weightGoal),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          
          // Timeline if exists
          if (widget.userProfile.goalTimeline != null && weightGoal != 'maintain_weight') ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Timeline: ${_formatTimeline(widget.userProfile.goalTimeline!)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Compact "Started → Current → Target" journey that surfaces the progress
  // the user has actually made, mirroring the weight logging screen.
  Widget _buildJourney(
    double start,
    double current,
    double target,
    String goal,
    double totalChange,
  ) {
    final isMaintain = goal == 'maintain_weight';
    final color = _getWeightGoalColor(goal);
    final hasChanged = totalChange.abs() >= 0.05;
    final isLoss = totalChange < 0;

    // How much is still left to reach the target.
    final remaining = (current - target).abs();
    final goalReached = remaining < 0.05;
    final isLossGoal = goal == 'lose_weight';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildJourneyNode('Started', start, Colors.blueGrey, Icons.flag_outlined),
        // Connector showing how much has changed since the start. The rail sits
        // at the vertical centre of the circles (see _buildConnector).
        _buildConnector(
          color: hasChanged ? color : Colors.grey,
          badgeIcon: hasChanged
              ? (isLoss ? Icons.trending_down : Icons.trending_up)
              : Icons.trending_flat,
          badgeText: hasChanged
              ? '${isLoss ? '-' : '+'}${totalChange.abs().toStringAsFixed(1)} kg'
              : 'No change',
        ),
        _buildJourneyNode('Current', current, Colors.blue, Icons.person_outline),
        if (!isMaintain) ...[
          // Connector showing how much is still left to reach the goal.
          _buildConnector(
            color: Colors.grey,
            badgeColor: goalReached ? Colors.green : Colors.grey.shade600,
            badgeIcon: goalReached
                ? Icons.check_circle
                : (isLossGoal ? Icons.trending_down : Icons.trending_up),
            badgeText: goalReached ? 'Reached' : '${remaining.toStringAsFixed(1)} kg',
          ),
          _buildJourneyNode('Target', target, Colors.green, Icons.emoji_events_outlined),
        ],
      ],
    );
  }

  // A node in the journey rail. The circle diameter (2 * radius) must match the
  // connector height so the rail line passes exactly through the circle centre.
  static const double _nodeCircleRadius = 18;

  Widget _buildJourneyNode(String label, double value, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: _nodeCircleRadius,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '${value.toStringAsFixed(1)} kg',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // Rail segment between two nodes. Its box height equals the circle diameter,
  // and the line is vertically centred, so it lines up with the circle centres
  // regardless of the labels underneath. An optional badge sits on the rail.
  Widget _buildConnector({
    required Color color,
    Color? badgeColor,
    IconData? badgeIcon,
    String? badgeText,
  }) {
    final effectiveBadgeColor = badgeColor ?? color;
    return Expanded(
      child: SizedBox(
        height: _nodeCircleRadius * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (badgeText != null)
              Container(
                // Match the card background so the badge masks the rail behind it.
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null) ...[
                      Icon(badgeIcon, size: 14, color: effectiveBadgeColor),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: effectiveBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProgressBar(double current, double target, String goal, double start) {
    double progress = 0;
    String progressText = '';

    if (goal == 'lose_weight') {
      // For weight loss, progress increases as weight decreases.
      if (start > target) {
        final totalToLose = start - target;
        final lost = start - current;
        progress = (lost / totalToLose).clamp(0.0, 1.0);

        if (current > target) {
          progressText = '${(current - target).toStringAsFixed(1)} kg to go';
        } else {
          progressText = 'Goal achieved! 🎉';
        }
      }
    } else if (goal == 'gain_weight') {
      // For weight gain, progress increases as weight increases.
      if (start < target) {
        final totalToGain = target - start;
        final gained = current - start;
        progress = (gained / totalToGain).clamp(0.0, 1.0);

        if (current < target) {
          progressText = '${(target - current).toStringAsFixed(1)} kg to go';
        } else {
          progressText = 'Goal achieved! 🎉';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(_getWeightGoalColor(goal)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% • $progressText',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  // ... rest of the helper methods remain the same ...
  IconData _getWeightGoalIcon(String goal) {
    switch (goal.toLowerCase()) {
      case 'lose_weight':
        return Icons.trending_down;
      case 'gain_weight':
        return Icons.trending_up;
      case 'maintain_weight':
        return Icons.horizontal_rule;
      default:
        return Icons.fitness_center;
    }
  }
  
  Color _getWeightGoalColor(String goal) {
    switch (goal.toLowerCase()) {
      case 'lose_weight':
        return Colors.orange;
      case 'gain_weight':
        return Colors.green;
      case 'maintain_weight':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  String _formatWeightGoal(String goal) {
    switch (goal.toLowerCase()) {
      case 'lose_weight':
        return 'Weight Loss Goal';
      case 'gain_weight':
        return 'Weight Gain Goal';
      case 'maintain_weight':
        return 'Maintain Weight';
      default:
        return 'Weight Goal';
    }
  }
  
  String _getWeightGoalDescription(String goal) {
    switch (goal.toLowerCase()) {
      case 'lose_weight':
        return 'Working towards a healthier weight';
      case 'gain_weight':
        return 'Building mass and strength';
      case 'maintain_weight':
        return 'Keeping steady at current weight';
      default:
        return 'Tracking weight progress';
    }
  }
  
  String _formatTimeline(String timeline) {
    switch (timeline.toLowerCase().replaceAll('_', '')) {
      case '1month':
        return '1 Month';
      case '3months':
        return '3 Months';
      case '6months':
        return '6 Months';
      case '1year':
        return '1 Year';
      case '12weeks':
        return '12 Weeks';
      case '24weeks':
        return '24 Weeks';
      default:
        return timeline.replaceAll('_', ' ').split(' ').map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join(' ');
    }
  }
}