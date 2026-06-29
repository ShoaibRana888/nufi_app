// lib/features/tracking/screens/water_logging_page.dart

// lib/features/tracking/screens/water_logging_page.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/repositories/water_repository.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:user_onboarding/features/tracking/screens/water_history_page.dart';
import 'package:intl/intl.dart';


class WaterLoggingPage extends StatefulWidget {
  final UserProfile userProfile;

  const WaterLoggingPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<WaterLoggingPage> createState() => _WaterLoggingPageState();
}

class _WaterLoggingPageState extends State<WaterLoggingPage> {
  WaterEntry? _todayEntry;
  bool _isLoading = true;
  bool _isSaving = false;
  int _dailyGoal = 8; 
  DateTime _selectedDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _showCalendar = false;

  // Constants for calculations
  static const double mlPerGlass = 250.0; // 250ml per glass
  static const double defaultTarget = 2000.0; // 2L default target

  @override
  void initState() {
    super.initState();
    _dailyGoal = widget.userProfile.waterIntakeGlasses ?? 8;
    _loadWaterForDate(_selectedDate);
  }

  Future<void> _loadWaterForDate(DateTime date) async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final entry = await WaterRepository.getWaterEntryByDate(
        widget.userProfile.id!, 
        date
      );
      
      setState(() {
        _selectedDate = date;
        _todayEntry = entry ?? WaterEntry(
          userId: widget.userProfile.id!,
          date: date,
          glassesConsumed: 0,
          totalMl: 0.0,
          targetMl: defaultTarget,
        );
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading water data for date: $e');
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to load water data: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadWaterForDate(date),
            ),
          ),
        );
      }
      
      // Initialize with empty entry on error
      setState(() {
        _selectedDate = date;
        _todayEntry = WaterEntry(
          userId: widget.userProfile.id!,
          date: date,
          glassesConsumed: 0,
          totalMl: 0.0,
          targetMl: defaultTarget,
        );
      });
    }
  }

  Future<void> _saveWaterEntry() async {
    if (_todayEntry == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await WaterRepository.saveWaterEntry(_todayEntry!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Water intake saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error saving water entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _addGlasses(int count) async {
    if (_todayEntry == null || _isSaving) return;
    
    setState(() {
      _todayEntry = _todayEntry!.copyWith(
        glassesConsumed: _todayEntry!.glassesConsumed + count,
        totalMl: (_todayEntry!.glassesConsumed + count) * mlPerGlass,
        updatedAt: DateTime.now(),
      );
    });
    
    await _saveWaterEntry();
  }

  void _addGlass() => _addGlasses(1);

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

  void _fillRemaining() {
    if (_todayEntry == null) return;
    
    final remaining = _dailyGoal - _todayEntry!.glassesConsumed;
    if (remaining > 0) {
      _addGlasses(remaining);
    }
  }

  void _showCustomAmountDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Enter Custom Amount'),
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
                _addGlasses(count);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _resetDaily() {
    if (_todayEntry == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Reset Daily Water'),
        content: const Text('Are you sure you want to reset today\'s water intake to 0?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _todayEntry = _todayEntry!.copyWith(
                  glassesConsumed: 0,
                  totalMl: 0.0,
                  updatedAt: DateTime.now(),
                );
              });
              _saveWaterEntry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_showCalendar 
            ? 'Select Date' 
            : 'Water Tracking - ${DateFormat('MMM d').format(_selectedDate)}'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_showCalendar ? Icons.close : Icons.calendar_month),
              onPressed: () {
                setState(() {
                  _showCalendar = !_showCalendar;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WaterHistoryPage(userProfile: widget.userProfile),
                  ),
                );
              },
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _loadWaterForDate(_selectedDate),
          child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Calendar (collapsible)
                    if (_showCalendar) _buildCalendar(),
                    
                    // Date indicator if not today
                    if (!DateUtils.isSameDay(_selectedDate, DateTime.now()))
                      _buildDateIndicator(),
                    
                    // Existing widgets
                    _buildWaterProgress(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildWaterControls(),
                    const SizedBox(height: 20),
                    _buildWaterTips(),
                  ],
                ),
              ),
        ),
      );
    }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now(),
        focusedDay: _selectedDate,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDate = selectedDay;
            _showCalendar = false;
          });
          _loadWaterForDate(selectedDay);
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildDateIndicator() {
    if (DateUtils.isSameDay(_selectedDate, DateTime.now())) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            'Viewing water intake for ${DateFormat('EEEE, MMM d').format(_selectedDate)}',
            style: const TextStyle(color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterProgress() {
    if (_todayEntry == null) return const SizedBox.shrink();
    
    final progress = _todayEntry!.totalMl / _todayEntry!.targetMl;
    final progressClamped = progress.clamp(0.0, 1.0);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Circular Progress
            SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      height: 180,
                      width: 180,
                      child: CircularProgressIndicator(
                        value: progressClamped,
                        strokeWidth: 12,
                        backgroundColor: Colors.blue.withValues(alpha: 0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 1.0 ? Colors.green : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.water_drop,
                          size: 40,
                          color: progress >= 1.0 ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_todayEntry!.glassesConsumed}',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: progress >= 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                        const Text(
                          'glasses',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Progress Text
            Text(
              '${_todayEntry!.totalMl.toInt()}ml / ${_todayEntry!.targetMl.toInt()}ml',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '${(progress * 100).toInt()}% of daily goal',
              style: TextStyle(
                fontSize: 14,
                color: progress >= 1.0 ? Colors.green : Colors.grey[600],
                fontWeight: progress >= 1.0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            
            if (progress >= 1.0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  const Text(
                    'Goal achieved! 🎉',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final remaining = _dailyGoal - (_todayEntry?.glassesConsumed ?? 0);
    final isGoalReached = remaining <= 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Add',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Quick add buttons grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAddButton(
                  label: '+2',
                  subtitle: 'glasses',
                  onTap: () => _addGlasses(2),
                  color: Colors.blue,
                ),
                _QuickAddButton(
                  label: '+3',
                  subtitle: 'glasses',
                  onTap: () => _addGlasses(3),
                  color: Colors.blue,
                ),
                _QuickAddButton(
                  label: '+4',
                  subtitle: 'glasses',
                  onTap: () => _addGlasses(4),
                  color: Colors.blue,
                ),
                _QuickAddButton(
                  label: '+5',
                  subtitle: 'glasses',
                  onTap: () => _addGlasses(5),
                  color: Colors.blue,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Fill remaining or achievement banner
            if (!isGoalReached) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _fillRemaining,
                  icon: const Icon(Icons.water_drop),
                  label: Text('Fill remaining ($remaining glasses)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
            
            // Custom amount button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _showCustomAmountDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Custom amount'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                // Remove Glass Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _todayEntry?.glassesConsumed != null && _todayEntry!.glassesConsumed > 0 
                        ? _removeGlass 
                        : null,
                    icon: const Icon(Icons.remove),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Add Glass Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _addGlass,
                    icon: _isSaving 
                        ? const SizedBox(
                            width: 16, 
                            height: 16, 
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isSaving ? 'Saving...' : 'Add Glass'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Reset Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetDaily,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
  
  Widget _buildWaterTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'Hydration Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('• Drink a glass of water when you wake up', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            const Text('• Set reminders every 2 hours', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            const Text('• Eat water-rich foods like fruits and vegetables', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            const Text('• Monitor urine color for hydration levels', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            const Text('• Drink more during exercise and hot weather', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// Quick Add Button Widget
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
            width: 1.5,
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
            const SizedBox(height: 2),
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