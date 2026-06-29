// lib/features/home/widgets/energy_balance_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';

class EnergyBalanceCard extends StatefulWidget {
  final UserProfile userProfile;
  final DateTime? selectedDate;
  final VoidCallback? onTap;

  const EnergyBalanceCard({
    Key? key,
    required this.userProfile,
    this.selectedDate,
    this.onTap,
  }) : super(key: key);

  @override
  State<EnergyBalanceCard> createState() => _EnergyBalanceCardState();
}

class _EnergyBalanceCardState extends State<EnergyBalanceCard> {
  final MealApi _apiService = MealApi();
  Map<String, dynamic>? _energyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEnergyBalance();
  }

  @override
  void didUpdateWidget(EnergyBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadEnergyBalance();
    }
  }

  Future<void> _loadEnergyBalance() async {
    if (widget.userProfile.id == null) return;

    setState(() => _isLoading = true);

    try {
      final date = widget.selectedDate ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final data = await _apiService.getEnergyBalance(
        widget.userProfile.id!,
        date: dateStr,
      );

      if (mounted) {
        setState(() {
          _energyData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading energy balance: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_energyData == null) {
      return const Center(child: Text('No data available'));
    }

    final balance = _energyData!['energy_balance'] ?? {};
    final caloriesConsumed = balance['calories_consumed'] ?? 0;
    final caloriesBurned = balance['calories_burned'] ?? 0;
    final netCalories = balance['net_calories'] ?? 0;
    final calorieGoal = balance['calorie_goal'] ?? 2000;
    final remainingCalories = balance['remaining_calories'] ?? calorieGoal;

    // Calculate progress (consumed / goal, capped at 1.0 for display)
    final progress = (caloriesConsumed / calorieGoal).clamp(0.0, 1.5);
    
    // Determine color based on remaining
    Color progressColor;
    if (remainingCalories > 0) {
      progressColor = Colors.green;
    } else if (remainingCalories > -200) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Energy Balance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loadEnergyBalance,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Main calorie display
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 12,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${remainingCalories.abs()}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                  Text(
                    remainingCalories >= 0 ? 'remaining' : 'over',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Breakdown row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn(
              'Consumed',
              '$caloriesConsumed',
              Icons.restaurant,
              Colors.orange,
            ),
            _buildStatColumn(
              'Burned',
              '-$caloriesBurned',
              Icons.local_fire_department,
              Colors.red,
            ),
            _buildStatColumn(
              'Net',
              '$netCalories',
              Icons.balance,
              Colors.blue,
            ),
            _buildStatColumn(
              'Goal',
              '$calorieGoal',
              Icons.flag,
              Colors.green,
            ),
          ],
        ),
        
        // Exercise info if any
        if (caloriesBurned > 0) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.fitness_center, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You\'ve earned $caloriesBurned extra calories from exercise!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}