// lib/features/home/widgets/daily_meal_card.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/tracking/screens/meal_history_page.dart';
import 'package:user_onboarding/features/tracking/screens/meal_logging_page.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';
import 'package:user_onboarding/data/services/api/exercise_api.dart';
import 'package:intl/intl.dart';

class DailyGoalsCard extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback? onTap;
  final bool isCompact;
  
  const DailyGoalsCard({
    Key? key,
    required this.userProfile,
    this.onTap,
    this.isCompact = false,
  }) : super(key: key);
  
  @override
  State<DailyGoalsCard> createState() => _DailyGoalsCardState();
}

class _DailyGoalsCardState extends State<DailyGoalsCard> {
  late double _dailyCalorieGoal;
  late Map<String, double> _macroGoals;
  late double _userTdee;
  late String _weightGoal;
  late double _currentWeight;
  late String _activityLevel;
  
  // Progress tracking
  Map<String, double> _consumedMacros = {
    'protein': 0.0,
    'carbs': 0.0,
    'fat': 0.0,
    'calories': 0.0,
  };
  
  bool _isLoadingProgress = false;
  double _caloriesBurned = 0;
  final MealApi _apiService = MealApi();
  final ExerciseApi _exerciseApi = ExerciseApi();
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _calculateDailyGoals();
    _loadTodayProgress();
  }
  
  @override
  void didUpdateWidget(DailyGoalsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userProfile != widget.userProfile) {
      _loadUserData();
      _calculateDailyGoals();
      _loadTodayProgress();
      _loadExerciseData();
    }
  }
  
  void _loadUserData() {
    // Get TDEE from user's actual calculated value
    _userTdee = widget.userProfile.tdee ?? 2000.0;
    
    // Get user's actual weight goal
    _weightGoal = widget.userProfile.primaryGoal ?? 'maintain_weight';
    
    // Get user's current weight
    _currentWeight = widget.userProfile.weight ?? 70.0;
    
    // Get activity level
    _activityLevel = widget.userProfile.activityLevel ?? 'moderately_active';
  }
  
  void _calculateDailyGoals() {
    // IMPROVED MACRO CALCULATION LOGIC BASED ON USER GOAL TYPE
    
    double calorieAdjustment = 0;
    Map<String, double> macroPercentages = {};
    
    // Determine goal type and set macro distribution
    switch (_weightGoal.toLowerCase()) {
      case 'lose_weight':
      case 'weight_loss':
        // Weight Loss: Higher protein for muscle preservation
        calorieAdjustment = -500; // 500 calorie deficit
        macroPercentages = {
          'protein': 0.35, // 35% of calories
          'carbs': 0.40,   // 40% of calories  
          'fat': 0.25,     // 25% of calories
        };
        break;
        
      case 'gain_muscle':
      case 'muscle_gain':
      case 'recomposition':
      case 'lose_fat':
        // Recomposition: Highest protein for muscle synthesis
        calorieAdjustment = _weightGoal.contains('gain') ? 200 : -200; // Small surplus or deficit
        macroPercentages = {
          'protein': 0.40, // 40% of calories
          'carbs': 0.35,   // 35% of calories
          'fat': 0.25,     // 25% of calories
        };
        break;
        
      case 'gain_weight':
      case 'weight_gain':
      case 'bulk':
        // Weight Gain: Balanced macros with surplus
        calorieAdjustment = 400; // 400 calorie surplus
        macroPercentages = {
          'protein': 0.25, // 25% of calories
          'carbs': 0.45,   // 45% of calories
          'fat': 0.30,     // 30% of calories
        };
        break;
        
      case 'maintain_weight':
      case 'maintenance':
      default:
        // Maintenance: Balanced approach
        calorieAdjustment = 0;
        macroPercentages = {
          'protein': 0.30, // 30% of calories
          'carbs': 0.40,   // 40% of calories
          'fat': 0.30,     // 30% of calories
        };
        break;
    }
    
    // Adjust for activity level
    if (_activityLevel == 'very_active' || _activityLevel == 'extremely_active') {
      // Increase carbs for very active individuals
      macroPercentages['carbs'] = (macroPercentages['carbs'] ?? 0.40) + 0.05;
      macroPercentages['fat'] = (macroPercentages['fat'] ?? 0.30) - 0.05;
    }
    
    // Calculate daily calorie goal
    _dailyCalorieGoal = _userTdee + calorieAdjustment;
    
    // Calculate macro grams from percentages
    // Protein: 4 cal/g, Carbs: 4 cal/g, Fat: 9 cal/g
    _macroGoals = {
      'protein': (_dailyCalorieGoal * macroPercentages['protein']!) / 4,
      'carbs': (_dailyCalorieGoal * macroPercentages['carbs']!) / 4,
      'fat': (_dailyCalorieGoal * macroPercentages['fat']!) / 9,
    };
    
    // Ensure minimum protein intake (0.8g per kg body weight)
    double minProtein = _currentWeight * 0.8;
    if (_macroGoals['protein']! < minProtein) {
      _macroGoals['protein'] = minProtein;
    }
    
    // For muscle gain/recomp, increase protein to 1g per lb (2.2g per kg)
    if (_weightGoal.contains('muscle') || _weightGoal == 'recomposition') {
      _macroGoals['protein'] = _currentWeight * 2.2;
    }
    
    setState(() {});
  }
  
  Future<void> _loadTodayProgress() async {
    if (widget.userProfile.id == null) return;
    
    setState(() => _isLoadingProgress = true);
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final meals = await _apiService.getMealHistory(
        widget.userProfile.id!,
        date: dateStr,
      );
      
      // Calculate consumed macros
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      double totalCalories = 0;
      
      for (var meal in meals) {
        totalProtein += (meal['protein_g'] ?? meal['protein'] ?? 0).toDouble();
        totalCarbs += (meal['carbs_g'] ?? meal['carbs'] ?? 0).toDouble();
        totalFat += (meal['fat_g'] ?? meal['fat'] ?? 0).toDouble();
        totalCalories += (meal['calories'] ?? 0).toDouble();
      }
      
      setState(() {
        _consumedMacros = {
          'protein': totalProtein,
          'carbs': totalCarbs,
          'fat': totalFat,
          'calories': totalCalories,
        };
        _isLoadingProgress = false;
      });
    } catch (e) {
      print('Error loading today\'s progress: $e');
      setState(() => _isLoadingProgress = false);
    }
  }
  
  String _getInfoText() {
    switch (_weightGoal.toLowerCase()) {
      case 'lose_weight':
      case 'weight_loss':
        return 'High protein (35%) preserves muscle during weight loss. Moderate carbs for energy, lower fat for calorie control.';
      case 'gain_muscle':
      case 'muscle_gain':
      case 'recomposition':
        return 'Very high protein (40%) supports muscle synthesis. Balanced carbs for training, adequate fats for hormones.';
      case 'gain_weight':
      case 'weight_gain':
        return 'Moderate protein with higher carbs (45%) and fats for easier calorie surplus and energy.';
      default:
        return 'Balanced macros for maintaining weight. Adjust based on training intensity and recovery needs.';
    }
  }
  
  Color _getGoalColor() {
    switch (_weightGoal.toLowerCase()) {
      case 'lose_weight':
      case 'weight_loss':
        return Colors.orange;
      case 'gain_muscle':
      case 'muscle_gain':
        return Colors.blue;
      case 'gain_weight':
      case 'weight_gain':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  Future<void> _loadExerciseData() async {
    if (widget.userProfile.id == null) return;
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
  
  Widget _buildMacroTooltip(String macro) {
    String explanation = '';
    IconData icon = Icons.info_outline;
    
    switch (macro.toLowerCase()) {
      case 'protein':
        icon = Icons.fitness_center;
        explanation = _weightGoal.contains('muscle') 
          ? 'Target: 1g per lb body weight for optimal muscle growth and recovery'
          : 'Target: 0.8-1g per lb to preserve muscle mass and increase satiety';
        break;
      case 'carbs':
        icon = Icons.grain;
        explanation = _activityLevel.contains('very') 
          ? 'Higher carbs to fuel your intense training sessions'
          : 'Moderate carbs for sustained energy throughout the day';
        break;
      case 'fat':
        icon = Icons.water_drop;
        explanation = 'Essential for hormone production, vitamin absorption, and overall health. Minimum 0.25g per lb body weight.';
        break;
    }
    
    return Tooltip(
      message: explanation,
      padding: const EdgeInsets.all(12),
      preferBelow: false,
      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.help_outline,
        size: 14,
        color: Colors.grey[600],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final goalColor = _getGoalColor();
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Calorie Goal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [goalColor.withOpacity(0.1), goalColor.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: goalColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_fire_department,
                        color: goalColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Calorie Target',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _dailyCalorieGoal.round().toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: goalColor,
                                ),
                              ),
                              Text(
                                ' kcal',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _weightGoal.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: goalColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TDEE: ${_userTdee.round()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Progress Bar
                if (!_isLoadingProgress) ...[
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_consumedMacros['calories']!.round()} consumed',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          Text(
                            '${(_dailyCalorieGoal - _consumedMacros['calories']!).round()} remaining',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_consumedMacros['calories']! / _dailyCalorieGoal).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _consumedMacros['calories']! > _dailyCalorieGoal 
                              ? Colors.red 
                              : goalColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Macro Targets with Progress
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'MACRO TARGETS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getMacroSplitText(),
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Enhanced Macro Cards with Progress
                Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedMacroCard(
                        'Protein',
                        _macroGoals['protein']?.round() ?? 0,
                        _consumedMacros['protein']?.round() ?? 0,
                        const Color(0xFF4A90E2),
                        Icons.fitness_center,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEnhancedMacroCard(
                        'Carbs',
                        _macroGoals['carbs']?.round() ?? 0,
                        _consumedMacros['carbs']?.round() ?? 0,
                        const Color(0xFFF5A623),
                        Icons.grain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEnhancedMacroCard(
                        'Fats',
                        _macroGoals['fat']?.round() ?? 0,
                        _consumedMacros['fat']?.round() ?? 0,
                        const Color(0xFF9B59B6),
                        Icons.water_drop,
                      ),
                    ),
                  ],
                ),
                
                // Educational Info Section
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getInfoText(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Action Buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EnhancedMealLoggingPage(
                                userProfile: widget.userProfile,
                              ),
                            ),
                          ).then((_) => _loadTodayProgress());
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log Meal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: goalColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MealHistoryPage(
                                userProfile: widget.userProfile,
                              ),
                            ),
                          ).then((_) => _loadTodayProgress());
                        },
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: goalColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEnhancedMacroCard(
    String label,
    int target,
    int consumed,
    Color color,
    IconData icon,
  ) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.5) : 0.0;
    final remaining = target - consumed;
    final isOverConsumed = consumed > target;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverConsumed ? Colors.red.withOpacity(0.3) : color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              _buildMacroTooltip(label),
            ],
          ),
          const SizedBox(height: 8),
          
          // Target amount
          Text(
            '${target}g',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          
          // Progress bar
          const SizedBox(height: 6),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress > 1.0 ? 1.0 : progress,
                minHeight: 4,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverConsumed ? Colors.red : color,
                ),
              ),
            ),
          ),
          
          // Consumed/Remaining
          const SizedBox(height: 4),
          Text(
            isOverConsumed 
              ? '+${(-remaining)}g over'
              : '${consumed}g / ${remaining}g left',
            style: TextStyle(
              fontSize: 9,
              color: isOverConsumed ? Colors.red : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getMacroSplitText() {
    final proteinPct = ((_macroGoals['protein']! * 4) / _dailyCalorieGoal * 100).round();
    final carbsPct = ((_macroGoals['carbs']! * 4) / _dailyCalorieGoal * 100).round();
    final fatPct = ((_macroGoals['fat']! * 9) / _dailyCalorieGoal * 100).round();
    
    return '${proteinPct}P/${carbsPct}C/${fatPct}F';
  }

}