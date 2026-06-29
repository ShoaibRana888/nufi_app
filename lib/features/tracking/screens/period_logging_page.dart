import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/period_entry.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/repositories/period_repository.dart';
import 'package:user_onboarding/data/managers/user_manager.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';

class PeriodCalendarPage extends StatefulWidget {
  const PeriodCalendarPage({Key? key}) : super(key: key);

  @override
  State<PeriodCalendarPage> createState() => _PeriodCalendarPageState();
}

class _PeriodCalendarPageState extends State<PeriodCalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  
  final SharingApi _sharingApi = SharingApi();
  UserProfile? _userProfile;
  List<PeriodEntry> _periodHistory = [];
  PeriodEntry? _currentPeriod;
  bool _isLoading = true;
  
  
  Map<DateTime, List<String>> _events = {};
  Set<DateTime> _periodDays = {};
  Set<DateTime> _fertileDays = {};
  Set<DateTime> _ovulationDays = {};
  
  // UI State
  final List<String> _flowOptions = ['Light', 'Medium', 'Heavy', 'Spotting'];
  String _selectedFlow = 'Medium';
  List<String> _selectedSymptoms = [];
  String? _selectedMood;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await UserManager.getCurrentUser();
      if (user != null && user.id != null) {
        final periods = await PeriodRepository.getPeriodHistory(user.id!, limit: 24);
        final currentPeriod = await PeriodRepository.getCurrentPeriod(user.id!);
        
        setState(() {
          _userProfile = user;
          _periodHistory = periods;
          _currentPeriod = currentPeriod;
          _calculatePeriodDays();
          _calculateFertileDays();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading period data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePeriodSharing(PeriodEntry entry) async {
    if (entry.id == null || _userProfile?.id == null) return;
    final newShared = !entry.sharedWithChat;

    final ok = await _sharingApi.setEntrySharing(
      userId: _userProfile!.id!,
      activityType: 'period',
      itemId: entry.id!,
      shared: newShared,
    );

    if (!mounted) return;
    if (ok) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newShared ? 'Period shared with coach' : 'Period hidden from coach'),
          backgroundColor: Colors.purple,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update sharing. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _calculatePeriodDays() {
    _periodDays.clear();
    _events.clear();
    
    for (var period in _periodHistory) {
      // Normalize the dates to avoid time issues
      final startDate = DateTime(
        period.startDate.year, 
        period.startDate.month, 
        period.startDate.day
      );
      
      // If period has ended, use that date; otherwise use today
      final endDate = period.endDate != null 
          ? DateTime(
              period.endDate!.year,
              period.endDate!.month, 
              period.endDate!.day
            )
          : DateTime.now();
      
      // Add each day of the period
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final day = startDate.add(Duration(days: i));
        _periodDays.add(day);
        _events[day] = ['Period'];
      }
    }
    
    print('Period days calculated: ${_periodDays.length} days marked');
  }

  void _calculateFertileDays() {
    if (_userProfile == null) return;
    
    final cycleLength = _userProfile!.cycleLength ?? 28;
    _fertileDays.clear();
    _ovulationDays.clear();
    
    for (var period in _periodHistory) {
      final ovulationDay = period.startDate.add(Duration(days: cycleLength - 14));
      final normalizedOvulation = DateTime(ovulationDay.year, ovulationDay.month, ovulationDay.day);
      _ovulationDays.add(normalizedOvulation);
      
      // Fertile window is 5 days before and 1 day after ovulation
      for (int i = -5; i <= 1; i++) {
        final fertileDay = ovulationDay.add(Duration(days: i));
        final normalizedDay = DateTime(fertileDay.year, fertileDay.month, fertileDay.day);
        _fertileDays.add(normalizedDay);
        
        if (!_periodDays.contains(normalizedDay)) {
          _events[normalizedDay] = (_events[normalizedDay] ?? [])..add('Fertile');
        }
      }
    }
  }

  // Validation methods
  bool _canStartPeriodOnDate(DateTime date) {
    if (_periodHistory.isEmpty) {
      // First period - allow any date within reasonable past
      final monthsAgo = DateTime.now().subtract(const Duration(days: 365));
      return date.isAfter(monthsAgo) && !date.isAfter(DateTime.now());
    }

    final cycleLength = _userProfile?.cycleLength ?? 28;
    final minCycleLength = cycleLength - 7; // Allow 7 days variance
    final maxCycleLength = cycleLength + 7;

    // Find the most recent period before this date
    PeriodEntry? previousPeriod;
    for (var period in _periodHistory) {
      if (period.startDate.isBefore(date)) {
        previousPeriod = period;
        break;
      }
    }

    if (previousPeriod == null) {
      // This would be the earliest period
      // Check if it's not too close to the next period
      final nextPeriod = _periodHistory.last;
      final daysBetween = nextPeriod.startDate.difference(date).inDays;
      
      if (daysBetween < minCycleLength) {
        return false; // Too close to next period
      }
      return true;
    }

    // Check if date is within valid cycle range from previous period
    final daysSincePrevious = date.difference(previousPeriod.startDate).inDays;
    
    // Can't start a new period if previous one hasn't ended
    if (previousPeriod.endDate == null) {
      return false;
    }

    // Check if it's been at least minimum cycle length
    if (daysSincePrevious < minCycleLength) {
      return false;
    }

    // Check if there's already a period that would be too close
    for (var period in _periodHistory) {
      if (period != previousPeriod) {
        final daysDiff = (period.startDate.difference(date).inDays).abs();
        if (daysDiff < minCycleLength && daysDiff > 0) {
          return false; // Too close to another period
        }
      }
    }

    return true;
  }

  String? _getStartPeriodValidationError(DateTime date) {
    if (!_canStartPeriodOnDate(date)) {
      final cycleLength = _userProfile?.cycleLength ?? 28;
      final minCycleLength = cycleLength - 7;

      // Find why it's invalid
      if (_currentPeriod != null && _currentPeriod!.endDate == null) {
        return 'Please end your current period first';
      }

      // Check for too close to other periods
      for (var period in _periodHistory) {
        final daysDiff = (period.startDate.difference(date).inDays).abs();
        if (daysDiff < minCycleLength && daysDiff > 0) {
          return 'Too close to another period (${daysDiff} days). Minimum cycle length is $minCycleLength days.';
        }
      }

      // Check if date is too far in the past
      final yearAgo = DateTime.now().subtract(const Duration(days: 365));
      if (date.isBefore(yearAgo)) {
        return 'Cannot add periods more than 1 year in the past';
      }

      // Check if date is in the future
      if (date.isAfter(DateTime.now())) {
        return 'Cannot start a period in the future';
      }

      return 'Invalid date for period start';
    }
    return null;
  }

  bool _canEndPeriodOnDate(DateTime endDate, PeriodEntry period) {
    // End date must be after start date
    if (endDate.isBefore(period.startDate)) {
      return false;
    }

    // Period shouldn't be longer than 10 days typically
    final duration = endDate.difference(period.startDate).inDays;
    if (duration > 10) {
      return false;
    }

    // End date can't be in the future
    if (endDate.isAfter(DateTime.now())) {
      return false;
    }

    return true;
  }

  Widget _buildCalendarDay(DateTime day, DateTime focusedDay) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, _selectedDay);
    final isPeriod = _periodDays.contains(normalizedDay);
    final isFertile = _fertileDays.contains(normalizedDay);
    final isOvulation = _ovulationDays.contains(normalizedDay);
    
    Color? backgroundColor = Colors.transparent;
    Color? textColor = Colors.grey.shade800;
    Color? borderColor = Colors.grey.shade300;
    double borderWidth = 1;
    
    // Only color the days that are actually period/fertile days
    if (isPeriod) {
      backgroundColor = const Color(0xFFE91E63);
      textColor = Colors.white;
    } else if (isOvulation) {
      backgroundColor = Colors.purple.shade400;
      textColor = Colors.white;
    } else if (isFertile) {
      backgroundColor = Colors.purple.shade100;
      textColor = Colors.purple.shade900;
    } else {
      backgroundColor = Colors.green.shade50;
      textColor = Colors.grey.shade800;
  }
    
    // Today gets a blue border
    if (isToday) {
      borderColor = Colors.blue.shade600;
      borderWidth = 2.5;
    }
    
    // Selected day gets special treatment
    if (isSelected && !isPeriod && !isFertile) {
      borderColor = Colors.blue;
      backgroundColor = Colors.blue.shade50;
    }
    
    return GestureDetector(
      onTap: () => _showDayDetails(day),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: textColor,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _showDayDetails(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final isPeriod = _periodDays.contains(normalizedDay);
    final isFertile = _fertileDays.contains(normalizedDay);
    final isOvulation = _ovulationDays.contains(normalizedDay);
    
    // Find period entry for this day
    PeriodEntry? dayPeriod;
    for (var period in _periodHistory) {
      if (day.isAfter(period.startDate.subtract(const Duration(days: 1))) &&
          (period.endDate == null || day.isBefore(period.endDate!.add(const Duration(days: 1))))) {
        dayPeriod = period;
        break;
      }
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDayDetailsSheet(day, isPeriod, isFertile, isOvulation, dayPeriod),
    );
  }

  Widget _buildDayDetailsSheet(DateTime day, bool isPeriod, bool isFertile, bool isOvulation, PeriodEntry? periodEntry) {
    final isToday = isSameDay(day, DateTime.now());
    final canStartPeriod = _canStartPeriodOnDate(day);
    final validationError = _getStartPeriodValidationError(day);
    
    // Check if this specific day has an ongoing period
    final dayHasOngoingPeriod = periodEntry != null && periodEntry.endDate == null;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(day),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Cycle day
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Cycle Day ${_getCycleDay(day)}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Status cards
                  if (isPeriod) _buildStatusCard(
                    'Period Day ${_getPeriodDay(day, periodEntry)}',
                    dayHasOngoingPeriod ? 'Ongoing period' : 'Completed period',
                    Icons.water_drop,
                    const Color(0xFFE91E63),
                  ),
                  
                  if (isOvulation) _buildStatusCard(
                    'Ovulation Day',
                    'Peak fertility - highest chance of conception',
                    Icons.bubble_chart,
                    Colors.purple,
                  ),
                  
                  if (isFertile && !isOvulation) _buildStatusCard(
                    'Fertile Window',
                    'High chance of pregnancy',
                    Icons.favorite,
                    Colors.purple.shade400,
                  ),
                  
                  if (!isPeriod && !isFertile) _buildStatusCard(
                    'Regular Day',
                    'Low fertility',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                  
                  // Validation warning if applicable
                  if (!isPeriod && validationError != null && _canEditDay(day)) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              validationError,
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  if (_canEditDay(day)) ...[
                    if (!isPeriod && canStartPeriod) ...[
                      _buildActionButton(
                        isToday ? 'Start Period' : 'Add Period for this Date',
                        Icons.add,
                        const Color(0xFFE91E63),
                        () => _startPeriodOnDay(day),
                      ),
                      if (!isToday)
                        Text(
                          'You\'ll be asked to set the end date',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                    
                    if (isPeriod && dayHasOngoingPeriod)
                      _buildActionButton(
                        'End Period',
                        Icons.stop,
                        Colors.orange,
                        () async {
                          // Let user pick end date
                          final DateTime? endDate = await showDatePicker(
                            context: context,
                            initialDate: day,
                            firstDate: periodEntry!.startDate,
                            lastDate: DateTime.now(),
                            helpText: 'Select end date',
                          );
                          
                          if (endDate != null) {
                            await _endPeriodWithDate(periodEntry, endDate);
                            if (mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    
                    if (isPeriod)
                      _buildActionButton(
                        'Edit Symptoms',
                        Icons.edit,
                        Colors.blue,
                        () {
                          Navigator.pop(context);
                          _showEditPeriodDialog(day, periodEntry);
                        },
                      ),
                    
                    if (isPeriod && periodEntry != null)
                      _buildActionButton(
                        'Delete This Period',
                        Icons.delete_outline,
                        Colors.red.shade400,
                        () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Period?'),
                              content: const Text('This will remove this period entry. This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirm == true) {
                            // Add delete functionality here
                            await _deletePeriod(periodEntry);
                            if (mounted) Navigator.pop(context);
                          }
                        },
                      ),

                    if (periodEntry != null)
                      _buildActionButton(
                        periodEntry.sharedWithChat ? 'Hide from coach' : 'Share with coach',
                        periodEntry.sharedWithChat ? Icons.visibility_off : Icons.visibility,
                        Colors.purple,
                        () async {
                          await _togglePeriodSharing(periodEntry);
                          if (mounted) Navigator.pop(context);
                        },
                      ),

                    const SizedBox(height: 16),
                  ],
                  // Cycle insights
                  if (_periodHistory.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildCycleInsights(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleInsights() {
    final cycleLength = _userProfile?.cycleLength ?? 28;
    final averageCycle = _calculateAverageCycle();
    final averagePeriodLength = _calculateAveragePeriodLength();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Cycle Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _buildInsightRow('Expected cycle:', '$cycleLength days'),
          _buildInsightRow('Average cycle:', '${averageCycle.round()} days'),
          _buildInsightRow('Average period:', '${averagePeriodLength.round()} days'),
          _buildInsightRow('Total cycles tracked:', '${_periodHistory.length}'),
        ],
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAverageCycle() {
    if (_periodHistory.length < 2) return _userProfile?.cycleLength?.toDouble() ?? 28.0;
    
    int totalDays = 0;
    int cycleCount = 0;
    
    for (int i = 0; i < _periodHistory.length - 1; i++) {
      final current = _periodHistory[i];
      final previous = _periodHistory[i + 1];
      final days = current.startDate.difference(previous.startDate).inDays;
      
      // Only count reasonable cycle lengths (15-45 days)
      if (days >= 15 && days <= 45) {
        totalDays += days;
        cycleCount++;
      }
    }
    
    return cycleCount > 0 ? totalDays / cycleCount : _userProfile?.cycleLength?.toDouble() ?? 28.0;
  }

  double _calculateAveragePeriodLength() {
    if (_periodHistory.isEmpty) return 5.0;
    
    int totalDays = 0;
    int periodCount = 0;
    
    for (var period in _periodHistory) {
      if (period.endDate != null) {
        final days = period.endDate!.difference(period.startDate).inDays + 1;
        if (days > 0 && days <= 10) {
          totalDays += days;
          periodCount++;
        }
      }
    }
    
    return periodCount > 0 ? totalDays / periodCount : 5.0;
  }

  Widget _buildStatusCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback? onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null ? color : Colors.grey.shade300,
          foregroundColor: onPressed != null ? Colors.white : Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getCycleDay(DateTime day) {
    if (_periodHistory.isEmpty || _userProfile == null) return 1;
    
    PeriodEntry? recentPeriod;
    for (var period in _periodHistory) {
      if (period.startDate.isBefore(day.add(const Duration(days: 1)))) {
        recentPeriod = period;
        break;
      }
    }
    
    if (recentPeriod == null) return 1;
    
    return day.difference(recentPeriod.startDate).inDays + 1;
  }

  int _getPeriodDay(DateTime day, PeriodEntry? period) {
    if (period == null) return 1;
    return day.difference(period.startDate).inDays + 1;
  }

  bool _canEditDay(DateTime day) {
    return !day.isAfter(DateTime.now());
  }

  Future<void> _startPeriodOnDay(DateTime day) async {
    if (_userProfile == null || _userProfile!.id == null) return;

    // Validate the date first
    final validationError = _getStartPeriodValidationError(day);
    if (validationError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Check if this is a historical entry (not today)
    final isToday = isSameDay(day, DateTime.now());
    
    if (!isToday) {
      // For historical periods, ask for end date immediately
      await _handleHistoricalPeriod(day);
    } else {
      // For today, start as ongoing period
      await _savePeriodEntry(day, null);
    }
    
    // Close the bottom sheet if it's open
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleHistoricalPeriod(DateTime startDate) async {
    // Show custom dialog for better UI
    final DateTime? endDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        DateTime selectedDate = startDate.add(const Duration(days: 5));
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'When did this period end?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Started: ${DateFormat('EEEE, MMMM d, yyyy').format(startDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show selected end date
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE91E63).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Date:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${selectedDate.difference(startDate).inDays + 1} days',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Quick selection buttons
                    const Text(
                      'Quick Select:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [3, 4, 5, 6, 7].map((days) {
                        final date = startDate.add(Duration(days: days - 1));
                        final isSelected = isSameDay(date, selectedDate);
                        
                        return ChoiceChip(
                          label: Text('$days days'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                          selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected 
                                ? const Color(0xFFE91E63)
                                : Colors.grey.shade700,
                            fontWeight: isSelected 
                                ? FontWeight.w600 
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Info message
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Average period length is 3-7 days',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text(
                    'Keep as Ongoing',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Set End Date'),
                ),
              ],
            );
          },
        );
      },
    );

    if (endDate == null) {
      // User chose to keep as ongoing
      await _savePeriodEntry(startDate, null);
    } else {
      // Save complete period
      await _savePeriodEntry(startDate, endDate);
    }
  }

  Future<void> _endPeriodWithDate(PeriodEntry period, DateTime endDate) async {
    setState(() => _isLoading = true);
    
    try {
      final updatedPeriod = period.copyWith(endDate: endDate);
      await PeriodRepository.savePeriodEntry(updatedPeriod);
      
      await _loadData();
      
      final duration = endDate.difference(period.startDate).inDays + 1;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Period ended ($duration days)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error ending period: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePeriod(PeriodEntry period) async {
    if (period.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete this period entry'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final success = await PeriodRepository.deletePeriodEntry(period.id!);
      
      if (success) {
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Period deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete period'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting period: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error deleting period'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePeriodEntry(DateTime startDate, DateTime? endDate) async {
    if (_userProfile == null || _userProfile!.id == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final newPeriod = PeriodEntry(
        userId: _userProfile!.id!,
        startDate: startDate,
        endDate: endDate,
        flowIntensity: 'Medium',
        symptoms: [],
        mood: null,
        notes: null,
      );
      
      await PeriodRepository.savePeriodEntry(newPeriod);
      
      await _loadData();
      
      if (mounted) {
        final duration = endDate != null 
            ? endDate.difference(startDate).inDays + 1
            : null;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              duration != null 
                  ? 'Period added ($duration days)'
                  : 'Period started on ${DateFormat('MMM d').format(startDate)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving period: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _endPeriodOnDay(DateTime day) async {
    if (_currentPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ongoing period to end'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate end date
    if (day.isBefore(_currentPeriod!.startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final duration = day.difference(_currentPeriod!.startDate).inDays + 1;
    if (duration > 10) {
      // Show confirmation dialog for long periods
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Long Period Duration'),
          content: Text('This period would be $duration days long. Is this correct?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final updatedPeriod = _currentPeriod!.copyWith(endDate: day);
      await PeriodRepository.savePeriodEntry(updatedPeriod);
      
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Period ended (${duration} days)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error ending period: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error ending period. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditPeriodDialog(DateTime day, PeriodEntry? periodEntry) {
    _selectedFlow = periodEntry?.flowIntensity ?? 'Medium';
    _selectedSymptoms = List<String>.from(periodEntry?.symptoms ?? []);
    _selectedMood = periodEntry?.mood;
    _notesController.text = periodEntry?.notes ?? '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Log Symptoms - ${DateFormat('MMM d').format(day)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Flow Intensity:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _flowOptions.map((flow) => ChoiceChip(
                    label: Text(flow),
                    selected: _selectedFlow == flow,
                    onSelected: (selected) {
                      setDialogState(() => _selectedFlow = flow);
                    },
                    selectedColor: const Color(0xFFE91E63).withOpacity(0.2),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                
                const Text('Symptoms:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Cramps', 'Headache', 'Bloating', 'Fatigue',
                    'Breast tenderness', 'Mood swings', 'Back pain', 'Acne'
                  ].map((symptom) => FilterChip(
                    label: Text(symptom, style: const TextStyle(fontSize: 12)),
                    selected: _selectedSymptoms.contains(symptom),
                    onSelected: (selected) {
                      setDialogState(() {
                        if (selected) {
                          _selectedSymptoms.add(symptom);
                        } else {
                          _selectedSymptoms.remove(symptom);
                        }
                      });
                    },
                    selectedColor: Colors.orange.withOpacity(0.2),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add any notes...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
            ElevatedButton(
              onPressed: () => _savePeriodData(day, periodEntry),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePeriodData(DateTime day, PeriodEntry? existingEntry) async {
    if (_userProfile == null || _userProfile!.id == null) return;
    
    try {
      final periodEntry = existingEntry ?? PeriodEntry(
        userId: _userProfile!.id!,
        startDate: day,
        flowIntensity: _selectedFlow,
        symptoms: _selectedSymptoms,
        mood: _selectedMood,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      
      final updatedEntry = periodEntry.copyWith(
        flowIntensity: _selectedFlow,
        symptoms: _selectedSymptoms,
        mood: _selectedMood,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );
      
      await PeriodRepository.savePeriodEntry(updatedEntry);
      await _loadData();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Symptoms saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving period data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
        ),
      );
    }
    
    final cycleDay = _getCycleDay(DateTime.now());
    final hasOngoingPeriod = _currentPeriod != null && _currentPeriod!.endDate == null;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Period Tracker',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              hasOngoingPeriod
                  ? 'Period Day ${_getPeriodDay(DateTime.now(), _currentPeriod)}'
                  : 'Cycle Day $cycleDay',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface),
            onPressed: _showLegend,
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: EdgeInsets.all(4),
                  defaultDecoration: BoxDecoration(),
                  weekendDecoration: BoxDecoration(),
                  selectedDecoration: BoxDecoration(),
                  todayDecoration: BoxDecoration(),
                  outsideDecoration: BoxDecoration(),
                  disabledDecoration: BoxDecoration(),
                ),
                
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.grey.shade600),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  titleTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  weekendStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, focusedDay);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, focusedDay);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, focusedDay);
                  },
                  disabledBuilder: (context, day, focusedDay) {
                    return _buildCalendarDay(day, focusedDay);
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    return Container();
                  },
                ),
                
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _showDayDetails(selectedDay);
                },
                
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
            ),
          ),
          
          // Smart button that changes based on period status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Show warning if there's an ongoing period
                if (hasOngoingPeriod) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You have an ongoing period. End it before starting a new one.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Primary action button
                ElevatedButton.icon(
                  onPressed: hasOngoingPeriod
                      ? () => _endPeriodOnDay(DateTime.now())
                      : () => _startPeriodOnDay(DateTime.now()),
                  icon: Icon(hasOngoingPeriod ? Icons.stop : Icons.add),
                  label: Text(
                    hasOngoingPeriod ? 'End Current Period' : 'Start Period Today',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasOngoingPeriod
                        ? Colors.orange
                        : const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
                
                // Secondary action - log symptoms if period is ongoing
                if (hasOngoingPeriod) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showEditPeriodDialog(DateTime.now(), _currentPeriod),
                    icon: const Icon(Icons.edit),
                    label: const Text('Log Today\'s Symptoms'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE91E63),
                      side: const BorderSide(color: Color(0xFFE91E63)),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calendar Legend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLegendItem(
              color: const Color(0xFFE91E63),
              label: 'Period Days',
              icon: Icons.water_drop,
            ),
            _buildLegendItem(
              color: Colors.purple.shade400,
              label: 'Ovulation Day',
              icon: Icons.bubble_chart,
            ),
            _buildLegendItem(
              color: Colors.purple.withValues(alpha: 0.18),
              label: 'Fertile Window',
              icon: Icons.favorite,
            ),
            _buildLegendItem(
              color: Colors.blue,
              label: 'Today',
              icon: Icons.today,
            ),
            _buildLegendItem(
              color: Colors.green,
              label: 'Regular Days',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}