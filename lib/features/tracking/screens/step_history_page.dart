// lib/features/tracking/screens/step_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/repositories/step_repository.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';

class StepHistoryPage extends StatefulWidget {
  final UserProfile userProfile;

  const StepHistoryPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<StepHistoryPage> createState() => _StepHistoryPageState();
}

class _StepHistoryPageState extends State<StepHistoryPage> {
  final SharingApi _sharingApi = SharingApi();
  List<StepEntry> _allEntries = [];
  List<StepEntry> _filteredEntries = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (widget.userProfile.id == null) {
      print('❌ User profile ID is null');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('📊 Loading step history for user: ${widget.userProfile.id}');
      final entries = await StepRepository.getAllStepEntries(widget.userProfile.id!);
      print('✅ Loaded ${entries.length} step entries');
      
      entries.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
      
      setState(() {
        _allEntries = entries;
        _filteredEntries = entries;
        _isLoading = false;
      });
      
      print('📋 Filtered entries: ${_filteredEntries.length}');
    } catch (e) {
      print('❌ Error loading step history: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    final now = DateTime.now();
    
    setState(() {
      _filteredEntries = _allEntries.where((entry) {
        // Date filter
        bool matchesDateFilter = true;
        switch (_selectedFilter) {
          case 'This Week':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            matchesDateFilter = entry.date.isAfter(weekStart.subtract(const Duration(days: 1)));
            break;
          case 'This Month':
            final monthStart = DateTime(now.year, now.month, 1);
            matchesDateFilter = entry.date.isAfter(monthStart.subtract(const Duration(days: 1)));
            break;
          case 'Goal Achieved':
            matchesDateFilter = entry.steps >= entry.goal;
            break;
        }

        // Search filter
        final matchesSearch = query.isEmpty || 
            DateFormat('MMM dd, yyyy').format(entry.date).toLowerCase().contains(query) ||
            entry.steps.toString().contains(query);

        return matchesDateFilter && matchesSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step History'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by date or steps...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _filterEntries(),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'This Week', 'This Month', 'Goal Achieved']
                  .map((filter) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter),
                          selected: _selectedFilter == filter,
                          onSelected: (selected) {
                            setState(() => _selectedFilter = filter);
                            _filterEntries();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
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
            Icons.directions_walk,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No step data found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your steps to see history here',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        return _buildHistoryCard(entry);
      },
    );
  }

  Future<void> _toggleStepSharing(StepEntry entry) async {
    final wasShared = entry.sharedWithChat;
    final newShared = !wasShared;

    // Steps are a per-day aggregate, so match by date across both lists.
    void apply(bool shared) {
      setState(() {
        for (final list in [_allEntries, _filteredEntries]) {
          final i = list.indexWhere((e) => DateUtils.isSameDay(e.date, entry.date));
          if (i != -1) list[i] = list[i].copyWith(sharedWithChat: shared);
        }
      });
    }

    apply(newShared);

    final ok = await _sharingApi.setDateSharing(
      userId: widget.userProfile.id!,
      activityType: 'steps',
      date: entry.date,
      shared: newShared,
    );

    if (!mounted) return;
    if (!ok) {
      apply(wasShared);
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
        content: Text(newShared ? 'Steps shared with coach' : 'Steps hidden from coach'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildHistoryCard(StepEntry entry) {
    final progress = entry.goal > 0 ? (entry.steps / entry.goal).clamp(0.0, 1.0) : 0.0;
    final isGoalAchieved = entry.steps >= entry.goal;
    final isToday = DateUtils.isSameDay(entry.date, DateTime.now());
    
    // Calculate stats if missing (for older entries)
    final calories = entry.caloriesBurned > 0 
        ? entry.caloriesBurned 
        : _calculateCalories(entry.steps);
    final distance = entry.distanceKm > 0 
        ? entry.distanceKm 
        : _calculateDistance(entry.steps);
    final activeMinutes = entry.activeMinutes > 0 
        ? entry.activeMinutes 
        : _calculateActiveMinutes(entry.steps);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM dd').format(entry.date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? Colors.green.shade700 : null,
                      ),
                    ),
                    if (isToday)
                      const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (isGoalAchieved)
                      const Icon(
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
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(entry.sourceType.toUpperCase()),
                      backgroundColor: entry.sourceType == 'health_app'
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
                      labelStyle: TextStyle(
                        fontSize: 10,
                        color: entry.sourceType == 'health_app'
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (v) {
                        if (v == 'sharing') _toggleStepSharing(entry);
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
            const SizedBox(height: 16),
            
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isGoalAchieved ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            
            // Steps info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.steps.toStringAsFixed(0)} steps',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Goal: ${entry.goal.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isGoalAchieved ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            
            // Always show stats (calculate if missing)
            if (entry.steps > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    'Calories',
                    '${calories.toStringAsFixed(0)}',
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  _buildStatItem(
                    'Distance',
                    '${distance.toStringAsFixed(2)} km',
                    Icons.straighten,
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'Active Min',
                    '${activeMinutes}',
                    Icons.timer,
                    Colors.purple,
                  ),
                ],
              ),
            ],
            
            if (entry.lastSynced != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last synced: ${DateFormat('MMM dd, HH:mm').format(entry.lastSynced!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  double _calculateCalories(int steps) {
    // Use default weight of 70kg if user weight not available
    final userWeight = widget.userProfile.weight ?? 70;
    return steps * 0.04 * (userWeight / 70);
  }

  double _calculateDistance(int steps) {
    // Average step length: 0.78 meters
    return steps * 0.00078; // km
  }

  int _calculateActiveMinutes(int steps) {
    // Rough estimation: 100 steps = 1 minute of activity
    return (steps / 100).round();
  }

}