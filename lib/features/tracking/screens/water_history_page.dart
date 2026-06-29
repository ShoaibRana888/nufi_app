// lib/features/tracking/screens/water_history_page.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/repositories/water_repository.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';
import 'package:intl/intl.dart';

class WaterHistoryPage extends StatefulWidget {
  final UserProfile userProfile;

  const WaterHistoryPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<WaterHistoryPage> createState() => _WaterHistoryPageState();
}

class _WaterHistoryPageState extends State<WaterHistoryPage> {
  final SharingApi _sharingApi = SharingApi();
  List<WaterEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final entries = await WaterRepository.getWaterHistory(widget.userProfile.id!, limit: 30);
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading water history: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Water History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSummaryCard(),
                    Expanded(child: _buildHistoryList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No water tracking history yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your daily water intake!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_entries.isEmpty) return const SizedBox.shrink();
    
    // Calculate summary statistics
    final totalDays = _entries.length;
    final goalAchievedDays = _entries.where((entry) => 
      entry.totalMl >= entry.targetMl).length;
    final avgDailyIntake = _entries.map((e) => e.totalMl).fold(0.0, (a, b) => a + b) / totalDays;
    final bestDay = _entries.map((e) => e.totalMl).fold(0.0, (a, b) => a > b ? a : b);
    
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Days\nTracked',
                  '$totalDays',
                  Icons.calendar_today,
                  Colors.blue,
                ),
                _buildSummaryItem(
                  'Goals\nAchieved',
                  '$goalAchievedDays/$totalDays',
                  Icons.track_changes,
                  Colors.green,
                ),
                _buildSummaryItem(
                  'Average\nDaily',
                  '${avgDailyIntake.round()}ml',
                  Icons.water_drop,
                  Colors.cyan,
                ),
                _buildSummaryItem(
                  'Best\nDay',
                  '${bestDay.round()}ml',
                  Icons.emoji_events,
                  Colors.amber,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _buildHistoryItem(entry);
      },
    );
  }

  Widget _buildHistoryItem(WaterEntry entry) {
    final progress = entry.totalMl / entry.targetMl;
    final isGoalAchieved = progress >= 1.0;
    final dateStr = DateFormat('MMM d, yyyy').format(entry.date);
    final dayOfWeek = DateFormat('EEEE').format(entry.date);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Date column
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayOfWeek,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Progress indicator
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isGoalAchieved ? Colors.green : Colors.blue,
                    ),
                  ),
                  Center(
                    child: Text(
                      '${entry.glassesConsumed}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Details column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.totalMl.toInt()}ml / ${entry.targetMl.toInt()}ml',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}% of goal',
                    style: TextStyle(
                      fontSize: 12,
                      color: isGoalAchieved ? Colors.green : Colors.grey[600],
                    ),
                  ),
                  if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.notes!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Achievement icon
            if (isGoalAchieved)
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            if (!entry.sharedWithChat)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: 'Hidden from AI coach',
                  child: Icon(Icons.visibility_off, size: 16, color: Colors.grey[500]),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) {
                if (v == 'sharing') _toggleWaterSharing(entry);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'sharing',
                  child: Row(
                    children: [
                      Icon(
                        entry.sharedWithChat ? Icons.visibility_off : Icons.visibility,
                        color: Colors.purple,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(entry.sharedWithChat ? 'Hide from coach' : 'Share with coach'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleWaterSharing(WaterEntry entry) async {
    final idx = _entries.indexOf(entry);
    if (idx == -1) return;
    final wasShared = entry.sharedWithChat;
    final newShared = !wasShared;

    setState(() => _entries[idx] = entry.copyWith(sharedWithChat: newShared));

    final ok = await _sharingApi.setDateSharing(
      userId: widget.userProfile.id!,
      activityType: 'water',
      date: entry.date,
      shared: newShared,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() => _entries[idx] = entry.copyWith(sharedWithChat: wasShared));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update sharing. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newShared ? 'Water shared with coach' : 'Water hidden from coach'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}