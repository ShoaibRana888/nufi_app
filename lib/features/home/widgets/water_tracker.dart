// lib/features/home/widgets/water_tracker.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/repositories/water_repository.dart';

class WaterTracker extends StatefulWidget {
  final UserProfile userProfile;

  const WaterTracker({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<WaterTracker> createState() => _WaterTrackerState();
}

class _WaterTrackerState extends State<WaterTracker> {
  WaterEntry? _todayEntry;
  bool _isLoading = true;
  bool _isSaving = false;

  static const double mlPerGlass = 250.0;
  static const double defaultTarget = 2000.0;

  @override
  void initState() {
    super.initState();
    _loadTodayEntry();
  }

  Future<void> _loadTodayEntry() async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final entry = await WaterRepository.getTodayWaterEntry(widget.userProfile.id!);
      setState(() {
        _todayEntry = entry ?? WaterEntry(
          userId: widget.userProfile.id!,
          date: DateTime.now(),
          glassesConsumed: 0,
          totalMl: 0.0,
          targetMl: defaultTarget,
        );
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading today\'s water entry: $e');
      setState(() {
        _todayEntry = WaterEntry(
          userId: widget.userProfile.id!,
          date: DateTime.now(),
          glassesConsumed: 0,
          totalMl: 0.0,
          targetMl: defaultTarget,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWaterEntry() async {
    if (_todayEntry == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await WaterRepository.saveWaterEntry(_todayEntry!);
    } catch (e) {
      print('Error saving water entry: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addGlass() {
    if (_todayEntry == null) return;
    
    setState(() {
      _todayEntry = _todayEntry!.copyWith(
        glassesConsumed: _todayEntry!.glassesConsumed + 1,
        totalMl: (_todayEntry!.glassesConsumed + 1) * mlPerGlass,
        updatedAt: DateTime.now(),
      );
    });
    
    _saveWaterEntry();
  }

  void _removeGlass() {
    if (_todayEntry == null || _todayEntry!.glassesConsumed <= 0) return;
    
    setState(() {
      _todayEntry = _todayEntry!.copyWith(
        glassesConsumed: _todayEntry!.glassesConsumed - 1,
        totalMl: (_todayEntry!.glassesConsumed - 1) * mlPerGlass,
        updatedAt: DateTime.now(),
      );
    });
    
    _saveWaterEntry();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_todayEntry == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Unable to load water data'),
        ),
      );
    }

    final progress = _todayEntry!.totalMl / _todayEntry!.targetMl;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Water Intake',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Progress bar
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.blue.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : Colors.blue,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_todayEntry!.glassesConsumed} glasses',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_todayEntry!.totalMl.toInt()}ml / ${_todayEntry!.targetMl.toInt()}ml',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _todayEntry!.glassesConsumed > 0 ? _removeGlass : null,
                    icon: const Icon(Icons.remove),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.18),
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _addGlass,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isSaving ? 'Saving...' : 'Add Glass'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.18),
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}