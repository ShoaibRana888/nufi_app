// lib/features/tracking/screens/sleep_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/sleep_entry.dart';
import 'package:user_onboarding/data/repositories/sleep_repository.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';

class SleepHistoryPage extends StatefulWidget {
  final UserProfile userProfile;

  const SleepHistoryPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  _SleepHistoryPageState createState() => _SleepHistoryPageState();
}

class _SleepHistoryPageState extends State<SleepHistoryPage> {
  final SleepRepository _sleepRepository = SleepRepository();
  final SharingApi _sharingApi = SharingApi();
  List<SleepEntry> _sleepEntries = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSleepHistory();
  }

  Future<void> _loadSleepHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final entries = await _sleepRepository.getSleepHistory(widget.userProfile.id);
      final stats = await _sleepRepository.getSleepStats(widget.userProfile.id);
      
      setState(() {
        _sleepEntries = entries;
        _stats = stats;
      });
    } catch (e) {
      print('Error loading sleep history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sleep history: $e')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep History'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSleepHistory,
              child: Column(
                children: [
                  _buildStatsSection(),
                  Expanded(child: _buildHistoryList()),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats.isEmpty) return const SizedBox.shrink();

    // Handle both snake_case (from API) and camelCase field names
    final avgSleep = _stats['avg_sleep'] ?? _stats['avgSleep'] ?? 0.0;
    final avgQuality = _stats['avg_quality'] ?? _stats['avgQuality'] ?? 0.0;
    final avgDeepSleep = _stats['avg_deep_sleep'] ?? _stats['avgDeepSleep'] ?? 0.0;
    final entriesCount = _stats['entries_count'] ?? _stats['entriesCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '30-Day Sleep Stats',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Avg Sleep',
                      '${avgSleep.toStringAsFixed(1)}h',
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Avg Quality',
                      '${(avgQuality * 100).toStringAsFixed(0)}%',
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Avg Deep Sleep',
                      '${avgDeepSleep.toStringAsFixed(1)}h',
                      Colors.purple,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Entries',
                      '$entriesCount',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_sleepEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bedtime, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No sleep entries yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Start logging your sleep to see history here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _sleepEntries.length,
      itemBuilder: (context, index) {
        final entry = _sleepEntries[index];
        return _buildSleepEntryCard(entry);
      },
    );
  }

  Future<void> _toggleSleepSharing(SleepEntry entry) async {
    final idx = _sleepEntries.indexOf(entry);
    if (idx == -1 || entry.id == null) return;
    final wasShared = entry.sharedWithChat;
    final newShared = !wasShared;

    setState(() => _sleepEntries[idx] = entry.copyWith(sharedWithChat: newShared));

    final ok = await _sharingApi.setEntrySharing(
      userId: widget.userProfile.id!,
      activityType: 'sleep',
      itemId: entry.id!,
      shared: newShared,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() => _sleepEntries[idx] = entry.copyWith(sharedWithChat: wasShared));
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
        content: Text(newShared ? 'Sleep shared with coach' : 'Sleep hidden from coach'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildSleepEntryCard(SleepEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEE, MMM dd').format(entry.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (!entry.sharedWithChat)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message: 'Hidden from AI coach',
                          child: Icon(Icons.visibility_off, size: 16, color: Colors.grey[500]),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getQualityColor(entry.qualityScore).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getQualityLabel(entry.qualityScore),
                        style: TextStyle(
                          color: _getQualityColor(entry.qualityScore),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) {
                        if (v == 'sharing') _toggleSleepSharing(entry);
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
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEntryDetail(
                    'Total Sleep',
                    '${entry.totalHours.toStringAsFixed(1)}h',
                    Icons.schedule,
                  ),
                ),
                Expanded(
                  child: _buildEntryDetail(
                    'Deep Sleep',
                    '${entry.deepSleepHours.toStringAsFixed(1)}h',
                   Icons.nights_stay,
                 ),
               ),
             ],
           ),
           const SizedBox(height: 8),
           Row(
             children: [
               Expanded(
                 child: _buildEntryDetail(
                   'Bedtime',
                   entry.bedtime != null 
                       ? DateFormat('h:mm a').format(entry.bedtime!)
                       : 'Not set',
                   Icons.bedtime,
                 ),
               ),
               Expanded(
                 child: _buildEntryDetail(
                   'Wake Time',
                   entry.wakeTime != null 
                       ? DateFormat('h:mm a').format(entry.wakeTime!)
                       : 'Not set',
                   Icons.wb_sunny,
                 ),
               ),
             ],
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildEntryDetail(String label, String value, IconData icon) {
   return Row(
     children: [
       Icon(icon, size: 16, color: Colors.grey[600]),
       const SizedBox(width: 4),
       Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             label,
             style: TextStyle(
               fontSize: 12,
               color: Colors.grey[600],
             ),
           ),
           Text(
             value,
             style: const TextStyle(
               fontSize: 14,
               fontWeight: FontWeight.w500,
             ),
           ),
         ],
       ),
     ],
   );
 }

 String _getQualityLabel(double score) {
   if (score >= 0.8) return 'Excellent';
   if (score >= 0.6) return 'Good';
   if (score >= 0.4) return 'Fair';
   if (score >= 0.2) return 'Poor';
   return 'Very Poor';
 }

 Color _getQualityColor(double score) {
   if (score >= 0.8) return Colors.green;
   if (score >= 0.6) return Colors.lightGreen;
   if (score >= 0.4) return Colors.orange;
   if (score >= 0.2) return Colors.deepOrange;
   return Colors.red;
 }
}