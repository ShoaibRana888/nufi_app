// lib/features/tracking/screens/steps_logging_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:user_onboarding/data/repositories/step_repository.dart';
import 'package:user_onboarding/features/home/widgets/daily_step_tracker.dart';
import 'package:user_onboarding/features/tracking/screens/step_history_page.dart';
import 'package:user_onboarding/data/services/api/auth_api.dart';

class StepsLoggingPage extends StatefulWidget {
  final UserProfile userProfile;

  const StepsLoggingPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  State<StepsLoggingPage> createState() => _StepsLoggingPageState();
}

class _StepsLoggingPageState extends State<StepsLoggingPage> {
  StepEntry? _todayEntry;
  List<StepEntry> _weeklyHistory = [];
  bool _isLoading = true;
  int _userStepGoal = 10000;
  
  final TextEditingController _manualStepsController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _userStepGoal = (widget.userProfile.formData['dailyStepGoal'] as int?) ?? 10000;
    _checkAndShowGoalModal();
  }

  @override
  void dispose() {
    _manualStepsController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowGoalModal() async {
    // Load step data first
    await _loadStepDataForDate(_selectedDate);
    
    final prefs = await SharedPreferences.getInstance();
    final hasSetStepGoal = prefs.getBool('has_set_step_goal_${widget.userProfile.id}') ?? false;
    
    // ✅ Check if user already has a step goal in their profile (existing users)
    final hasStepGoalInProfile = widget.userProfile.dailyStepGoal != null && 
                                  widget.userProfile.dailyStepGoal > 0;
    
    // If user has step goal in profile but flag not set, set it now (for existing users)
    if (hasStepGoalInProfile && !hasSetStepGoal) {
      await prefs.setBool('has_set_step_goal_${widget.userProfile.id}', true);
      return; // Don't show modal
    }
    
    // Show modal only if:
    // 1. User hasn't set goal before
    // 2. No step goal in profile
    if (!hasSetStepGoal && !hasStepGoalInProfile && mounted) {
      await _showStepGoalSetupModal();
    }
  }

  Future<void> _showStepGoalSetupModal() async {
    final currentGoal = (widget.userProfile.formData['dailyStepGoal'] as int?) ?? 
                      _todayEntry?.goal ?? 
                      10000;
    
    final TextEditingController goalSetupController = TextEditingController(
      text: currentGoal.toString()
    );
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          // ... (your existing AlertDialog code)
          actions: [
            TextButton(
              onPressed: () async {
                final goal = int.tryParse(goalSetupController.text) ?? 10000;
                
                setState(() {
                  _userStepGoal = goal;
                });
                
                try {
                  final apiService = AuthApi();
                  
                  // ✅ Update both dailyStepGoal field AND formData
                  final updatedFormData = Map<String, dynamic>.from(widget.userProfile.formData);
                  updatedFormData['dailyStepGoal'] = goal;
                  
                  final updatedProfile = widget.userProfile.copyWith(
                    dailyStepGoal: goal,  // ✅ Update the actual field
                    formData: updatedFormData,
                  );
                  
                  // Update user profile via API
                  await apiService.updateUserProfile(updatedProfile);
                  
                  // If today's entry exists, update it with the new goal
                  if (_todayEntry != null) {
                    final updatedEntry = _todayEntry!.copyWith(goal: goal);
                    await StepRepository.saveStepEntry(updatedEntry);
                    setState(() {
                      _todayEntry = updatedEntry;
                    });
                  }
                  
                  // Mark as set in SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_set_step_goal_${widget.userProfile.id}', true);
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Step goal saved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error saving step goal: $e');
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save goal: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Set Goal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadStepDataForDate(DateTime date) async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final entry = await StepRepository.getStepEntryByDate(
        widget.userProfile.id!,
        date,
      );
      
      final stepGoal = widget.userProfile.dailyStepGoal ?? 
                      (widget.userProfile.formData['dailyStepGoal'] as int?) ?? 
                      10000;
      
      StepEntry loadedEntry;
      if (entry != null) {
        // Recalculate metrics if they're 0 or missing
        if (entry.steps > 0 && (entry.caloriesBurned == 0 || entry.distanceKm == 0)) {
          loadedEntry = entry.copyWith(
            caloriesBurned: _calculateCalories(entry.steps),
            distanceKm: _calculateDistance(entry.steps),
            activeMinutes: _calculateActiveMinutes(entry.steps),
          );
        } else {
          loadedEntry = entry;
        }
      } else {
        loadedEntry = StepEntry(
          userId: widget.userProfile.id!,
          date: date,
          steps: 0,
          goal: stepGoal,
        );
      }
      
      setState(() {
        _selectedDate = date;
        _todayEntry = loadedEntry;
        _isLoading = false;
      });
      
      // Load weekly history as well
      await _loadWeeklyHistory();
      
    } catch (e) {
      print('Error loading step data for date: $e');
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to load step data: ${e.toString()}'),
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
              onPressed: () => _loadStepDataForDate(date),
            ),
          ),
        );
      }
      
      // Initialize with empty entry on error
      final stepGoal = widget.userProfile.dailyStepGoal ?? 
                      (widget.userProfile.formData['dailyStepGoal'] as int?) ?? 
                      10000;
      
      setState(() {
        _selectedDate = date;
        _todayEntry = StepEntry(
          userId: widget.userProfile.id!,
          date: date,
          steps: 0,
          goal: stepGoal,
        );
      });
    }
  }

  Future<void> _loadWeeklyHistory() async {
    if (widget.userProfile.id == null) return;
    
    try {
      final now = DateTime.now();
      final List<StepEntry> history = [];
      
      // Load last 7 days of data
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final entry = await StepRepository.getStepEntryByDate(
          widget.userProfile.id!,
          date,
        );
        
        if (entry != null) {
          // Recalculate metrics if missing
          if (entry.steps > 0 && (entry.caloriesBurned == 0 || entry.distanceKm == 0)) {
            history.add(entry.copyWith(
              caloriesBurned: _calculateCalories(entry.steps),
              distanceKm: _calculateDistance(entry.steps),
              activeMinutes: _calculateActiveMinutes(entry.steps),
            ));
          } else {
            history.add(entry);
          }
        }
      }
      
      setState(() {
        _weeklyHistory = history;
      });
    } catch (e) {
      print('Error loading weekly history: $e');
    }
  }

  Future<void> _saveManualEntry() async {
    if (_todayEntry == null) return;

    final steps = int.tryParse(_manualStepsController.text);

    if (steps == null || steps < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid step count'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final updatedEntry = _todayEntry!.copyWith(
        steps: steps,
        // Keep the existing goal, don't change it
        caloriesBurned: _calculateCalories(steps),
        distanceKm: _calculateDistance(steps),
        activeMinutes: _calculateActiveMinutes(steps),
        sourceType: 'manual',
        lastSynced: DateTime.now(),
      );

      await StepRepository.saveStepEntry(updatedEntry);
      
      setState(() {
        _todayEntry = updatedEntry;
      });

      _manualStepsController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Steps saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _calculateCalories(int steps) {
    // Rough estimation: 0.04 calories per step (varies by weight)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showCalendar 
          ? 'Select Date' 
          : 'Steps - ${DateFormat('MMM d').format(_selectedDate)}'),
        backgroundColor: Colors.green.shade700,
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
                  builder: (context) => StepHistoryPage(userProfile: widget.userProfile),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar (collapsible)
          if (_showCalendar) _buildCalendar(),
          
          // Date indicator if not today
          if (!DateUtils.isSameDay(_selectedDate, DateTime.now()))
            _buildDateIndicator(),
          
          // Main content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepTracker(),
                        const SizedBox(height: 16),
                        _buildManualEntry(),
                        const SizedBox(height: 16),
                        _buildQuickStats(),
                        const SizedBox(height: 16),
                        _buildWeeklyOverview(),
                        const SizedBox(height: 16),
                        _buildStepTips(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTracker() {
    if (_todayEntry == null) return const SizedBox();

    // Dynamically set the title based on selected date
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final title = isToday ? 'Today\'s Progress' : '${DateFormat('MMM d').format(_selectedDate)} Progress';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        DailyStepTracker(
          stepGoal: _todayEntry!.goal,
          stepsWalked: _todayEntry!.steps,
        ),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Log Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _manualStepsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps',
                hintText: 'Enter step count',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_walk),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saveManualEntry,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Steps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (DateUtils.isSameDay(_selectedDate, DateTime.now())) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showResetDialog,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
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
          _loadStepDataForDate(selectedDay);
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.green.shade300.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green.shade700,
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
      color: Colors.green.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            'Viewing steps for ${DateFormat('EEEE, MMM d').format(_selectedDate)}',
            style: TextStyle(color: Colors.green.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_weeklyHistory.isEmpty)
              const Center(
                child: Text(
                  'No data available for this week',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              _buildWeeklyChart(),
            const SizedBox(height: 16),
            _buildWeeklyStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final maxSteps = _weeklyHistory.isNotEmpty 
        ? _weeklyHistory.map((e) => e.steps).reduce((a, b) => a > b ? a : b)
        : 10000;
    
    return Container(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final date = DateTime.now().subtract(Duration(days: 6 - index));
          final entry = _weeklyHistory.firstWhere(
            (e) => DateUtils.isSameDay(e.date, date),
            orElse: () => StepEntry(
              userId: widget.userProfile.id!,
              date: date,
              steps: 0,
              goal: 10000,
            ),
          );
          
          final heightPercent = maxSteps > 0 ? (entry.steps / maxSteps) : 0.0;
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          final isMaxDay = entry.steps == maxSteps && maxSteps > 0;
          
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                entry.steps.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isMaxDay ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 25,
                height: 80 * heightPercent.clamp(0.1, 1.0),
                decoration: BoxDecoration(
                  color: entry.steps >= entry.goal
                      ? (isMaxDay ? Colors.green.shade700 : Colors.green.shade400)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                  border: isToday 
                      ? Border.all(color: Colors.green.shade700, width: 2.5)
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('E').format(date),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isMaxDay ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? Colors.green.shade700 : Colors.grey,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWeeklyStats() {
    if (_weeklyHistory.isEmpty) return const SizedBox();
    
    final totalSteps = _weeklyHistory.fold(0, (sum, entry) => sum + entry.steps);
    final avgSteps = (totalSteps / 7).round();
    final bestDay = _weeklyHistory.reduce((a, b) => a.steps > b.steps ? a : b);
    final goalsAchieved = _weeklyHistory.where((e) => e.steps >= e.goal).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatColumn('Total', totalSteps.toString()),
        _buildStatColumn('Average', avgSteps.toString()),
        _buildStatColumn('Best Day', bestDay.steps.toString()),
        _buildStatColumn('Goals Hit', '$goalsAchieved/7'),
      ],
    );
  }

  Widget _buildQuickStats() {
    if (_todayEntry == null) return const SizedBox();

    // Dynamically set the title based on selected date
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final title = isToday ? 'Today\'s Details' : '${DateFormat('MMM d').format(_selectedDate)} Details';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDetailColumn(
                  'Calories',
                  '${_todayEntry!.caloriesBurned.toStringAsFixed(0)}',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildDetailColumn(
                  'Distance',
                  '${_todayEntry!.distanceKm.toStringAsFixed(2)} km',
                  Icons.straighten,
                  Colors.blue,
                ),
                _buildDetailColumn(
                  'Active Min',
                  '${_todayEntry!.activeMinutes}',
                  Icons.timer,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepTips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Step Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• Take the stairs instead of the elevator\n'
              '• Park farther away from your destination\n'
              '• Take walking breaks during work\n'
              '• Walk while talking on the phone\n'
              '• Set reminders to move every hour',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
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

  Widget _buildDetailColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
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

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Today\'s Steps'),
        content: const Text('Are you sure you want to reset today\'s step count to 0?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_todayEntry != null) {
                final resetEntry = _todayEntry!.copyWith(
                  steps: 0,
                  caloriesBurned: 0.0,
                  distanceKm: 0.0,
                  activeMinutes: 0,
                );
                await StepRepository.saveStepEntry(resetEntry);
                setState(() => _todayEntry = resetEntry);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Steps reset to 0')),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}