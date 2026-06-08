// lib/features/home/widgets/compact_supplements_tracker.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/tracking/screens/supplements_logging_page.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class CompactSupplementsTracker extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onUpdate;

  const CompactSupplementsTracker({
    Key? key,
    required this.userProfile,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<CompactSupplementsTracker> createState() => _CompactSupplementsTrackerState();
}

class _CompactSupplementsTrackerState extends State<CompactSupplementsTracker> {
  List<Map<String, dynamic>> _supplements = [];
  Map<String, bool> _todaysTaken = {};
  bool _isLoading = true;
  late String _todaysDate;

  @override
  void initState() {
    super.initState();
    _todaysDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadSupplementsData();
  }

  Future<void> _loadSupplementsData() async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userProfile.id!;
      
      // Load supplements list
      final supplementsJson = prefs.getString('supplement_setup_${userId}_list');
      if (supplementsJson != null) {
        final List<dynamic> supplementsList = jsonDecode(supplementsJson);
        _supplements = supplementsList.cast<Map<String, dynamic>>();
      }
      
      // Load today's status
      final statusKey = 'supplement_status_${userId}_$_todaysDate';
      final statusJson = prefs.getString(statusKey);
      if (statusJson != null) {
        final Map<String, dynamic> status = jsonDecode(statusJson);
        _todaysTaken = status.map((key, value) => MapEntry(key, value as bool));
      } else {
        // Initialize with all false
        _todaysTaken = {};
        for (var supplement in _supplements) {
          _todaysTaken[supplement['name']] = false;
        }
      }
    } catch (e) {
      print('Error loading supplements data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToSupplementsLogging() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplementLoggingPage(
          userProfile: widget.userProfile,
        ),
      ),
    ).then((_) {
      _loadSupplementsData();
      widget.onUpdate?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
        ),
      );
    }

    final totalSupplements = _supplements.length;
    final takenCount = _todaysTaken.values.where((taken) => taken).length;
    final progress = totalSupplements > 0 ? takenCount / totalSupplements : 0.0;
    final allTaken = takenCount == totalSupplements && totalSupplements > 0;

    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: _navigateToSupplementsLogging,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.shade400,
                Colors.teal.shade600,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medication,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Supplements',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (allTaken)
                              Text(
                                'All taken ✓',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$takenCount/$totalSupplements',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
                          'Today\'s Progress',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 6,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Quick list of supplements
                if (_supplements.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _supplements.take(3).map((supplement) {
                      final name = supplement['name'] as String;
                      final taken = _todaysTaken[name] ?? false;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: taken
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              taken ? Icons.check_circle : Icons.circle_outlined,
                              size: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              name.length > 10 ? '${name.substring(0, 10)}...' : name,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                
                if (_supplements.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${_supplements.length - 3} more',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Log button
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToSupplementsLogging,
                    icon: const Icon(Icons.checklist, size: 18),
                    label: const Text('Manage Supplements'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
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