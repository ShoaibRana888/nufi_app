// lib/features/tracking/screens/supplement_history_page.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/repositories/supplement_repository.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class SupplementHistoryPage extends StatefulWidget {
  final UserProfile userProfile;

  const SupplementHistoryPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<SupplementHistoryPage> createState() => _SupplementHistoryPageState();
}

class _SupplementHistoryPageState extends State<SupplementHistoryPage> {
  final SharingApi _sharingApi = SharingApi();
  List<Map<String, dynamic>> _historyData = [];
  List<String> _userSupplements = [];
  bool _isLoading = true;
  String _selectedPeriod = '7 days';
  final List<String> _periodOptions = ['7 days', '14 days', '30 days', '90 days'];

  @override
  void initState() {
    super.initState();
    _loadUserSupplements();
  }

  Future<void> _loadUserSupplements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final supplementPreferenceKey = 'supplement_setup_${widget.userProfile.id}_list';
      final supplementsJson = prefs.getString(supplementPreferenceKey);
      
      if (supplementsJson != null) {
        final List<dynamic> supplementsList = jsonDecode(supplementsJson);
        setState(() {
          _userSupplements = supplementsList
              .map((s) => s['name'] as String)
              .toList();
        });
      }
      
      await _loadHistoryData();
    } catch (e) {
      print('Error loading user supplements: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistoryData() async {
    try {
      final days = int.parse(_selectedPeriod.split(' ')[0]);
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      
      // Load from database
      final dbHistory = await _loadFromDatabase(startDate, endDate);
      
      // Load from local storage for recent days
      final localHistory = await _loadFromLocalStorage(startDate, endDate);
      
      // Combine and deduplicate
      final combinedHistory = <String, Map<String, dynamic>>{};
      
      // Add database records
      for (var record in dbHistory) {
        final key = '${record['date']}_${record['supplement_name']}';
        combinedHistory[key] = record;
      }
      
      // Add local records (overwrites if same day/supplement)
      for (var record in localHistory) {
        final key = '${record['date']}_${record['supplement_name']}';
        combinedHistory[key] = record;
      }
      
      // Convert to list and sort by date
      final historyList = combinedHistory.values.toList();
      historyList.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      
      setState(() {
        _historyData = historyList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadFromDatabase(DateTime startDate, DateTime endDate) async {
    try {
      final days = endDate.difference(startDate).inDays + 1;
      final results = await SupplementRepository.getSupplementHistory(
        widget.userProfile.id!,
        days: days,
      );
      
      print('📊 Loaded ${results.length} records from database');
      return results;
    } catch (e) {
      print('❌ Error loading from database: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadFromLocalStorage(DateTime startDate, DateTime endDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = <Map<String, dynamic>>[];
      
      // Check each day in the range
      for (var date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final statusKey = 'supplement_status_${widget.userProfile.id}_$dateStr';
        final statusJson = prefs.getString(statusKey);
        
        if (statusJson != null) {
          final Map<String, dynamic> statusMap = jsonDecode(statusJson);
          
          statusMap.forEach((supplementName, taken) {
            records.add({
              'date': dateStr,
              'supplement_name': supplementName,
              'taken': taken,
              'source': 'local',
            });
          });
        }
      }
      
      return records;
    } catch (e) {
      print('Error loading from local storage: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplement History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
                _isLoading = true;
              });
              _loadHistoryData();
            },
            itemBuilder: (context) => _periodOptions.map((period) {
              return PopupMenuItem<String>(
                value: period,
                child: Row(
                  children: [
                    Icon(
                      _selectedPeriod == period ? Icons.check : Icons.access_time,
                      color: Colors.black,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(period),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryStats(),
                Expanded(
                  child: _historyData.isEmpty
                      ? _buildEmptyState()
                      : _buildHistoryList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryStats() {
    if (_historyData.isEmpty) return const SizedBox.shrink();

    final totalEntries = _historyData.length;
    final takenEntries = _historyData.where((entry) => entry['taken'] == true).length;
    final adherenceRate = totalEntries > 0 ? (takenEntries / totalEntries * 100).round() : 0;
    
    // Calculate daily stats
    final dailyStats = <String, Map<String, int>>{};
    for (var entry in _historyData) {
      final date = entry['date'] as String;
      if (!dailyStats.containsKey(date)) {
        dailyStats[date] = {'total': 0, 'taken': 0};
      }
      dailyStats[date]!['total'] = (dailyStats[date]!['total']! + 1);
      if (entry['taken'] == true) {
        dailyStats[date]!['taken'] = (dailyStats[date]!['taken']! + 1);
      }
    }
    
    final perfectDays = dailyStats.values.where((stats) => 
      stats['taken']! > 0 && stats['taken'] == stats['total']).length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$_selectedPeriod Overview',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn('Adherence Rate', '$adherenceRate%'),
              _buildStatColumn('Perfect Days', '$perfectDays'),
              _buildStatColumn('Total Taken', '$takenEntries'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No History Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking supplements to see your history',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    // Group by date
    final groupedData = <String, List<Map<String, dynamic>>>{};
    for (var entry in _historyData) {
      final date = entry['date'] as String;
      if (!groupedData.containsKey(date)) {
        groupedData[date] = [];
      }
      groupedData[date]!.add(entry);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedData.length,
      itemBuilder: (context, index) {
        final date = groupedData.keys.elementAt(index);
        final dateEntries = groupedData[date]!;
        
        return _buildDateGroup(date, dateEntries);
      },
    );
  }

  Widget _buildDateGroup(String date, List<Map<String, dynamic>> entries) {
    final dateTime = DateTime.parse(date);
    final isToday = DateFormat('yyyy-MM-dd').format(DateTime.now()) == date;
    final isYesterday = DateFormat('yyyy-MM-dd').format(
      DateTime.now().subtract(const Duration(days: 1))) == date;
    
    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isYesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE, MMM d').format(dateTime);
    }
    
    final takenCount = entries.where((e) => e['taken'] == true).length;
    final totalCount = entries.length;
    final completionRate = totalCount > 0 ? (takenCount / totalCount) : 0.0;
    
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
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$takenCount/$totalCount',
                      style: TextStyle(
                        fontSize: 14,
                        color: completionRate == 1.0 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      completionRate == 1.0 ? Icons.check_circle : Icons.warning,
                      color: completionRate == 1.0 ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    Builder(
                      builder: (context) {
                        final isShared = !entries.any((e) => e['shared_with_chat'] == false);
                        return PopupMenuButton<String>(
                          icon: Icon(
                            isShared ? Icons.more_vert : Icons.visibility_off,
                            size: 18,
                            color: isShared ? null : Colors.grey[500],
                          ),
                          onSelected: (v) {
                            if (v == 'sharing') _toggleSupplementDateSharing(date, !isShared);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'sharing',
                              child: Row(
                                children: [
                                  Icon(
                                    isShared ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.purple,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(isShared
                                      ? 'Hide day from coach'
                                      : 'Share day with coach'),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: completionRate,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                completionRate == 1.0 ? Colors.green : Colors.orange,
              ),
              minHeight: 4,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: entries.map((entry) => _buildSupplementChip(entry)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Toggle whether all supplements logged on [date] are shared with the coach.
  Future<void> _toggleSupplementDateSharing(String date, bool newShared) async {
    // Optimistically update every entry for that date.
    final previous = <Map<String, dynamic>, dynamic>{};
    setState(() {
      for (final e in _historyData) {
        if (e['date'] == date) {
          previous[e] = e['shared_with_chat'];
          e['shared_with_chat'] = newShared;
        }
      }
    });

    final ok = await _sharingApi.setSupplementSharing(
      userId: widget.userProfile.id!,
      date: DateTime.parse(date),
      shared: newShared,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        previous.forEach((e, val) => e['shared_with_chat'] = val);
      });
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
        content: Text(newShared
            ? 'Supplements shared with coach'
            : 'Supplements hidden from coach'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildSupplementChip(Map<String, dynamic> entry) {
    final supplementName = entry['supplement_name'] as String;
    final taken = entry['taken'] as bool;
    
    return Chip(
      label: Text(
        supplementName,
        style: TextStyle(
          fontSize: 12,
          color: taken ? Colors.white : Colors.grey.shade700,
        ),
      ),
      backgroundColor: taken ? Colors.green : Colors.grey.shade300,
      avatar: Icon(
        taken ? Icons.check : Icons.close,
        size: 16,
        color: taken ? Colors.white : Colors.grey.shade600,
      ),
    );
  }
}