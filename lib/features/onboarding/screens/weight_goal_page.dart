// lib/features/onboarding/screens/weight_goal_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WeightGoalPage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;

  const WeightGoalPage({
    Key? key,
    required this.formData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<WeightGoalPage> createState() => _WeightGoalPageState();
}

class _WeightGoalPageState extends State<WeightGoalPage> {
  String _selectedWeightGoal = '';
  final _targetWeightController = TextEditingController();
  String _selectedTimeline = '';
  String? _weightError;
  late double _currentWeight;
  bool _showValidationErrors = false;

  final List<Map<String, dynamic>> _weightGoals = [
    {
      'id': 'lose_weight',
      'title': 'Lose Weight',
      'description': 'Reduce body weight',
      'icon': Icons.trending_down,
      'color': Colors.red,
    },
    {
      'id': 'maintain_weight',
      'title': 'Maintain Weight',
      'description': 'Keep current weight',
      'icon': Icons.horizontal_rule,
      'color': Colors.blue,
    },
    {
      'id': 'gain_weight',
      'title': 'Gain Weight',
      'description': 'Increase body weight',
      'icon': Icons.trending_up,
      'color': Colors.green,
    },
  ];

  final List<Map<String, String>> _timelines = [
    {'id': '4_weeks', 'title': '4 weeks', 'description': 'Quick results'},
    {'id': '8_weeks', 'title': '8 weeks', 'description': 'Moderate pace'},
    {'id': '12_weeks', 'title': '12 weeks', 'description': 'Recommended'},
    {'id': '16_weeks', 'title': '16 weeks', 'description': 'Steady progress'},
    {'id': '24_weeks', 'title': '6 months', 'description': 'Sustainable'},
  ];

  @override
  void initState() {
    super.initState();
    _currentWeight = widget.formData['weight'] ?? 70.0;
    _selectedWeightGoal = widget.formData['weightGoal'] ?? '';
    _selectedTimeline = widget.formData['goalTimeline'] ?? '';
    
    if (widget.formData['targetWeight'] != null && 
        widget.formData['targetWeight'] != 0.0) {
      _targetWeightController.text = widget.formData['targetWeight'].toString();
    }
  }

  bool _isFieldValid(String fieldName) {
    if (!_showValidationErrors) return true;
    
    switch (fieldName) {
      case 'goal':
        return _selectedWeightGoal.isNotEmpty;
      case 'target':
        if (_selectedWeightGoal == 'maintain_weight') return true;
        return _targetWeightController.text.isNotEmpty && _validateTargetWeight();
      case 'timeline':
        return _selectedTimeline.isNotEmpty;
      default:
        return true;
    }
  }

  bool _validateTargetWeight() {
    if (_selectedWeightGoal == 'maintain_weight') return true;
    
    double? targetWeight = double.tryParse(_targetWeightController.text);
    if (targetWeight == null) return false;
    
    if (_selectedWeightGoal == 'lose_weight') {
      return targetWeight < _currentWeight && targetWeight > _currentWeight * 0.5;
    } else if (_selectedWeightGoal == 'gain_weight') {
      return targetWeight > _currentWeight && targetWeight < _currentWeight * 1.5;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What\'s your weight goal?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your current weight: ${_currentWeight.toStringAsFixed(2)} kg',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Weight Goal Selection with validation
          Row(
            children: const [
              Text(
                'Select your goal',
                style: TextStyle(
                  fontSize: 16,
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
          
          if (!_isFieldValid('goal') && _showValidationErrors)
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
                    'Please select a weight goal',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          ...List.generate(_weightGoals.length, (index) {
            final goal = _weightGoals[index];
            final isSelected = _selectedWeightGoal == goal['id'];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedWeightGoal = goal['id'];
                    _showValidationErrors = false;
                    
                    // Auto-set target weight for maintain
                    if (goal['id'] == 'maintain_weight') {
                      _targetWeightController.text = _currentWeight.toString();
                      widget.onDataChanged('targetWeight', _currentWeight);
                    } else {
                      _targetWeightController.clear();
                      widget.onDataChanged('targetWeight', 0.0);
                    }
                  });
                  widget.onDataChanged('weightGoal', goal['id']);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (goal['color'] as Color).withOpacity(0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? goal['color'] as Color
                          : (!_isFieldValid('goal') && _showValidationErrors 
                              ? Colors.red[300]! 
                              : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (goal['color'] as Color).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          goal['icon'] as IconData,
                          color: goal['color'] as Color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? goal['color'] as Color : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              goal['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: goal['color'] as Color,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          // Target Weight Input (show only if not maintaining)
          if (_selectedWeightGoal.isNotEmpty && _selectedWeightGoal != 'maintain_weight') ...[
            const SizedBox(height: 24),
            Row(
              children: const [
                Text(
                  'Target Weight (kg)',
                  style: TextStyle(
                    fontSize: 16,
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
            TextField(
              controller: _targetWeightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow up to 2 decimals
              ],
              decoration: InputDecoration(
                hintText: _selectedWeightGoal == 'lose_weight' 
                    ? 'Enter weight less than ${_currentWeight.toStringAsFixed(2)} kg'
                    : 'Enter weight more than ${_currentWeight.toStringAsFixed(2)} kg',
                prefixIcon: const Icon(Icons.fitness_center),
                suffixText: 'kg',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: (!_isFieldValid('target') && _showValidationErrors)
                        ? Colors.red[300]!
                        : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: (!_isFieldValid('target') && _showValidationErrors)
                        ? Colors.red
                        : Colors.blue,
                    width: 2,
                  ),
                ),
                errorText: (!_isFieldValid('target') && _showValidationErrors)
                    ? _getTargetWeightError()
                    : null,
              ),
              onChanged: (value) {
                double? target = double.tryParse(value);
                widget.onDataChanged('targetWeight', target ?? 0.0);
                if (_showValidationErrors) {
                  setState(() {});
                }
              },
            ),
            
            // Weight difference indicator
            if (_targetWeightController.text.isNotEmpty && _validateTargetWeight())
              Container(
                margin: const EdgeInsets.only(top: 12),
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
                        _getWeightChangeMessage(),
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
          
          // Timeline Selection
          if (_selectedWeightGoal.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: const [
                Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 16,
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
            Text(
              'Choose a realistic timeline for your goal',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            
            if (!_isFieldValid('timeline') && _showValidationErrors)
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
                      'Please select a timeline',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timelines.map((timeline) {
                final isSelected = _selectedTimeline == timeline['id'];
                final isRecommended = timeline['id'] == '12_weeks';
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeline = timeline['id']!;
                      _showValidationErrors = false;
                    });
                    widget.onDataChanged('goalTimeline', timeline['id']);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.blue
                            : (!_isFieldValid('timeline') && _showValidationErrors
                                ? Colors.red[300]!
                                : Colors.grey[300]!),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeline['title']!,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            if (isRecommended) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'RECOMMENDED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          timeline['description']!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getTargetWeightError() {
    if (_targetWeightController.text.isEmpty) {
      return 'Target weight is required';
    }
    
    double? target = double.tryParse(_targetWeightController.text);
    if (target == null) {
      return 'Please enter a valid number';
    }
    
    if (_selectedWeightGoal == 'lose_weight' && target >= _currentWeight) {
      return 'Target must be less than current weight';
    } else if (_selectedWeightGoal == 'gain_weight' && target <= _currentWeight) {
      return 'Target must be more than current weight';
    } else if ((target - _currentWeight).abs() / _currentWeight > 0.5) {
      return 'Please set a more realistic target (less than 50% change)';
    }
    
    return '';
  }

  String _getWeightChangeMessage() {
    double target = double.tryParse(_targetWeightController.text) ?? _currentWeight;
    double difference = (target - _currentWeight).abs();
    String action = _selectedWeightGoal == 'lose_weight' ? 'lose' : 'gain';
    
    return 'You want to $action ${difference.toStringAsFixed(2)} kg. '
           'Healthy rate is 0.5-1 kg per week.';
  }
  
  void validateFields() {
    setState(() {
      _showValidationErrors = true;
    });
  }
}