// lib/features/home/widgets/daily_calendar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';

class DailyCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final UserProfile userProfile;

  const DailyCalendar({
    Key? key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<DailyCalendar> createState() => _DailyCalendarState();
}

class _DailyCalendarState extends State<DailyCalendar> {
  PageController pageController = PageController(initialPage: 1000);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(widget.selectedDate),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final newDate = DateTime(
                      widget.selectedDate.year,
                      widget.selectedDate.month - 1,
                      widget.selectedDate.day,
                    );
                    widget.onDateSelected(newDate);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final newDate = DateTime(
                      widget.selectedDate.year,
                      widget.selectedDate.month + 1,
                      widget.selectedDate.day,
                    );
                    widget.onDateSelected(newDate);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildWeekView(),
        const SizedBox(height: 16),
        _buildTodayActivities(),
      ],
    );
  }

  Widget _buildWeekView() {
    final today = DateTime.now();
    final startOfWeek = widget.selectedDate.subtract(
      Duration(days: widget.selectedDate.weekday - 1),
    );

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, today);
          
          return GestureDetector(
            onTap: () => widget.onDateSelected(date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected 
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildActivityDots(date),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityDots(DateTime date) {
    // Mock data - replace with actual data based on date
    final hasWorkout = date.weekday % 2 == 0;
    final hasNutrition = true;
    final hasSleep = date.isBefore(DateTime.now());
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasWorkout) _buildDot(Colors.blue),
        if (hasNutrition) _buildDot(Colors.green),
        if (hasSleep) _buildDot(Colors.purple),
      ],
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTodayActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activities for ${DateFormat('MMM dd').format(widget.selectedDate)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildActivityChip('Meals', Icons.restaurant, Colors.green, 3, 3),
            _buildActivityChip('Water', Icons.water_drop, Colors.blue, 8, 8),
            _buildActivityChip('Sleep', Icons.bedtime, Colors.purple, 1, 1),
            _buildActivityChip('Exercise', Icons.fitness_center, Colors.orange, 0, 1),
            if (widget.userProfile.gender == 'Female')
              _buildActivityChip('Period', Icons.favorite, Colors.pink, 0, 1),
            _buildActivityChip('Weight', Icons.monitor_weight, Colors.grey, 1, 1),
            _buildActivityChip('Supplements', Icons.medication, Colors.indigo, 2, 3),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityChip(String label, IconData icon, Color color, int completed, int total) {
    final isCompleted = completed == total;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCompleted ? color.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? color : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isCompleted ? color : Colors.grey[600],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isCompleted ? color : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 10,
              color: isCompleted ? color : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}