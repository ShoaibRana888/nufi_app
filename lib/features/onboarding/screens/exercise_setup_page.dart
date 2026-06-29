// lib/features/onboarding/screens/exercise_setup_page.dart
import 'package:flutter/material.dart';

class CurrentExerciseSetupPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;

  const CurrentExerciseSetupPage({
    Key? key,
    required this.formData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<CurrentExerciseSetupPage> createState() => _CurrentExerciseSetupPageState();
}

class _CurrentExerciseSetupPageState extends State<CurrentExerciseSetupPage> {
  String _workoutLocation = '';
  List<String> _availableEquipment = [];
  String _fitnessLevel = 'Beginner';
  bool _hasTrainer = false;
  int _dailyStepGoal = 10000;
  final TextEditingController _stepGoalController = TextEditingController();
  bool _showValidationErrors = false;

  final List<Map<String, dynamic>> _locationOptions = [
    {
      'title': 'Gym',
      'description': 'Commercial gym or fitness center',
      'icon': Icons.fitness_center,
    },
    {
      'title': 'Home',
      'description': 'Working out in your living space',
      'icon': Icons.home,
    },
    {
      'title': 'Outdoors',
      'description': 'Parks, trails, or outdoor spaces',
      'icon': Icons.park,
    },
    {
      'title': 'Office',
      'description': 'Workplace gym or during breaks',
      'icon': Icons.work,
    },
    {
      'title': 'Studio',
      'description': 'Specialized fitness studios',
      'icon': Icons.storefront,
    },
  ];

  final List<String> _equipmentOptions = [
    'Dumbbells',
    'Barbell & Plates',
    'Resistance bands',
    'Kettlebells',
    'Cardio machines',
    'Yoga mat',
    'Pull-up bar',
    'Bench',
    'TRX/Suspension trainer',
    'Medicine ball',
    'None',
  ];

  final List<String> _fitnessLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  final List<int> _presetStepGoals = [
    5000,
    7500,
    10000,
    12500,
    15000,
  ];

  @override
  void initState() {
    super.initState();
    _workoutLocation = widget.formData['workoutLocation'] ?? '';
    if (widget.formData['availableEquipment'] != null) {
      _availableEquipment = List<String>.from(widget.formData['availableEquipment']);
    }
    _fitnessLevel = widget.formData['fitnessLevel'] ?? 'Beginner';
    _hasTrainer = widget.formData['hasTrainer'] ?? false;
    _dailyStepGoal = widget.formData['dailyStepGoal'] ?? 10000;
    _stepGoalController.text = _dailyStepGoal.toString();
  }

  @override
  void dispose() {
    _stepGoalController.dispose();
    super.dispose();
  }

  bool _isFieldValid(String fieldName) {
    if (!_showValidationErrors) return true;
    
    switch (fieldName) {
      case 'location':
        return _workoutLocation.isNotEmpty;
      case 'equipment':
        return _availableEquipment.isNotEmpty;
      case 'fitness':
        return _fitnessLevel.isNotEmpty;
      case 'trainer':
        return true; // Has default value
      case 'stepGoal':
        return _dailyStepGoal >= 1000 && _dailyStepGoal <= 50000;
      default:
        return true;
    }
  }

  String _getStepGoalDescription(int steps) {
    if (steps < 5000) return 'Light activity';
    if (steps < 7500) return 'Somewhat active';
    if (steps < 10000) return 'Active';
    if (steps < 12500) return 'Very active';
    return 'Highly active';
  }

  Color _getStepGoalColor(int steps) {
    if (steps < 5000) return Colors.orange;
    if (steps < 7500) return Colors.amber;
    if (steps < 10000) return Colors.lightGreen;
    if (steps < 12500) return Colors.green;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Exercise & Activity Setup',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us about your exercise routine and daily activity goals.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Daily Step Goal Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getStepGoalColor(_dailyStepGoal).withOpacity(0.1),
                  _getStepGoalColor(_dailyStepGoal).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !_isFieldValid('stepGoal') && _showValidationErrors
                    ? Colors.red
                    : _getStepGoalColor(_dailyStepGoal).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.directions_walk,
                      color: _getStepGoalColor(_dailyStepGoal),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Daily Step Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' *',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (!_isFieldValid('stepGoal') && _showValidationErrors)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Please set a step goal between 1,000 and 50,000',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                
                // Display current goal
                Center(
                  child: Column(
                    children: [
                      Text(
                        _dailyStepGoal.toString(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _getStepGoalColor(_dailyStepGoal),
                        ),
                      ),
                      Text(
                        'steps per day',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStepGoalColor(_dailyStepGoal).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStepGoalDescription(_dailyStepGoal),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStepGoalColor(_dailyStepGoal),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Preset goals
                const Text(
                  'Quick select:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _presetStepGoals.map((goal) {
                    final isSelected = _dailyStepGoal == goal;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _dailyStepGoal = goal;
                          _stepGoalController.text = goal.toString();
                          _showValidationErrors = false;
                        });
                        widget.onDataChanged('dailyStepGoal', goal);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? _getStepGoalColor(goal)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${(goal / 1000).toStringAsFixed(goal % 1000 == 0 ? 0 : 1)}k',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Custom input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stepGoalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Custom goal',
                          hintText: 'Enter your step goal',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.edit),
                        ),
                        onChanged: (value) {
                          final goal = int.tryParse(value);
                          if (goal != null && goal > 0) {
                            setState(() {
                              _dailyStepGoal = goal;
                              _showValidationErrors = false;
                            });
                            widget.onDataChanged('dailyStepGoal', goal);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The WHO recommends at least 10,000 steps per day for general health. Adjust based on your fitness level and goals.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Workout location
          Row(
            children: const [
              Text(
                'Where do you usually workout?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (!_isFieldValid('location') && _showValidationErrors)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Please select where you workout',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _locationOptions.length,
            itemBuilder: (context, index) {
              final location = _locationOptions[index];
              final isSelected = _workoutLocation == location['title'];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _workoutLocation = location['title'];
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('workoutLocation', location['title']);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.blue
                          : (!_isFieldValid('location') && _showValidationErrors
                              ? Colors.red[300]!
                              : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        location['icon'],
                        color: isSelected ? Colors.blue : Colors.grey[700],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        location['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        location['description'],
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.blue[700] : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Available equipment
          Row(
            children: const [
              Text(
                'What equipment do you have access to?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select all that apply',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          
          if (!_isFieldValid('equipment') && _showValidationErrors)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Please select your available equipment or "None"',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipmentOptions.map((equipment) {
              final isSelected = _availableEquipment.contains(equipment);
              return FilterChip(
                label: Text(equipment),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (equipment == 'None') {
                        _availableEquipment = ['None'];
                      } else {
                        _availableEquipment.remove('None');
                        _availableEquipment.add(equipment);
                      }
                    } else {
                      _availableEquipment.remove(equipment);
                    }
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('availableEquipment', _availableEquipment);
                },
                selectedColor: Colors.blue.withOpacity(0.2),
                checkmarkColor: Colors.blue,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: !_isFieldValid('equipment') && _showValidationErrors
                        ? Colors.red[300]!
                        : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          // Fitness level
          Row(
            children: const [
              Text(
                'What\'s your current fitness level?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (!_isFieldValid('fitness') && _showValidationErrors)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Please select your fitness level',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          Row(
            children: _fitnessLevels.map((level) {
              final isSelected = _fitnessLevel == level;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _fitnessLevel = level;
                        _showValidationErrors = false;
                      });
                      widget.onDataChanged('fitnessLevel', level);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_isFieldValid('fitness') && _showValidationErrors
                              ? Colors.red[300]!
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            level == 'Beginner' ? Icons.star_border :
                            level == 'Intermediate' ? Icons.star_half :
                            Icons.star,
                            color: isSelected ? Colors.white : Colors.grey[700],
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            level,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          // Trainer option
          Row(
            children: const [
              Text(
                'Do you work with a personal trainer?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasTrainer = true;
                    });
                    widget.onDataChanged('hasTrainer', true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _hasTrainer ? Colors.green : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _hasTrainer ? Colors.white : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Yes',
                          style: TextStyle(
                            color: _hasTrainer ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasTrainer = false;
                    });
                    widget.onDataChanged('hasTrainer', false);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !_hasTrainer ? Colors.red : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel,
                          color: !_hasTrainer ? Colors.white : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No',
                          style: TextStyle(
                            color: !_hasTrainer ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void validateFields() {
    setState(() {
      _showValidationErrors = true;
    });
  }
}