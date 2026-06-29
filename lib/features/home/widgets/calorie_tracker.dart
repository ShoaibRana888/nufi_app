// lib/features/home/widgets/calorie_tracker.dart

import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/data_manager.dart';

class CalorieTracker extends StatefulWidget {
  final UserProfile userProfile;
  
  const CalorieTracker({
    Key? key,
    required this.userProfile,
  }) : super(key: key);
  
  @override
  State<CalorieTracker> createState() => _CalorieTrackerState();
}

class _CalorieTrackerState extends State<CalorieTracker> {
  late int _calorieGoal;
  late int _caloriesConsumed;
  late int _caloriesBurned;
  late double _carbs;
  late double _protein;
  late double _fat;
  
  // Add meal tracking state
  final List<Map<String, dynamic>> _meals = [];
  bool _isAddingMeal = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  void _loadData() {
    // Calculate calorie goal based on TDEE
    final tdee = widget.userProfile.formData['tdee'] as double? ?? 2000.0;
    
    // Set calorie goal based on user's weight goal
    if (widget.userProfile.weightGoal.toLowerCase().contains('lose')) {
      _calorieGoal = (tdee * 0.8).round(); // 20% deficit for weight loss
    } else if (widget.userProfile.weightGoal.toLowerCase().contains('gain')) {
      _calorieGoal = (tdee * 1.1).round(); // 10% surplus for weight gain
    } else {
      _calorieGoal = tdee.round(); // Maintenance
    }
    
    // In a real app, you would load the user's saved meals and exercise data
    // For now, initialize with default values
    _caloriesConsumed = 0;
    _caloriesBurned = 0;
    
    // Initialize macros (these would come from the database in a real app)
    _carbs = 0.45; // 45% of calories from carbs
    _protein = 0.30; // 30% from protein
    _fat = 0.25; // 25% from fat
    
    // Load sample meals (in a real app, these would come from the database)
    // _loadMeals();
  }
  
  void _loadMeals() {
    // In a real app, this would load meals from a database
    // For now, we'll use sample data
    _meals.clear();
    
    // Sample meals
    _meals.addAll([
      {
        'name': 'Breakfast',
        'description': 'Oatmeal with banana and honey',
        'calories': 350,
        'time': '7:30 AM',
      },
      {
        'name': 'Lunch',
        'description': 'Grilled chicken salad',
        'calories': 450,
        'time': '12:30 PM',
      },
    ]);
    
    // Calculate consumed calories
    _caloriesConsumed = _meals.fold(0, (sum, meal) => sum + (meal['calories'] as int));
  }
  
  void _showAddMealDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final caloriesController = TextEditingController();
    final timeController = TextEditingController(text: _getCurrentTime());
    
    setState(() {
      _isAddingMeal = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Meal'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Meal Name',
                  hintText: 'e.g., Breakfast, Lunch, Snack',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Oatmeal with banana',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  hintText: 'e.g., 350',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: 'e.g., 7:30 AM',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isAddingMeal = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Validate inputs
              if (nameController.text.isEmpty || 
                  caloriesController.text.isEmpty ||
                  int.tryParse(caloriesController.text) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields correctly'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final newMeal = {
                'name': nameController.text,
                'description': descriptionController.text,
                'calories': int.parse(caloriesController.text),
                'time': timeController.text,
              };
              
              setState(() {
                _meals.add(newMeal);
                _caloriesConsumed += newMeal['calories'] as int;
                _isAddingMeal = false;
              });
              
              // In a real app, you would save this to the database
              _saveMealData();
              
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  Future<void> _saveMealData() async {
    // In a real app, you would save the meals to the database
    // For now, we'll just print them
    print('Saving meals: $_meals');
    
    // You could store this in your UserProfile model, or in a separate collection
  }
  
  @override
  Widget build(BuildContext context) {
    final caloriesRemaining = _calorieGoal - _caloriesConsumed + _caloriesBurned;
    final consumedPercentage = (_caloriesConsumed / _calorieGoal).clamp(0.0, 1.0);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calories',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: caloriesRemaining >= 0 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  caloriesRemaining >= 0 
                      ? '$caloriesRemaining remaining'
                      : '${caloriesRemaining.abs()} over',
                  style: TextStyle(
                    color: caloriesRemaining >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Calorie bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Goal: $_calorieGoal',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Consumed: $_caloriesConsumed',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  // Background progress bar
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Consumed progress
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 10,
                    width: MediaQuery.of(context).size.width * 0.86 * consumedPercentage,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: caloriesRemaining >= 0 
                            ? [Colors.blue.shade300, Colors.blue.shade600]
                            : [Colors.orange.shade300, Colors.red.shade600],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Macros section
          const Text(
            'Macronutrients',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroCircle('Carbs', _carbs, Colors.blue),
              _buildMacroCircle('Protein', _protein, Colors.red),
              _buildMacroCircle('Fat', _fat, Colors.yellow.shade800),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                'Food',
                _caloriesConsumed.toString(),
                Icons.restaurant,
                Colors.orange,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildStatColumn(
                'Goal',
                _calorieGoal.toString(),
                Icons.flag,
                Colors.green,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildStatColumn(
                'Remaining',
                caloriesRemaining.toString(),
                Icons.calculate,
                caloriesRemaining >= 0 ? Colors.blue : Colors.red,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Meal List
          if (_meals.isNotEmpty) ...[
            const Text(
              'Today\'s Meals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_meals.length, (index) {
              final meal = _meals[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                meal['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${meal['calories']} cal',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            meal['description'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            meal['time'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.grey),
                      onPressed: () {
                        // Remove meal
                        setState(() {
                          _caloriesConsumed -= meal['calories'] as int;
                          _meals.removeAt(index);
                        });
                        // Save changes
                        _saveMealData();
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          
          // Add meal button
          Center(
            child: _isAddingMeal
                ? const CircularProgressIndicator()
                : OutlinedButton.icon(
                    onPressed: _showAddMealDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Meal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMacroCircle(String label, double percentage, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 70,
              width: 70,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 8,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '${(percentage * 100).toInt()}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}