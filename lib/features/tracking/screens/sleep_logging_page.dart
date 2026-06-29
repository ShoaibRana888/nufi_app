// lib/features/tracking/screens/sleep_logging_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/models/sleep_entry.dart';
import 'package:user_onboarding/data/repositories/sleep_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/features/tracking/screens/sleep_history_page.dart';

class SleepLoggingPage extends StatefulWidget {
  final UserProfile userProfile;

  const SleepLoggingPage({Key? key, required this.userProfile}) : super(key: key);

  @override
  _SleepLoggingPageState createState() => _SleepLoggingPageState();
}

class _SleepLoggingPageState extends State<SleepLoggingPage> {
  final SleepRepository _sleepRepository = SleepRepository();
  final TextEditingController _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _bedtime;
  TimeOfDay? _wakeTime;
  double _qualityScore = 0.7;
  bool _isLoading = false;
  List<String> _sleepIssues = [];
  double _targetHours = 8.0;
  
  SleepEntry? _existingEntry;
  bool _hasEntryForToday = false;

  @override
  void initState() {
    super.initState();
    _targetHours = widget.userProfile.sleepHours ?? 8.0;
    _initializeFromUserProfile();
    _loadExistingEntry();
  }

  void _initializeFromUserProfile() {
    // Set defaults from user's onboarding data
    _bedtime = _parseTimeString(widget.userProfile.bedtime);
    _wakeTime = _parseTimeString(widget.userProfile.wakeupTime);
    _sleepIssues = List.from(widget.userProfile.sleepIssues);
    
    print('🛏️ Initialized with user defaults:');
    print('  Bedtime: ${widget.userProfile.bedtime} -> $_bedtime');
    print('  Wake time: ${widget.userProfile.wakeupTime} -> $_wakeTime');
    print('  Sleep hours: ${widget.userProfile.sleepHours}');
    print('  Sleep issues: ${widget.userProfile.sleepIssues}');
  }

  Future<void> _loadExistingEntry() async {
    setState(() => _isLoading = true);
    try {
      final entry = await _sleepRepository.getSleepEntryByDate(
        widget.userProfile.id,
        _selectedDate
      );
      if (entry != null) {
        print('📥 Raw entry data:');
        print('  Bedtime DateTime: ${entry.bedtime}');
        print('  WakeTime DateTime: ${entry.wakeTime}');
        
        setState(() {
          _existingEntry = entry;
          _hasEntryForToday = true;
          
          // Parse times with better debugging
          _bedtime = _parseTimeOfDay(entry.bedtime);
          _wakeTime = _parseTimeOfDay(entry.wakeTime);
          
          print('  Parsed Bedtime TimeOfDay: $_bedtime');
          print('  Parsed WakeTime TimeOfDay: $_wakeTime');
          
          _qualityScore = entry.qualityScore;
          _sleepIssues = List.from(entry.sleepIssues);
          _notesController.text = entry.notes ?? '';
        });

        print('✅ Loaded existing entry for ${_selectedDate.toIso8601String().split('T')[0]}');
        print('  Total hours in entry: ${entry.totalHours}');
        print('  Calculated total hours: ${_calculateTotalHours()}');
      } else {
        print('📝 No existing entry for ${_selectedDate.toIso8601String().split('T')[0]}');
        setState(() {
          _hasEntryForToday = false;
          _existingEntry = null;
          // Use profile defaults only when there's no existing entry
          _initializeFromUserProfile();
        });
      }
    } catch (e) {
      print('Error loading existing entry: $e');
      // Continue with defaults if loading fails
      setState(() {
        _hasEntryForToday = false;
        _existingEntry = null;
      });
    }
    setState(() => _isLoading = false);
  }

  TimeOfDay? _parseTimeString(String? timeString) {
    if (timeString == null || timeString.isEmpty) return null;
    
    try {
      // Handle various time formats from onboarding
      String cleanTime = timeString.trim();
      
      // Remove seconds if present
      if (cleanTime.split(':').length == 3) {
        cleanTime = cleanTime.substring(0, cleanTime.lastIndexOf(':'));
      }
      
      // Handle AM/PM format
      if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
        final parts = cleanTime.split(' ');
        final timePart = parts[0];
        final period = parts[1].toUpperCase();
        
        final timeParts = timePart.split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        if (period == 'PM' && hour != 12) {
          hour += 12;
        } else if (period == 'AM' && hour == 12) {
          hour = 0;
        }
        
        return TimeOfDay(hour: hour, minute: minute);
      } else {
        // Handle 24-hour format
        final parts = cleanTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('Error parsing time string "$timeString": $e');
      return null;
    }
  }

  TimeOfDay? _parseTimeOfDay(DateTime? dateTime) {
    if (dateTime == null) return null;
    return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }

  double _calculateTotalHours() {
    // Always recompute from the selected times when both are present, so
    // editing bedtime/wake on an existing entry updates the total. Fall back to
    // the stored total (when editing) or the profile default only if a time is
    // missing.
    if (_bedtime == null || _wakeTime == null) {
      return _existingEntry?.totalHours ?? widget.userProfile.sleepHours;
    }

    DateTime bedDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _bedtime!.hour,
      _bedtime!.minute,
    );
    
    DateTime wakeDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day + (_wakeTime!.hour < _bedtime!.hour ? 1 : 0),
      _wakeTime!.hour,
      _wakeTime!.minute,
    );
    
    return wakeDateTime.difference(bedDateTime).inMinutes / 60.0;
  }

  // Estimate deep sleep based on research (typically 13-23% of total sleep)
  double _estimateDeepSleep() {
    final totalHours = _calculateTotalHours();
    return totalHours * 0.18; // Use 18% as a conservative estimate
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Tracking'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SleepHistoryPage(userProfile: widget.userProfile),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await _refreshData();
          } catch (e) {
            print('Error refreshing: $e');
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : (_hasEntryForToday && _isToday(_selectedDate)
                    ? _buildAlreadyLoggedView()
                    : _buildLoggingForm()),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  Widget _buildAlreadyLoggedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              "Today's Sleep Logged!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You logged ${_calculateTotalHours().toStringAsFixed(1)} hours of sleep',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Quality: ${(_qualityScore * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 16,
                color: _getQualityColor(_qualityScore),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Check back tomorrow to log your next sleep entry',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SleepHistoryPage(userProfile: widget.userProfile),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('View History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasEntryForToday = false;
                    });
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Entry'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  _loadExistingEntry();
                });
              },
              child: const Text('Log Previous Day'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggingForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: 20),
          if (_existingEntry != null)
            _buildEditingNotice(),
          _buildDefaultsInfo(),
          const SizedBox(height: 20),
          _buildTimeInputs(),
          const SizedBox(height: 20),
          _buildQualitySlider(),
          const SizedBox(height: 20),
          _buildSleepIssuesSection(),
          const SizedBox(height: 20),
          _buildNotesSection(),
          const SizedBox(height: 20),
          _buildSleepSummary(),
          const SizedBox(height: 30),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildEditingNotice() {
    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.edit, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Editing existing entry for ${DateFormat('MMM dd').format(_selectedDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultsInfo() {
    return Card(
      color: Colors.blue.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Using your profile defaults. Feel free to adjust for today.',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveSleepEntry,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          _existingEntry != null ? 'Update Sleep Entry' : 'Save Sleep Entry',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.purple),
        title: const Text('Sleep Date'),
        subtitle: Text(DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate)),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              _selectedDate = picked;
              _existingEntry = null;
            });
            _loadExistingEntry();
          }
        },
      ),
    );
  }

  Widget _buildTimeInputs() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sleep Times',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_existingEntry == null)
                      Text(
                        'From your profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Bedtime', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _selectBedtime,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.withValues(alpha: 0.18)),
                            child: Text(
                              _bedtime?.format(context) ?? 'Select',
                              style: const TextStyle(color: Colors.purple),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Wake Time', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _selectWakeTime,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.withValues(alpha: 0.18)),
                            child: Text(
                              _wakeTime?.format(context) ?? 'Select',
                              style: const TextStyle(color: Colors.purple),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualitySlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How did you sleep?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _getQualityLabel(_qualityScore),
              style: TextStyle(
                color: _getQualityColor(_qualityScore),
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _qualityScore,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              activeColor: Colors.purple,
              onChanged: (value) {
                setState(() {
                  _qualityScore = value;
                });
              },
            ),
            Text(
              'Rate your sleep quality from very poor to excellent',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepIssuesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Issues (if any)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_sleepIssues.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _sleepIssues.map((issue) => Chip(
                  label: Text(issue),
                  backgroundColor: Colors.orange.withValues(alpha: 0.18),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _sleepIssues.remove(issue);
                    });
                  },
                )).toList(),
              )
            else
              Text(
                'No sleep issues reported',
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _addSleepIssue,
              icon: const Icon(Icons.add),
              label: const Text('Add sleep issue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes (optional)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any additional notes about your sleep...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepSummary() {
    final totalHours = _calculateTotalHours();
    final estimatedDeepSleep = _estimateDeepSleep();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow('Total Sleep', '${totalHours.toStringAsFixed(1)} hours'),
            _buildSummaryRow('Quality', _getQualityLabel(_qualityScore)),
            _buildSummaryRow('Est. Deep Sleep*', '${estimatedDeepSleep.toStringAsFixed(1)} hours'),
            if (_sleepIssues.isNotEmpty)
              _buildSummaryRow('Issues', '${_sleepIssues.length} reported'),
            const SizedBox(height: 8),
            Text(
              '*Deep sleep is estimated based on total sleep duration',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _selectBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bedtime ?? const TimeOfDay(hour: 22, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _bedtime = picked;
      });
    }
  }

  Future<void> _selectWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _wakeTime = picked;
      });
    }
  }

  void _addSleepIssue() {
    final commonIssues = [
      'Trouble falling asleep',
      'Woke up frequently',
      'Woke up too early',
      'Restless sleep',
      'Nightmares',
      'Sleep talking',
      'Snoring',
      'Too hot/cold',
      'Noise disturbance',
      'Light disturbance',
      'Stress/anxiety',
      'Physical discomfort',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Sleep Issue'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Common issues:'),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: commonIssues.length,
                    itemBuilder: (context, index) {
                      final issue = commonIssues[index];
                      return ListTile(
                        title: Text(issue),
                        onTap: () {
                          if (!_sleepIssues.contains(issue)) {
                            setState(() {
                              _sleepIssues.add(issue);
                            });
                          }
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveSleepEntry() async {
    if (_bedtime == null || _wakeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both bedtime and wake time')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final bedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _bedtime!.hour,
        _bedtime!.minute,
      );
      
      final wakeDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + (_wakeTime!.hour < _bedtime!.hour ? 1 : 0),
        _wakeTime!.hour,
        _wakeTime!.minute,
      );

      final sleepEntry = SleepEntry(
        id: _existingEntry?.id,
        userId: widget.userProfile.id,
        date: _selectedDate,
        bedtime: bedDateTime,
        wakeTime: wakeDateTime,
        totalHours: _calculateTotalHours(),
        qualityScore: _qualityScore,
        deepSleepHours: _estimateDeepSleep(),
        sleepIssues: _sleepIssues,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: _existingEntry?.createdAt ?? DateTime.now(),
      );

      if (_existingEntry != null) {
        await _sleepRepository.updateSleepEntry(sleepEntry);
      } else {
        await _sleepRepository.createSleepEntry(sleepEntry);
      }

      // Save to SharedPreferences for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final totalHours = _calculateTotalHours();
      
      await prefs.setBool('sleep_logged_$dateStr', true);
      await prefs.setDouble('sleep_hours_$dateStr', totalHours);
      await prefs.setDouble('sleep_quality_$dateStr', _qualityScore);
      await prefs.setString('sleep_bedtime_$dateStr', bedDateTime.toIso8601String());
      await prefs.setString('sleep_waketime_$dateStr', wakeDateTime.toIso8601String());
      
      // Save sleep issues as a joined string
      if (_sleepIssues.isNotEmpty) {
        await prefs.setString('sleep_issues_$dateStr', _sleepIssues.join(','));
      }
      
      // Save notes if present
      if (_notesController.text.isNotEmpty) {
        await prefs.setString('sleep_notes_$dateStr', _notesController.text);
      }
      
      print('✅ Sleep saved to SharedPreferences: $dateStr = ${totalHours}h');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep entry ${_existingEntry != null ? 'updated' : 'saved'} successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadExistingEntry(); // Reload to get updated data

    } catch (e) {
      print('❌ Error saving sleep entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving sleep entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  String _getQualityLabel(double score) {
    if (score >= 0.9) return 'Excellent';
    if (score >= 0.7) return 'Good';
    if (score >= 0.5) return 'Fair';
    if (score >= 0.3) return 'Poor';
    return 'Very Poor';
  }

  Color _getQualityColor(double score) {
    if (score >= 0.9) return Colors.green;
    if (score >= 0.7) return Colors.lightGreen;
    if (score >= 0.5) return Colors.orange;
    if (score >= 0.3) return Colors.deepOrange;
    return Colors.red;
  }

  Future<void> _refreshData() async {
    await _loadExistingEntry();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}