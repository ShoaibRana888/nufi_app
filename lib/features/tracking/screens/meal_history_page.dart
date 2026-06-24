// lib/features/tracking/screens/meal_history_page.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';
import 'package:user_onboarding/data/services/api/sharing_api.dart';
import 'package:intl/intl.dart';

class MealHistoryPage extends StatefulWidget {
  final UserProfile userProfile;

  const MealHistoryPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<MealHistoryPage> createState() => _MealHistoryPageState();
}

class _MealHistoryPageState extends State<MealHistoryPage> {
  final MealApi _apiService = MealApi();
  final SharingApi _sharingApi = SharingApi();
  List<Map<String, dynamic>> _meals = [];
  Map<String, dynamic> _dailyTotals = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    setState(() => _isLoading = true);
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      // Load both daily summary and individual meals
      final summary = await _apiService.getDailySummary(widget.userProfile.id!, date: dateStr);
      final meals = await _apiService.getMealHistory(widget.userProfile.id!, date: dateStr);
      
      print('📊 Summary loaded: $summary');
      print('📊 Meals loaded: ${meals.length} meals');
      
      setState(() {
        _meals = meals;
        
        // Use summary totals if available, otherwise calculate from meals
        if (summary['totals'] != null) {
          _dailyTotals = Map<String, dynamic>.from(summary['totals']);
          print('📊 Using summary totals: $_dailyTotals');
        } else {
          _calculateDailyTotals();
          print('📊 Calculated totals: $_dailyTotals');
        }
      });
    } catch (e) {
      print('❌ Error loading meals: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateDailyTotals() {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalFiber = 0;
    double totalSugar = 0;
    double totalSodium = 0;

    for (var meal in _meals) {
      totalCalories += (meal['calories'] as num?)?.toDouble() ?? 0;
      totalProtein += (meal['protein_g'] as num?)?.toDouble() ?? 0;
      totalCarbs += (meal['carbs_g'] as num?)?.toDouble() ?? 0;
      totalFat += (meal['fat_g'] as num?)?.toDouble() ?? 0;
      totalFiber += (meal['fiber_g'] as num?)?.toDouble() ?? 0;
      totalSugar += (meal['sugar_g'] as num?)?.toDouble() ?? 0;
      totalSodium += (meal['sodium_mg'] as num?)?.toDouble() ?? 0;
    }

    _dailyTotals = {
      'calories': totalCalories,
      'protein_g': totalProtein,
      'carbs_g': totalCarbs,
      'fat_g': totalFat,
      'fiber_g': totalFiber,
      'sugar_g': totalSugar,
      'sodium_mg': totalSodium,
    };
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadMeals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Meal History'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.green,
                  child: Text(
                    DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Daily Totals Calculator
                _buildDailyTotalsCard(),
                
                // Clear Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Divider(
                    thickness: 2,
                    color: Colors.grey,
                  ),
                ),
                
                // Section Header for Meals
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Meals (${_meals.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                
                // Simplified Meals List
                Expanded(
                  child: _meals.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.no_meals,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No meals logged for this date',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _meals.length,
                          itemBuilder: (context, index) =>
                              _buildSimpleMealCard(_meals[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSimpleMealCard(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Meal type indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getMealTypeColor(meal['meal_type']),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Meal info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMealTypeColor(meal['meal_type']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meal['meal_type'] ?? 'Snack',
                    style: TextStyle(
                      color: _getMealTypeColor(meal['meal_type']),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // Food item
                Text(
                  meal['food_item'] ?? 'Unknown food',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Quantity
                Text(
                  meal['quantity'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Calories
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${meal['calories']?.toStringAsFixed(0) ?? '0'} cal',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.green,
              ),
            ),
          ),
          
          // ADD THIS: Action buttons
          const SizedBox(width: 8),
          // Hidden-from-coach indicator
          if (meal['shared_with_chat'] == false) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Hidden from AI coach',
              child: Icon(Icons.visibility_off, size: 18, color: Colors.grey[500]),
            ),
          ],
          // ADD THIS: Action buttons
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'edit') {
                _editMeal(meal);
              } else if (value == 'delete') {
                _confirmDeleteMeal(meal);
              } else if (value == 'sharing') {
                _toggleMealSharing(meal);
              }
            },
            itemBuilder: (context) {
              final isShared = meal['shared_with_chat'] != false;
              return [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
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
                      Text(isShared ? 'Hide from coach' : 'Share with coach'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Color _getMealTypeColor(String? mealType) {
    switch (mealType?.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snack':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDailyTotalsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Daily Nutrition Summary',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_meals.length} meals',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Main Calories Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Text(
                  '${_dailyTotals['calories']?.toStringAsFixed(0) ?? '0'}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'TOTAL CALORIES',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Macronutrients
          const Text(
            'MACRONUTRIENTS',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactNutrientBox(
                  'Protein',
                  '${_dailyTotals['protein_g']?.toStringAsFixed(1) ?? '0'}g',
                  Colors.red[600]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactNutrientBox(
                  'Carbs',
                  '${_dailyTotals['carbs_g']?.toStringAsFixed(1) ?? '0'}g',
                  Colors.orange[600]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactNutrientBox(
                  'Fat',
                  '${_dailyTotals['fat_g']?.toStringAsFixed(1) ?? '0'}g',
                  Colors.blue[600]!,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Micronutrients
          const Text(
            'MICRONUTRIENTS',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCompactNutrientBox(
                  'Fiber',
                  '${_dailyTotals['fiber_g']?.toStringAsFixed(1) ?? '0'}g',
                  Colors.green[600]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactNutrientBox(
                  'Sugar',
                  '${_dailyTotals['sugar_g']?.toStringAsFixed(1) ?? '0'}g',
                  Colors.purple[600]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCompactNutrientBox(
                  'Sodium',
                  '${_dailyTotals['sodium_mg']?.toStringAsFixed(0) ?? '0'}mg',
                  Colors.amber[700]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanNutrientBox(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Delete meal with confirmation
  Future<void> _confirmDeleteMeal(Map<String, dynamic> meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: Text('Are you sure you want to delete "${meal['food_item']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteMeal(meal);
    }
  }

  // Toggle whether this meal is shared with the AI coach
  Future<void> _toggleMealSharing(Map<String, dynamic> meal) async {
    final wasShared = meal['shared_with_chat'] != false;
    final newShared = !wasShared;

    // Optimistic UI update
    setState(() => meal['shared_with_chat'] = newShared);

    final ok = await _sharingApi.setEntrySharing(
      userId: widget.userProfile.id!,
      activityType: 'meal',
      itemId: meal['id'].toString(),
      shared: newShared,
    );

    if (!mounted) return;
    if (!ok) {
      // Revert on failure
      setState(() => meal['shared_with_chat'] = wasShared);
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
        content: Text(newShared ? 'Meal shared with coach' : 'Meal hidden from coach'),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // Delete meal
  Future<void> _deleteMeal(Map<String, dynamic> meal) async {
    try {
      final success = await _apiService.deleteMeal(meal['id'], widget.userProfile.id);
      
      if (success) {
        // Reload meals after deletion
        await _loadMeals();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete meal');
      }
    } catch (e) {
      print('Error deleting meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Edit meal - opens a dialog or navigates to edit page
  void _editMeal(Map<String, dynamic> meal) {
    // Option 1: Show edit dialog
    showDialog(
      context: context,
      builder: (context) => _EditMealDialog(
        meal: meal,
        onSave: (updatedMeal) async {
          await _updateMeal(meal['id'], updatedMeal);
          await _loadMeals();
        },
      ),
    );
  }

  // Update meal
  Future<void> _updateMeal(String mealId, Map<String, dynamic> updatedData) async {
    try {
      await _apiService.updateMeal(mealId, updatedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating meal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCompactNutrientBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMealDialog extends StatefulWidget {
  final Map<String, dynamic> meal;
  final Function(Map<String, dynamic>) onSave;
  
  const _EditMealDialog({
    required this.meal,
    required this.onSave,
  });
  
  @override
  State<_EditMealDialog> createState() => _EditMealDialogState();
}

class _EditMealDialogState extends State<_EditMealDialog> {
  late TextEditingController _foodController;
  late TextEditingController _quantityController;
  String? _selectedMealType;
  
  @override
  void initState() {
    super.initState();
    _foodController = TextEditingController(text: widget.meal['food_item']);
    _quantityController = TextEditingController(text: widget.meal['quantity']);
    _selectedMealType = widget.meal['meal_type'];
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Meal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _foodController,
            decoration: const InputDecoration(
              labelText: 'Food Item',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedMealType,
            decoration: const InputDecoration(
              labelText: 'Meal Type',
              border: OutlineInputBorder(),
            ),
            items: ['Breakfast', 'Lunch', 'Dinner', 'Snack']
                .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedMealType = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave({
              'food_item': _foodController.text,
              'quantity': _quantityController.text,
              'meal_type': _selectedMealType,
            });
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _foodController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}