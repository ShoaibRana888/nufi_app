// lib/features/onboarding/screens/dietary_preferences_page.dart
import 'package:flutter/material.dart';

class DietaryPreferencesPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;

  const DietaryPreferencesPage({
    Key? key,
    required this.formData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<DietaryPreferencesPage> createState() => _DietaryPreferencesPageState();
}

class _DietaryPreferencesPageState extends State<DietaryPreferencesPage> {
  List<String> _selectedDiets = [];
  double _waterIntake = 2.0; // Default 2 liters
  int _waterIntakeGlasses = 8;
  bool _useGlasses = true;
  List<String> _medicalConditions = [];
  final _otherMedicalController = TextEditingController();
  int _dailyMealsCount = 3; // NEW: Default to 3 meals
  bool _showValidationErrors = false;

  final List<String> _dietOptions = [
    'No restrictions',
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Gluten-free',
    'Dairy-free',
    'Keto',
    'Paleo',
    'Low carb',
    'Low fat',
    'Mediterranean',
    'Halal',
    'Kosher',
  ];

  final List<String> _commonMedicalConditions = [
    'None',
    'Diabetes',
    'Hypertension',
    'Heart disease',
    'Asthma',
    'Thyroid issues',
    'Food allergies',
    'Digestive disorders',
    'Arthritis',
    'Other (please specify)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.formData['dietaryPreferences'] != null) {
      _selectedDiets = List<String>.from(widget.formData['dietaryPreferences']);
    }
    _waterIntake = widget.formData['waterIntake'] ?? 2.0;
    _waterIntakeGlasses = widget.formData['waterIntakeGlasses'] ?? 8;
    _dailyMealsCount = widget.formData['dailyMealsCount'] ?? 3; // NEW
    if (widget.formData['medicalConditions'] != null) {
      _medicalConditions = List<String>.from(widget.formData['medicalConditions']);
    }
  }

  @override
  void dispose() {
    _otherMedicalController.dispose();
    super.dispose();
  }

  bool _isFieldValid(String fieldName) {
    if (!_showValidationErrors) return true;
    
    switch (fieldName) {
      case 'meals':
        return _dailyMealsCount >= 1 && _dailyMealsCount <= 6;
      case 'dietary':
        return _selectedDiets.isNotEmpty;
      case 'medical':
        return _medicalConditions.isNotEmpty;
      default:
        return true;
    }
  }

  void _updateWaterIntake({double? liters, int? glasses}) {
    setState(() {
      if (liters != null) {
        _waterIntake = liters;
        _waterIntakeGlasses = (liters * 4).round(); // 250ml per glass
      } else if (glasses != null) {
        _waterIntakeGlasses = glasses;
        _waterIntake = glasses / 4.0; // Convert to liters
      }
    });
    
    widget.onDataChanged('waterIntake', _waterIntake);
    widget.onDataChanged('waterIntakeGlasses', _waterIntakeGlasses);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dietary & Health Information',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us about your diet preferences and health conditions.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // NEW: Daily Meals Count Section
          Row(
            children: const [
              Text(
                'How many meals do you typically have per day?',
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
          
          if (!_isFieldValid('meals') && _showValidationErrors)
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
                    'Please select your daily meals count',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Meals',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      '$_dailyMealsCount ${_dailyMealsCount == 1 ? 'meal' : 'meals'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.blue[100],
                    thumbColor: Colors.blue,
                    overlayColor: Colors.blue.withOpacity(0.2),
                    valueIndicatorColor: Colors.blue,
                  ),
                  child: Slider(
                    value: _dailyMealsCount.toDouble(),
                    min: 1,
                    max: 6,
                    divisions: 5,
                    label: _dailyMealsCount.toString(),
                    onChanged: (value) {
                      setState(() {
                        _dailyMealsCount = value.round();
                      });
                      widget.onDataChanged('dailyMealsCount', _dailyMealsCount);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text('6', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getMealCountAdvice(),
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
          
          // Dietary preferences with validation
          Row(
            children: const [
              Text(
                'Dietary Preferences',
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
          
          if (!_isFieldValid('dietary') && _showValidationErrors)
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
                    'Please select at least one dietary preference or "No restrictions"',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dietOptions.map((diet) {
              final isSelected = _selectedDiets.contains(diet);
              return FilterChip(
                label: Text(diet),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (diet == 'No restrictions') {
                        _selectedDiets = ['No restrictions'];
                      } else {
                        _selectedDiets.remove('No restrictions');
                        _selectedDiets.add(diet);
                      }
                    } else {
                      _selectedDiets.remove(diet);
                    }
                    _showValidationErrors = false;
                    }
                  );
                  widget.onDataChanged('dietaryPreferences', _selectedDiets);
                },
                selectedColor: Colors.blue.withOpacity(0.2),
                checkmarkColor: Colors.blue,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          
          // Water intake section with toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Water Intake Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Toggle button
              ToggleButtons(
                borderRadius: BorderRadius.circular(8),
                isSelected: [_useGlasses, !_useGlasses],
                onPressed: (index) {
                  setState(() {
                    _useGlasses = index == 0;
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Glasses'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Liters'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_useGlasses)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _waterIntakeGlasses.toDouble(),
                        min: 4,
                        max: 16,
                        divisions: 12,
                        label: '$_waterIntakeGlasses glasses',
                        onChanged: (value) {
                          _updateWaterIntake(glasses: value.round());
                        },
                      ),
                    ),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_waterIntakeGlasses glasses',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '≈ ${_waterIntake.toStringAsFixed(1)} liters',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _waterIntake,
                        min: 1,
                        max: 4,
                        divisions: 30,
                        label: '${_waterIntake.toStringAsFixed(1)} L',
                        onChanged: (value) {
                          _updateWaterIntake(liters: value);
                        },
                      ),
                    ),
                    Container(
                      width: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_waterIntake.toStringAsFixed(1)} L',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '≈ $_waterIntakeGlasses glasses',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          
          const SizedBox(height: 24),
          
          // Medical conditions with validation
          Row(
            children: const [
              Text(
                'Medical Conditions',
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
            'Select any that apply (important for personalized recommendations)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          
          if (!_isFieldValid('medical') && _showValidationErrors)
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
                    'Please select your medical conditions or "None"',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonMedicalConditions.map((condition) {
              final isSelected = _medicalConditions.contains(condition);
              return FilterChip(
                label: Text(condition),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (condition == 'None') {
                        _medicalConditions = ['None'];
                      } else {
                        _medicalConditions.remove('None');
                        _medicalConditions.add(condition);
                        if (condition == 'Other (please specify)') {
                          _showOtherMedicalDialog();
                        }
                      }
                    } else {
                      _medicalConditions.remove(condition);
                      if (condition == 'Other (please specify)') {
                        _otherMedicalController.clear();
                        widget.onDataChanged('otherMedicalCondition', null);
                      }
                    }
                  });
                  widget.onDataChanged('medicalConditions', _medicalConditions);
                },
                selectedColor: Colors.orange.withOpacity(0.2),
                checkmarkColor: Colors.orange,
              );
            }).toList(),
          ),
          
          if (_medicalConditions.contains('Other (please specify)') && 
              _otherMedicalController.text.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Other: ${_otherMedicalController.text}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
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
  
  String _getMealCountAdvice() {
    switch (_dailyMealsCount) {
      case 1:
        return 'Intermittent fasting or OMAD (One Meal A Day)';
      case 2:
        return 'Time-restricted eating pattern';
      case 3:
        return 'Traditional meal pattern (breakfast, lunch, dinner)';
      case 4:
        return '3 main meals + 1 snack';
      case 5:
        return '3 main meals + 2 snacks';
      case 6:
        return 'Multiple small meals throughout the day';
      default:
        return 'Customize based on your eating pattern';
    }
  }

  void _showOtherMedicalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Other Medical Condition'),
        content: TextField(
          controller: _otherMedicalController,
          decoration: const InputDecoration(
            hintText: 'Please specify...',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _medicalConditions.remove('Other (please specify)');
              });
              widget.onDataChanged('medicalConditions', _medicalConditions);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onDataChanged('otherMedicalCondition', _otherMedicalController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}