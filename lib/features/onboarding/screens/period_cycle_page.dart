// lib/features/onboarding/screens/period_cycle_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PeriodCyclePage extends StatefulWidget {
  final Map<String, dynamic> formData;
  final Function(String, dynamic) onDataChanged;

  const PeriodCyclePage({
    Key? key,
    required this.formData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<PeriodCyclePage> createState() => _PeriodCyclePageState();
}

class _PeriodCyclePageState extends State<PeriodCyclePage> {
  bool? _hasPeriods;
  DateTime? _lastPeriodDate;
  int _cycleLength = 28;
  int _periodLength = 5;
  bool? _isCycleRegular;
  String _pregnancyStatus = '';
  String _trackingPreference = '';
  bool _showValidationErrors = false;

  final List<Map<String, dynamic>> _pregnancyOptions = [
    {'id': 'not_pregnant', 'title': 'Not Pregnant', 'icon': Icons.close, 'color': Colors.blue},
    {'id': 'pregnant', 'title': 'Pregnant', 'icon': Icons.child_care, 'color': Colors.pink},
    {'id': 'trying', 'title': 'Trying to Conceive', 'icon': Icons.favorite, 'color': Colors.red},
    {'id': 'postpartum', 'title': 'Postpartum', 'icon': Icons.baby_changing_station, 'color': Colors.purple},
  ];

  final List<Map<String, dynamic>> _trackingOptions = [
    {'id': 'detailed', 'title': 'Detailed Tracking', 'description': 'Track symptoms, mood, and more', 'icon': Icons.analytics},
    {'id': 'none', 'title': 'No Tracking', 'description': 'Don\'t track periods', 'icon': Icons.block},
  ];

  @override
  void initState() {
    super.initState();
    _hasPeriods = widget.formData['hasPeriods'];
    if (widget.formData['lastPeriodDate'] != null && widget.formData['lastPeriodDate'] != '') {
      try {
        _lastPeriodDate = DateTime.parse(widget.formData['lastPeriodDate']);
      } catch (e) {
        _lastPeriodDate = null;
      }
    }
    _cycleLength = widget.formData['cycleLength'] ?? 28;
    _periodLength = widget.formData['periodLength'] ?? 5;
    _isCycleRegular = widget.formData['cycleLengthRegular'];
    _pregnancyStatus = widget.formData['pregnancyStatus'] ?? '';
    _trackingPreference = widget.formData['trackingPreference'] ?? '';
  }

  bool _isFieldValid(String fieldName) {
    if (!_showValidationErrors) return true;
    
    switch (fieldName) {
      case 'hasPeriods':
        return _hasPeriods != null;
      case 'lastPeriod':
        return _hasPeriods != true || _lastPeriodDate != null;
      case 'cycleRegular':
        return _hasPeriods != true || _isCycleRegular != null;
      case 'pregnancy':
        return _pregnancyStatus.isNotEmpty;
      case 'tracking':
        return _trackingPreference.isNotEmpty;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Period & Cycle Tracking',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This helps us provide personalized health insights and reminders.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // Do you have periods?
          Row(
            children: const [
              Text(
                'Do you have regular periods?',
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
          
          if (!_isFieldValid('hasPeriods') && _showValidationErrors)
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
                    'Please select an option',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasPeriods = true;
                      _showValidationErrors = false;
                    });
                    widget.onDataChanged('hasPeriods', true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _hasPeriods == true ? Colors.pink.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasPeriods == true 
                            ? Colors.pink 
                            : (!_isFieldValid('hasPeriods') && _showValidationErrors
                                ? Colors.red[300]!
                                : Colors.grey[300]!),
                        width: _hasPeriods == true ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _hasPeriods == true ? Colors.pink : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasPeriods = false;
                      _showValidationErrors = false;
                      // Clear period-related fields
                      _lastPeriodDate = null;
                      _isCycleRegular = null;
                    });
                    widget.onDataChanged('hasPeriods', false);
                    widget.onDataChanged('lastPeriodDate', '');
                    widget.onDataChanged('cycleLengthRegular', null);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _hasPeriods == false ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasPeriods == false 
                            ? Colors.blue 
                            : (!_isFieldValid('hasPeriods') && _showValidationErrors
                                ? Colors.red[300]!
                                : Colors.grey[300]!),
                        width: _hasPeriods == false ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cancel,
                          color: _hasPeriods == false ? Colors.blue : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Show additional fields if user has periods
          if (_hasPeriods == true) ...[
            const SizedBox(height: 24),
            
            // Last Period Date
            Row(
              children: const [
                Text(
                  'When did your last period start?',
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
            
            if (!_isFieldValid('lastPeriod') && _showValidationErrors)
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
                      'Please select the date',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
            
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _lastPeriodDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _lastPeriodDate = picked;
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('lastPeriodDate', picked.toIso8601String());
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_isFieldValid('lastPeriod') && _showValidationErrors
                        ? Colors.red[300]!
                        : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _lastPeriodDate != null ? Colors.pink : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _lastPeriodDate != null
                          ? DateFormat('MMMM d, yyyy').format(_lastPeriodDate!)
                          : 'Select date',
                      style: TextStyle(
                        fontSize: 16,
                        color: _lastPeriodDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Cycle Length
            const Text(
              'Average cycle length (days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$_cycleLength days',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
                    ),
                  ),
                  Slider(
                    value: _cycleLength.toDouble(),
                    min: 21,
                    max: 35,
                    divisions: 14,
                    activeColor: Colors.pink,
                    inactiveColor: Colors.pink[100],
                    onChanged: (value) {
                      setState(() {
                        _cycleLength = value.round();
                      });
                      widget.onDataChanged('cycleLength', _cycleLength);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('21', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('28 (average)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('35', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Period Length (NEW SECTION)
            const Text(
              'Average period length (days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
              
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$_periodLength days',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  Slider(
                    value: _periodLength.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    activeColor: Colors.orange,
                    inactiveColor: Colors.red[100],
                    onChanged: (value) {
                      setState(() {
                        _periodLength = value.round();
                      });
                      widget.onDataChanged('periodLength', _periodLength);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('2', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('5 (average)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('10', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
              
            const SizedBox(height: 24),
            
            // Is cycle regular?
            Row(
              children: const [
                Text(
                  'Is your cycle regular?',
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
            
            if (!_isFieldValid('cycleRegular') && _showValidationErrors)
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
                      'Please select an option',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ),
              ),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCycleRegular = true;
                        _showValidationErrors = false;
                      });
                      widget.onDataChanged('cycleLengthRegular', true);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isCycleRegular == true ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCycleRegular == true 
                              ? Colors.green 
                              : (!_isFieldValid('cycleRegular') && _showValidationErrors
                                  ? Colors.red[300]!
                                  : Colors.grey[300]!),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Regular',
                          style: TextStyle(
                            fontWeight: _isCycleRegular == true ? FontWeight.bold : FontWeight.normal,
                            color: _isCycleRegular == true ? Colors.green : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCycleRegular = false;
                        _showValidationErrors = false;
                      });
                      widget.onDataChanged('cycleLengthRegular', false);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isCycleRegular == false ? Colors.orange[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCycleRegular == false 
                              ? Colors.orange 
                              : (!_isFieldValid('cycleRegular') && _showValidationErrors
                                  ? Colors.red[300]!
                                  : Colors.grey[300]!),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Irregular',
                          style: TextStyle(
                            fontWeight: _isCycleRegular == false ? FontWeight.bold : FontWeight.normal,
                            color: _isCycleRegular == false ? Colors.orange : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Pregnancy Status
          Row(
            children: const [
              Text(
                'Pregnancy Status',
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
          
          if (!_isFieldValid('pregnancy') && _showValidationErrors)
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
                    'Please select your pregnancy status',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _pregnancyOptions.length,
            itemBuilder: (context, index) {
              final option = _pregnancyOptions[index];
              final isSelected = _pregnancyStatus == option['id'];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _pregnancyStatus = option['id'] as String;
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('pregnancyStatus', option['id']);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (option['color'] as Color).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? option['color'] as Color
                          : (!_isFieldValid('pregnancy') && _showValidationErrors
                              ? Colors.red[300]!
                              : Colors.grey[300]!),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option['icon'] as IconData,
                        size: 28,
                        color: isSelected ? option['color'] as Color : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? option['color'] as Color : Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Tracking Preference
          Row(
            children: const [
              Text(
                'Period Tracking Preference',
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
          
          if (!_isFieldValid('tracking') && _showValidationErrors)
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
                    'Please select your tracking preference',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          
          ...List.generate(_trackingOptions.length, (index) {
            final option = _trackingOptions[index];
            final isSelected = _trackingPreference == option['id'];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _trackingPreference = option['id'] as String;
                    _showValidationErrors = false;
                  });
                  widget.onDataChanged('trackingPreference', option['id']);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.purple.withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.purple
                          : (!_isFieldValid('tracking') && _showValidationErrors
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
                          color: isSelected 
                              ? Colors.purple.withOpacity(0.2)
                              : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          option['icon'] as IconData,
                          color: isSelected ? Colors.purple : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option['title'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.purple : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              option['description'] as String,
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
                          color: Colors.purple,
                          size: 24,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          
          // Privacy Notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your period and health data is private and secure. We use this information only to provide personalized health insights.',
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
    );
  }
  
  void validateFields() {
    setState(() {
      _showValidationErrors = true;
    });
  }
}