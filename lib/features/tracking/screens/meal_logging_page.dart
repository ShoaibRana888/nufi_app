// lib/features/tracking/screens/enhanced_meal_logging_page.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';
import 'package:user_onboarding/features/tracking/screens/meal_history_page.dart';
import 'package:user_onboarding/features/tracking/widgets/voice_input_widget.dart';
import 'package:user_onboarding/features/tracking/screens/meal_suggestions_sheet.dart';

class EnhancedMealLoggingPage extends StatefulWidget {
  final UserProfile userProfile;

  const EnhancedMealLoggingPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<EnhancedMealLoggingPage> createState() => _EnhancedMealLoggingPageState();
}

class _EnhancedMealLoggingPageState extends State<EnhancedMealLoggingPage> {
  final MealApi _apiService = MealApi();
  final ExerciseApi _exerciseApi = ExerciseApi();
  
  // Controllers
  final _multiLineController = TextEditingController();
  final _quantityController = TextEditingController();
  final _searchController = TextEditingController();
  
  // State
  DateTime _selectedDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  String _selectedMealType = 'Lunch';
  bool _isAnalyzing = false;
  Map<String, dynamic>? _nutritionData;
  List<Map<String, dynamic>> _foodItems = [];
  bool _useMultiLineEntry = false;
  int _dailyMealGoal = 3;
  double _dailyCalorieGoal = 2000;
  double _caloriesBurned = 0;
  Map<String, double> _macroGoals = {
    'protein': 150.0,
    'carbs': 225.0,
    'fat': 67.0,
  };
  List<Map<String, dynamic>> _todaysMeals = [];
  
  // Enhanced features state
  List<Map<String, dynamic>> _mealPresets = [];
  List<Map<String, dynamic>> _recentMeals = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _showCalendar = false;
  bool _showRecentMeals = false;
  bool _showPresets = false;
  
  
  // Common meal combos for quick selection
  final List<Map<String, dynamic>> _mealCombos = [
    {
      'name': 'Breakfast Combo',
      'items': '2 scrambled eggs, 2 slices whole wheat toast, 1 cup orange juice',
      'icon': Icons.egg_alt,
    },
    {
      'name': 'Lunch Combo',
      'items': 'Grilled chicken sandwich with lettuce and tomato, side salad, apple',
      'icon': Icons.lunch_dining,
    },
    {
      'name': 'Dinner Plate',
      'items': '6 oz grilled salmon, 1 cup brown rice, steamed broccoli',
      'icon': Icons.dinner_dining,
    },
    {
      'name': 'Burger Meal',
      'items': 'Cheeseburger and medium fries with diet coke',
      'icon': Icons.fastfood,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTodaysMeals();
    _loadPresets();
    _loadRecentMeals();
    _loadExerciseData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDailyGoals();
      if (mounted) setState(() {});
    });
    _dailyMealGoal = widget.userProfile.dailyMealsCount ?? 3;
    _setMealTypeByTime();
    
    // Add listener for search
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _multiLineController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (_searchController.text.length > 2) {
      _performSearch(_searchController.text);
    } else {
      setState(() {
        _searchResults = [];
      });
    }
  }

  bool _hasMealTypeLogged(String mealType) {
    if (mealType.toLowerCase() == 'snack') {
      return false; // Allow multiple snacks
    }
    
    return _todaysMeals.any((meal) => 
      meal['meal_type']?.toLowerCase() == mealType.toLowerCase()
    );
  }

  DateTime _parseUTCToLocal(String? utcString) {
    if (utcString == null) return DateTime.now();
    
    try {
      // Ensure the string has UTC indicator
      String normalized = utcString.trim();
      if (!normalized.endsWith('Z') && !normalized.contains('+') && !normalized.contains('UTC')) {
        normalized += 'Z';
      }
      
      // Parse as UTC and convert to local
      final utcTime = DateTime.parse(normalized).toUtc();
      final localTime = utcTime.toLocal();
      
      return localTime;
    } catch (e) {
      print('❌ Error parsing time: $e');
      return DateTime.now();
    }
  }

  Future<void> _performSearch(String query) async {
    final queryLower = query.toLowerCase();
    
    // Search in both recent meals and presets
    final List<Map<String, dynamic>> results = [];
    
    // Search recent meals
    for (final meal in _recentMeals) {
      final foodItem = meal['food_item']?.toString().toLowerCase() ?? '';
      if (foodItem.contains(queryLower)) {
        results.add({...meal, 'type': 'recent'});
      }
    }
    
    // Search presets
    for (final preset in _mealPresets) {
      final presetName = preset['preset_name']?.toString().toLowerCase() ?? '';
      if (presetName.contains(queryLower)) {
        results.add({...preset, 'type': 'preset'});
      }
    }
    
    setState(() {
      _searchResults = results;
    });
  }

  Future<void> _loadPresets() async {
    try {
      final response = await _apiService.getMealPresets(widget.userProfile.id!);
      setState(() {
        _mealPresets = response['presets'] ?? [];
      });
    } catch (e) {
      print('Error loading presets: $e');
    }
  }

  Future<void> _loadRecentMeals() async {
    try {
      final response = await _apiService.getMealSuggestions(widget.userProfile.id!);
      setState(() {
        _recentMeals = response['recent_meals'] ?? [];
      });
    } catch (e) {
      print('Error loading recent meals: $e');
    }
  }

  Future<void> _loadMealsForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final meals = await _apiService.getMealHistory(
        widget.userProfile.id!,
        date: dateStr,
      );
      
      setState(() {
        _todaysMeals = meals;
        _selectedDate = date; 
      });
      
      await _loadExerciseData();
    } catch (e) {
      print('Error loading meals: $e');
    }
  }

  Future<void> _loadTodaysMeals() async {
    await _loadMealsForDate(DateTime.now());
  }

  Future<bool> _confirmDuplicateMealType(String mealType) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Duplicate Meal Type')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have already logged a $mealType today.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to log another $mealType?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can log multiple Snacks without this warning.',
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
            child: const Text(
              'Yes, Log Anyway',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _loadExerciseData() async {
    if (widget.userProfile.id == null) return;
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final exercises = await _exerciseApi.getExerciseLogs(
        widget.userProfile.id!,
        startDate: dateStr,
        endDate: dateStr,
      );
      
      double totalBurned = 0;
      for (var ex in exercises) {
        totalBurned += (ex['calories_burned'] ?? 0).toDouble();
      }
      
      if (mounted) {
        setState(() {
          _caloriesBurned = totalBurned;
        });
      }
    } catch (e) {
      print('Error loading exercise data: $e');
    }
  }

  void _calculateDailyGoals() {
    try {
      final tdee = (widget.userProfile.formData?['tdee'] ?? widget.userProfile.tdee ?? 2000).toDouble();
      final weightGoal = widget.userProfile.primaryGoal ?? 'maintain_weight';
      final currentWeight = widget.userProfile.weight ?? 70.0;
      final activityLevel = widget.userProfile.activityLevel ?? 'moderately_active';
      
      // Match the logic from daily_meal_card.dart
      double calorieAdjustment = 0;
      Map<String, double> macroPercentages = {};
      
      switch (weightGoal.toLowerCase()) {
        case 'lose_weight':
        case 'weight_loss':
          calorieAdjustment = -500;
          macroPercentages = {
            'protein': 0.35,
            'carbs': 0.40,
            'fat': 0.25,
          };
          break;
          
        case 'gain_muscle':
        case 'muscle_gain':
        case 'recomposition':
        case 'lose_fat':
          calorieAdjustment = weightGoal.contains('gain') ? 200 : -200;
          macroPercentages = {
            'protein': 0.40,
            'carbs': 0.35,
            'fat': 0.25,
          };
          break;
          
        case 'gain_weight':
        case 'weight_gain':
        case 'bulk':
          calorieAdjustment = 400;
          macroPercentages = {
            'protein': 0.25,
            'carbs': 0.45,
            'fat': 0.30,
          };
          break;
          
        case 'maintain_weight':
        case 'maintenance':
        default:
          calorieAdjustment = 0;
          macroPercentages = {
            'protein': 0.30,
            'carbs': 0.40,
            'fat': 0.30,
          };
          break;
      }
      
      // Adjust for activity level
      if (activityLevel == 'very_active' || activityLevel == 'extremely_active') {
        macroPercentages['carbs'] = (macroPercentages['carbs'] ?? 0.40) + 0.05;
        macroPercentages['fat'] = (macroPercentages['fat'] ?? 0.30) - 0.05;
      }
      
      // Calculate daily calorie goal
      _dailyCalorieGoal = tdee + calorieAdjustment;
      
      // Calculate macro grams from percentages
      _macroGoals = {
        'protein': (_dailyCalorieGoal * macroPercentages['protein']!) / 4,
        'carbs': (_dailyCalorieGoal * macroPercentages['carbs']!) / 4,
        'fat': (_dailyCalorieGoal * macroPercentages['fat']!) / 9,
      };
      
      // Ensure minimum protein intake
      double minProtein = currentWeight * 0.8;
      if (_macroGoals['protein']! < minProtein) {
        _macroGoals['protein'] = minProtein;
      }
      
      // For muscle gain/recomp, increase protein
      if (weightGoal.contains('muscle') || weightGoal == 'recomposition') {
        _macroGoals['protein'] = currentWeight * 2.2;
      }
      
    } catch (e) {
      print('Error calculating goals: $e');
      _dailyCalorieGoal = 2000;
      _macroGoals = {
        'protein': 150.0,
        'carbs': 225.0,
        'fat': 67.0,
      };
    }
  }
  
  void _setMealTypeByTime() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      _selectedMealType = 'Breakfast';
    } else if (hour < 15) {
      _selectedMealType = 'Lunch';
    } else if (hour < 20) {
      _selectedMealType = 'Dinner';
    } else {
      _selectedMealType = 'Snack';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(DateUtils.isSameDay(_selectedDate, DateTime.now()) 
          ? 'Smart Meal Logging' 
          : 'Log Meals - ${DateFormat('MMM d').format(_selectedDate)}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _showMealSuggestions,
            tooltip: 'Get meal suggestions',
          ),
          IconButton(
            icon: Icon(_showCalendar ? Icons.close : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: _openPresetsModal,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewHistory,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Calendar (collapsible)
              if (_showCalendar) _buildCalendar(),
              
              // Date indicator if not today
              if (!DateUtils.isSameDay(_selectedDate, DateTime.now()))
                _buildDateIndicator(),
              
              // Search bar
              _buildSearchBar(),
              
              // Search results dropdown
              if (_searchResults.isNotEmpty) _buildSearchResults(),
              
              // Meal Type Selector
              _buildMealTypeSelector(),
              
              // Recent Meals (collapsible section)
              _buildRecentMealsSection(),
              
              // Entry Mode Toggle
              _buildEntryModeToggle(),
              
              // Quick Meal Combos
              if (!_useMultiLineEntry) _buildQuickCombos(),
              
              // Main Entry Area
              _buildEntryArea(),
              
              // Individual Items List
              if (!_useMultiLineEntry && _foodItems.isNotEmpty) 
                _buildItemsList(),
              
              // Analyze Button
              _buildAnalyzeButton(),

              // Today's Meals
              _buildTodaysMeals(),
              
              // Results
              if (_nutritionData != null) _buildResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      color: Colors.white,
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
          _loadMealsForDate(selectedDay);
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Colors.lightGreen,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildDateIndicator() {
    return Container(
      color: Colors.orange.shade100,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text(
            'Logging meals for ${DateFormat('EEEE, MMMM d').format(_selectedDate)}',
            style: const TextStyle(color: Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search meals, presets, or enter new food...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                  });
                },
              )
            : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final item = _searchResults[index];
          final isPreset = item['type'] == 'preset';
          
          // Extract nutrition values properly
          final calories = isPreset 
            ? _extractDouble(item, ['total_calories', 'calories'])
            : _extractDouble(item, ['calories']);
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isPreset ? Colors.amber.shade100 : Colors.green.shade100,
              child: Icon(
                isPreset ? Icons.star : Icons.history,
                color: isPreset ? Colors.amber : Colors.green,
              ),
            ),
            title: Text(isPreset ? item['preset_name'] : item['food_item']),
            subtitle: Text(
              isPreset 
                ? '${calories.round()}cal preset'
                : '${item['quantity']} • ${calories.round()}cal',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick log button for presets
                if (isPreset)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchResults = []);
                      _logPresetDirectly(item);
                    },
                    tooltip: 'Quick log',
                  ),
                Chip(
                  label: Text(
                    isPreset ? 'Preset' : 'Recent', 
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: isPreset ? Colors.amber.shade100 : Colors.blue.shade100,
                ),
              ],
            ),
            onTap: () {
              if (isPreset) {
                _logPresetDirectly(item);
              } else {
                _quickAddMeal(item);
              }
              _searchController.clear();
              setState(() {
                _searchResults = [];
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildRecentMealsSection() {
    if (_recentMeals.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showRecentMeals = !_showRecentMeals;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _showRecentMeals ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Meals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_recentMeals.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showRecentMeals) ...[
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentMeals.length,
                itemBuilder: (context, index) {
                  final meal = _recentMeals[index];
                  return _buildRecentMealCard(meal);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentMealCard(Map<String, dynamic> meal) {
    final calories = _extractDouble(meal, ['calories']);
    
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: InkWell(
          onTap: () => _quickAddMeal(meal),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal['food_item'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  meal['quantity'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, 
                      size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '${calories.round()}cal',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    final mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];
    
    return Container(
      margin: const EdgeInsets.all(16),
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mealTypes.length,
        itemBuilder: (context, index) {
          final mealType = mealTypes[index];
          final isSelected = _selectedMealType == mealType;
          
          return GestureDetector(
            onTap: () => setState(() => _selectedMealType = mealType),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.green : Colors.grey.shade300,
                ),
              ),
              child: Center(
                child: Text(
                  mealType,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntryModeToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _useMultiLineEntry = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_useMultiLineEntry ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: !_useMultiLineEntry ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Items',
                      style: TextStyle(
                        color: !_useMultiLineEntry ? Colors.green : Colors.grey,
                        fontWeight: !_useMultiLineEntry ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _useMultiLineEntry = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _useMultiLineEntry ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.text_fields,
                      color: _useMultiLineEntry ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Describe Meal',
                      style: TextStyle(
                        color: _useMultiLineEntry ? Colors.green : Colors.grey,
                        fontWeight: _useMultiLineEntry ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCombos() {
    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _mealCombos.length,
        itemBuilder: (context, index) {
          final combo = _mealCombos[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _useMultiLineEntry = true;
                _multiLineController.text = combo['items'];
              });
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    combo['icon'],
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    combo['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to use',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEntryArea() {
    if (_useMultiLineEntry) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Describe your meal:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can list multiple items separated by commas, "and", or "with"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _multiLineController,
                    maxLines: 4,
                    onChanged: (value) {
                      // Add this to trigger UI updates
                      setState(() {});
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g., grilled chicken with rice and salad',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceInputWidget(
                  onTextReceived: (text) {
                    setState(() {
                      if (_multiLineController.text.isEmpty) {
                        _multiLineController.text = text;
                      } else {
                        _multiLineController.text += ', $text';
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add food items:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _multiLineController,
                    decoration: InputDecoration(
                      hintText: 'Food item',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceInputWidget(
                  onTextReceived: (text) {
                    setState(() {
                      _multiLineController.text = text;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      hintText: 'Quantity',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addFoodItem,
                  icon: const Icon(Icons.add_circle),
                  color: Colors.green,
                  iconSize: 40,
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items to log:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._foodItems.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item['food']),
              subtitle: Text(item['quantity']),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _foodItems.remove(item);
                  });
                },
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    final hasContent = _useMultiLineEntry 
        ? _multiLineController.text.isNotEmpty 
        : _foodItems.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasContent && !_isAnalyzing ? _analyzeMeal : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isAnalyzing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Analyze Meal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _saveLoggedMealAsPreset(Map<String, dynamic> meal) async {
    final presetNameController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Give this preset a memorable name:'),
            const SizedBox(height: 16),
            TextField(
              controller: presetNameController,
              decoration: InputDecoration(
                hintText: meal['food_item'],
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final presetName = presetNameController.text.isNotEmpty 
        ? presetNameController.text 
        : meal['food_item'];
      
      try {
        // Extract nutrition values with proper fallback
        final calories = _extractDouble(meal, ['calories']);
        final proteinG = _extractDouble(meal, ['protein_g', 'protein']);
        final carbsG = _extractDouble(meal, ['carbs_g', 'carbs']);
        final fatG = _extractDouble(meal, ['fat_g', 'fat']);
        final fiberG = _extractDouble(meal, ['fiber_g', 'fiber']);
        final sugarG = _extractDouble(meal, ['sugar_g', 'sugar']);
        final sodiumMg = _extractDouble(meal, ['sodium_mg', 'sodium']);
        
        await _apiService.createPreset({
          'user_id': widget.userProfile.id,
          'preset_name': presetName,
          'food_items': meal['food_item'],
          'meal_type': meal['meal_type'],
          'nutrition_data': meal,
          'total_calories': calories,
          'total_protein_g': proteinG,
          'total_carbs_g': carbsG,
          'total_fat_g': fatG,
          'total_fiber_g': fiberG,
          'total_sugar_g': sugarG,
          'total_sodium_mg': sodiumMg,
        });
        
        await _loadPresets();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.star, color: Colors.white),
                SizedBox(width: 8),
                Text('Meal saved as preset!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Error saving logged meal as preset: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _analyzeMeal() async {
    if (widget.userProfile.id == null || widget.userProfile.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for duplicate meal type (only for today's meals)
    if (DateUtils.isSameDay(_selectedDate, DateTime.now())) {
      if (_hasMealTypeLogged(_selectedMealType)) {
        final confirmed = await _confirmDuplicateMealType(_selectedMealType);
        if (!confirmed) {
          return;
        }
      }
    }

    setState(() => _isAnalyzing = true);

    try {
      String mealDescription;
      String quantity = '1 serving';
      
      if (_useMultiLineEntry) {
        mealDescription = _multiLineController.text;
      } else {
        mealDescription = _foodItems
            .map((item) => '${item['quantity']} ${item['food']}')
            .join(', ');
      }

      // FIXED: Same approach as weight logging - use local time then convert to UTC
      DateTime mealDateTime;
      final now = DateTime.now();
      
      // Check if selected date is today
      if (_selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day) {
        // It's today - use actual current time
        mealDateTime = now;
        print('✅ Using current time for today: $mealDateTime');
      } else {
        // It's a past date - use a reasonable time for the meal type
        int hour;
        switch (_selectedMealType.toLowerCase()) {
          case 'breakfast':
            hour = 8;
            break;
          case 'lunch':
            hour = 13;
            break;
          case 'dinner':
            hour = 19;
            break;
          case 'snack':
            hour = 15;
            break;
          default:
            hour = 12;
        }
        
        mealDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
          0,
          0,
        );
        print('✅ Using default time for past date: $mealDateTime');
      }

      // Convert local time to UTC before sending to backend (same as weight logging)
      final utcDateTime = mealDateTime.toUtc();

      print('📅 Local time: $mealDateTime');
      print('📅 UTC time being sent: $utcDateTime');
      print('📅 As ISO string: ${utcDateTime.toIso8601String()}');

      final response = await _apiService.analyzeMeal({
        'user_id': widget.userProfile.id,
        'food_item': mealDescription,
        'quantity': quantity,
        'meal_type': _selectedMealType,
        'meal_date': utcDateTime.toIso8601String(), // Send UTC time
      });

      setState(() {
        if (response.containsKey('meal')) {
          _nutritionData = response['meal'];
        } else if (response.containsKey('data')) {
          _nutritionData = response['data'];
        } else {
          _nutritionData = response;
        }
        _isAnalyzing = false;
      });

      String dataSource = _nutritionData?['data_source'] ?? 'Unknown';
      print('Data source used: $dataSource');

      if (response['success'] == true || _nutritionData != null) {
        _showSaveAsPresetDialog(_nutritionData!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Meal analyzed successfully! (${_nutritionData?['calories']?.round() ?? 0} calories)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await _loadMealsForDate(_selectedDate);

      _multiLineController.clear();
      _quantityController.clear();
      _foodItems.clear();
      
    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing meal: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error details: $e');
    }
  }


  void _usePreset(Map<String, dynamic> preset) {
    setState(() {
      _useMultiLineEntry = true;
      // FIXED: Use food_items instead of preset_name
      _multiLineController.text = preset['food_items'] ?? preset['preset_name'] ?? '';
      _selectedMealType = preset['meal_type'] ?? _selectedMealType;
      
      // Pre-populate nutrition data if available
      if (preset['nutrition_data'] != null) {
        _nutritionData = preset['nutrition_data'];
      }
    });
    
    // Scroll to the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.edit, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Preset "${preset['preset_name']}" loaded for editing'),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _quickAddMeal(Map<String, dynamic> meal) async {
    setState(() => _isAnalyzing = true);
    
    try {
      // FIXED: Same approach as weight logging
      DateTime mealDateTime;
      final now = DateTime.now();
      
      // Check if selected date is today
      if (_selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day) {
        // It's today - use actual current time
        mealDateTime = now;
        print('✅ Using current time for today: $mealDateTime');
      } else {
        // It's a past date - use a reasonable time for the meal type
        int hour;
        switch (_selectedMealType.toLowerCase()) {
          case 'breakfast':
            hour = 8;
            break;
          case 'lunch':
            hour = 13;
            break;
          case 'dinner':
            hour = 19;
            break;
          case 'snack':
            hour = 15;
            break;
          default:
            hour = 12;
        }
        
        mealDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
          0,
          0,
        );
        print('✅ Using default time for past date: $mealDateTime');
      }

      // Convert local time to UTC before sending to backend (same as weight logging)
      final utcDateTime = mealDateTime.toUtc();

      print('📅 Quick adding meal - Local time: $mealDateTime');
      print('📅 Quick adding meal - UTC time: $utcDateTime');

      final response = await _apiService.analyzeMeal({
        'user_id': widget.userProfile.id,
        'food_item': meal['food_item'],
        'quantity': meal['quantity'] ?? '1 serving',
        'meal_type': _selectedMealType,
        'meal_date': utcDateTime.toIso8601String(), // Send UTC time
        'cached_nutrition': meal['nutrition_data'],
      });
      
      setState(() {
        _isAnalyzing = false;
        if (response['success'] == true) {
          _nutritionData = response['meal'] ?? response['data'];
        }
      });
      
      await _loadMealsForDate(_selectedDate);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding meal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openPresetsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Presets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: _mealPresets.isEmpty
                  ? const Center(
                      child: Text('No presets saved yet'),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _mealPresets.length,
                      itemBuilder: (context, index) {
                        final preset = _mealPresets[index];
                        
                        // FIXED: Extract values properly from database
                        final calories = _extractDouble(preset, ['total_calories', 'calories']);
                        final protein = _extractDouble(preset, ['total_protein_g', 'protein_g', 'protein']);
                        final carbs = _extractDouble(preset, ['total_carbs_g', 'carbs_g', 'carbs']);
                        final fat = _extractDouble(preset, ['total_fat_g', 'fat_g', 'fat']);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: Colors.amber.shade100,
                              child: const Icon(Icons.star, color: Colors.amber),
                            ),
                            title: Text(
                              preset['preset_name'] ?? 'Unnamed Preset',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${calories.round()} cal • '
                                  'P: ${protein.round()}g • '
                                  'C: ${carbs.round()}g • '
                                  'F: ${fat.round()}g',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (preset['meal_type'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    preset['meal_type'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Quick Log Button
                                IconButton(
                                  icon: const Icon(Icons.restaurant),
                                  color: Colors.green,
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _logPresetDirectly(preset);
                                  },
                                  tooltip: 'Log now',
                                ),
                                // Edit Button
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  color: Colors.blue,
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _usePreset(preset);
                                  },
                                  tooltip: 'Load & edit',
                                ),
                                // Delete Button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red,
                                  onPressed: () => _deletePreset(preset['id']),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePreset(String presetId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preset?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _apiService.deleteMealPreset(presetId);
        await _loadPresets();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preset deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSaveAsPresetDialog(Map<String, dynamic> nutritionData) {
    final presetNameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Preset?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Save this meal as a preset for quick access later?'),
            const SizedBox(height: 16),
            TextField(
              controller: presetNameController,
              decoration: const InputDecoration(
                hintText: 'Preset name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveAsPreset(nutritionData, presetNameController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsPreset(Map<String, dynamic> nutritionData, String presetName) async {
    try {
      final foodItem = nutritionData['food_item'] ?? _multiLineController.text;
      final name = presetName.isNotEmpty ? presetName : foodItem;
      
      // Extract nutrition values with proper fallback
      final calories = _extractDouble(nutritionData, ['calories']);
      final proteinG = _extractDouble(nutritionData, ['protein_g', 'protein']);
      final carbsG = _extractDouble(nutritionData, ['carbs_g', 'carbs']);
      final fatG = _extractDouble(nutritionData, ['fat_g', 'fat']);
      final fiberG = _extractDouble(nutritionData, ['fiber_g', 'fiber']);
      final sugarG = _extractDouble(nutritionData, ['sugar_g', 'sugar']);
      final sodiumMg = _extractDouble(nutritionData, ['sodium_mg', 'sodium']);
      
      await _apiService.createPreset({
        'user_id': widget.userProfile.id,
        'preset_name': name,
        'food_items': foodItem,
        'meal_type': _selectedMealType,
        'nutrition_data': nutritionData,
        'total_calories': calories,
        'total_protein_g': proteinG,
        'total_carbs_g': carbsG,
        'total_fat_g': fatG,
        'total_fiber_g': fiberG,
        'total_sugar_g': sugarG,
        'total_sodium_mg': sodiumMg,
      });
      
      await _loadPresets();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.star, color: Colors.white),
              SizedBox(width: 8),
              Text('Meal saved as preset!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving preset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving preset: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealHistoryPage(
          userProfile: widget.userProfile,
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadMealsForDate(_selectedDate),
      _loadPresets(),
      _loadRecentMeals(),
    ]);
  }

  void _addFoodItem() {
    if (_multiLineController.text.isNotEmpty) {
      setState(() {
        _foodItems.add({
          'food': _multiLineController.text,
          'quantity': _quantityController.text.isNotEmpty 
            ? _quantityController.text 
            : '1 serving',
        });
        _multiLineController.clear();
        _quantityController.clear();
      });
    }
  }

  Future<void> _logPresetDirectly(Map<String, dynamic> preset) async {
    // Show confirmation bottom sheet with duplicate check
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final calories = _extractDouble(preset, ['total_calories', 'calories']);
        final protein = _extractDouble(preset, ['total_protein_g', 'protein_g', 'protein']);
        final carbs = _extractDouble(preset, ['total_carbs_g', 'carbs_g', 'carbs']);
        final fat = _extractDouble(preset, ['total_fat_g', 'fat_g', 'fat']);
        
        // Check if meal type already logged
        final hasDuplicate = _hasMealTypeLogged(_selectedMealType);
        
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                preset['preset_name'] ?? 'Preset',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (preset['food_items'] != null && preset['food_items'].toString().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    preset['food_items'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              Text(
                '${calories.round()} cal • '
                'P: ${protein.round()}g • '
                'C: ${carbs.round()}g • '
                'F: ${fat.round()}g',
                style: TextStyle(color: Colors.grey[600]),
              ),
              
              // Warning for duplicate meal type
              if (hasDuplicate && DateUtils.isSameDay(_selectedDate, DateTime.now())) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, 
                        color: Colors.orange.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You already logged $_selectedMealType today',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Meal Type Selector
              const Text(
                'Select meal type:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((type) {
                  final isSelected = _selectedMealType == type;
                  final typeLogged = _hasMealTypeLogged(type);
                  
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type),
                        if (typeLogged && type.toLowerCase() != 'snack') ...[
                          const SizedBox(width: 4),
                          Icon(Icons.check_circle, 
                            size: 16, 
                            color: isSelected ? Colors.white : Colors.orange),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedMealType = type;
                      });
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _logPresetDirectly(preset);
                      });
                    },
                    selectedColor: Colors.green,
                    backgroundColor: typeLogged && type.toLowerCase() != 'snack' 
                      ? Colors.orange.shade50 
                      : null,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              // Log Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.restaurant, color: Colors.white),
                  label: Text(
                    'Log as $_selectedMealType',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasDuplicate && DateUtils.isSameDay(_selectedDate, DateTime.now())
                      ? Colors.orange
                      : Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
    
    if (confirmed == true) {
      setState(() => _isAnalyzing = true);
      
      try {
        DateTime mealDateTime;
        final now = DateTime.now();
        
        // Check if selected date is today
        if (_selectedDate.year == now.year &&
            _selectedDate.month == now.month &&
            _selectedDate.day == now.day) {
          // It's today - use actual current time
          mealDateTime = now;
          print('✅ Using current time for today: $mealDateTime');
        } else {
          // It's a past date - use a reasonable time for the meal type
          int hour;
          switch (_selectedMealType.toLowerCase()) {
            case 'breakfast':
              hour = 8;
              break;
            case 'lunch':
              hour = 13;
              break;
            case 'dinner':
              hour = 19;
              break;
            case 'snack':
              hour = 15;
              break;
            default:
              hour = 12;
          }
          
          mealDateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            hour,
            0,
            0,
          );
          print('✅ Using default time for past date: $mealDateTime');
        }

        // Convert local time to UTC before sending to backend (same as weight logging)
        final utcDateTime = mealDateTime.toUtc();

        print('📅 Logging preset - Local time: $mealDateTime');
        print('📅 Logging preset - UTC time: $utcDateTime');

        final response = await _apiService.usePreset(
          preset['id'],
          {
            'meal_type': _selectedMealType,
            'meal_date': utcDateTime.toIso8601String(), 
          },
        );
        
        setState(() => _isAnalyzing = false);
        
        if (response['success'] == true) {
          await _loadMealsForDate(_selectedDate);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${preset['preset_name']} logged as $_selectedMealType!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging preset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTodaysMeals() {
    if (_todaysMeals.isEmpty) return const SizedBox.shrink();
    
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateLabel = isToday ? 'Today\'s Meals' : 'Meals for ${DateFormat('MMM d').format(_selectedDate)}';
    
    if (_todaysMeals.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No meals logged for ${isToday ? "today" : DateFormat('MMM d').format(_selectedDate)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the form above to log a meal',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isToday)
                Text(
                  '${_todaysMeals.length}/$_dailyMealGoal meals',
                  style: TextStyle(
                    color: _todaysMeals.length >= _dailyMealGoal 
                      ? Colors.green 
                      : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  '${_todaysMeals.length} meals',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNutritionProgress(),
          const SizedBox(height: 12),
          ..._todaysMeals.map((meal) {
              final loggedAt = _parseUTCToLocal(meal['logged_at']);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    meal['meal_type']?.substring(0, 1) ?? 'M',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(meal['food_item'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${meal['calories']?.round() ?? 0} cal • ${meal['quantity'] ?? ''}',
                    ),
                    Text(
                      'P: ${(meal['protein_g'] ?? meal['protein'] ?? 0).round()}g • '
                      'C: ${(meal['carbs_g'] ?? meal['carbs'] ?? 0).round()}g • '
                      'F: ${(meal['fat_g'] ?? meal['fat'] ?? 0).round()}g',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(loggedAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'preset') {
                          _saveLoggedMealAsPreset(meal); 
                        } else if (value == 'edit') {
                          _editMeal(meal);
                        } else if (value == 'delete') {
                          _deleteMeal(meal['id']);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'preset',
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_add, size: 20, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Save as Preset'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildNutritionProgress() {
    // Calculate totals from today's meals
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    for (final meal in _todaysMeals) {
      totalCalories += (meal['calories'] ?? 0).toDouble();
      totalProtein += (meal['protein_g'] ?? meal['protein'] ?? 0).toDouble();
      totalCarbs += (meal['carbs_g'] ?? meal['carbs'] ?? 0).toDouble();
      totalFat += (meal['fat_g'] ?? meal['fat'] ?? 0).toDouble();
    }
    
    // Calculate remaining with exercise adjustment
    final remainingCalories = _dailyCalorieGoal - totalCalories + _caloriesBurned;
    
    return Column(
      children: [
        _buildProgressBar('Calories', totalCalories, _dailyCalorieGoal, Colors.orange),
        
        // Show exercise bonus if any
        if (_caloriesBurned > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  '+${_caloriesBurned.round()} cal from exercise • ${remainingCalories.round()} remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMacroChip('Protein', totalProtein, _macroGoals['protein']!, Colors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMacroChip('Carbs', totalCarbs, _macroGoals['carbs']!, Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMacroChip('Fat', totalFat, _macroGoals['fat']!, Colors.yellow.shade700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(String label, double current, double goal, Color color) {
    final percentage = (current / goal).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${current.round()} / ${goal.round()}'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildMacroChip(String label, double current, double goal, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
          Text(
            '${current.round()}g',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '/ ${goal.round()}g',
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_nutritionData == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nutrition Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _nutritionData = null;
                  });
                },
              ),
            ],
          ),
          const Divider(),
          Text(
            _nutritionData!['food_item'] ?? 'Analyzed Meal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientInfo('Calories', 
                '${_nutritionData!['calories']?.round() ?? 0}', 'kcal'),
              _buildNutrientInfo('Protein', 
                '${(_nutritionData!['protein_g'] ?? _nutritionData!['protein'] ?? 0).round()}', 'g'),
              _buildNutrientInfo('Carbs', 
                '${(_nutritionData!['carbs_g'] ?? _nutritionData!['carbs'] ?? 0).round()}', 'g'),
              _buildNutrientInfo('Fat', 
                '${(_nutritionData!['fat_g'] ?? _nutritionData!['fat'] ?? 0).round()}', 'g'),
            ],
          ),
          
          // Micronutrient Highlights Section
          if (_hasMicronutrients()) ...[
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Micronutrient Highlights',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildMicronutrientChips(),
            ),
          ],
          
          if (_nutritionData!['data_source'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Source: ${_nutritionData!['data_source']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  bool _hasMicronutrients() {
    if (_nutritionData == null) return false;
    
    final microKeys = [
      'vitamin_c_mg', 'vitamin_a_mcg', 'vitamin_d_mcg',
      'iron_mg', 'calcium_mg', 'potassium_mg', 'magnesium_mg', 'zinc_mg'
    ];
    
    for (final key in microKeys) {
      final value = _nutritionData![key];
      if (value != null && value is num && value > 0) {
        return true;
      }
    }
    return false;
  }

  List<Widget> _buildMicronutrientChips() {
    final List<Widget> chips = [];
    
    final micronutrients = [
      {'key': 'vitamin_c_mg', 'label': 'Vit C', 'unit': 'mg', 'threshold': 5},
      {'key': 'vitamin_a_mcg', 'label': 'Vit A', 'unit': 'mcg', 'threshold': 50},
      {'key': 'vitamin_d_mcg', 'label': 'Vit D', 'unit': 'mcg', 'threshold': 1},
      {'key': 'iron_mg', 'label': 'Iron', 'unit': 'mg', 'threshold': 1},
      {'key': 'calcium_mg', 'label': 'Calcium', 'unit': 'mg', 'threshold': 30},
      {'key': 'potassium_mg', 'label': 'Potassium', 'unit': 'mg', 'threshold': 100},
      {'key': 'magnesium_mg', 'label': 'Magnesium', 'unit': 'mg', 'threshold': 10},
      {'key': 'zinc_mg', 'label': 'Zinc', 'unit': 'mg', 'threshold': 0.5},
      {'key': 'fiber_g', 'label': 'Fiber', 'unit': 'g', 'threshold': 1},
    ];
    
    for (final micro in micronutrients) {
      final value = _nutritionData![micro['key']];
      if (value != null && value is num && value > (micro['threshold'] as num)) {
        chips.add(_buildMicroChip(
          micro['label'] as String,
          '${value.round()}${micro['unit']}',
        ));
      }
    }
    
    return chips;
  }

  Widget _buildMicroChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.purple.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _editMeal(Map<String, dynamic> meal) {
    setState(() {
      _useMultiLineEntry = true;
      _multiLineController.text = meal['food_item'] ?? '';
      _selectedMealType = meal['meal_type'] ?? _selectedMealType;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meal loaded for editing. Make changes and analyze again.'),
        backgroundColor: Colors.blue,
      ),
    );
    
    // Scroll to top
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  double _extractDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        final value = data[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return 0.0;
  }

  Future<void> _deleteMeal(String mealId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _apiService.deleteMeal(mealId,widget.userProfile.id);
        await _loadMealsForDate(_selectedDate);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMealSuggestions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MealSuggestionsSheet(
        userId: widget.userProfile.id!,
        mealType: _selectedMealType.toLowerCase(),
        onSuggestionSelected: (suggestion) {
          Navigator.pop(context);
          
          // Pre-fill the form with suggestion
          setState(() {
            _useMultiLineEntry = true;
            _multiLineController.text = suggestion['food_item'];
            
            // Optionally pre-fill nutrition data
            _nutritionData = {
              'food_item': suggestion['food_item'],
              'calories': suggestion['calories'],
              'protein_g': suggestion['protein_g'],
              'carbs_g': suggestion['carbs_g'],
              'fat_g': suggestion['fat_g'],
            };
          });
        },
      ),
    );
  }

}