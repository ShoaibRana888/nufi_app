// lib/features/profile/screens/edit_profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:user_onboarding/providers/user_provider.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfile userProfile;

  const EditProfilePage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info Controllers
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _targetWeightController;

  // Phase 1 Controllers - Daily Targets
  late TextEditingController _dailyStepGoalController;
  late TextEditingController _sleepHoursController;
  late TextEditingController _waterIntakeLitersController;
  late TextEditingController _waterIntakeGlassesController;
  late TextEditingController _workoutFrequencyController;
  late TextEditingController _workoutDurationController;

  // Phase 2
  late TextEditingController _bedtimeController;
  late TextEditingController _wakeupTimeController;
  List<String> _selectedSleepIssues = [];
  List<String> _selectedDietaryPreferences = [];
  List<String> _selectedWorkoutTypes = [];
  String _selectedWorkoutLocation = 'Gym';

  //Phase 3
  List<String> _selectedMedicalConditions = [];
  TextEditingController _otherMedicalConditionController = TextEditingController();
  List<String> _selectedEquipment = [];
  bool _hasTrainer = false;
  bool? _hasPeriods;
  String _pregnancyStatus = '';
  String _periodTrackingPreference = '';
  int _cycleLength = 28;
  bool _cycleLengthRegular = true;

  // Dropdown selections
  late String _selectedActivityLevel;
  late String _selectedPrimaryGoal;
  late String _selectedWeightGoal;
  late String _selectedGoalTimeline;
  late String _selectedFitnessLevel;

  bool _isSaving = false;
  String? _errorMessage;
  
  // Calculated values
  double _bmi = 0.0;
  double _bmr = 0.0;
  double _tdee = 0.0;

  

  // Activity level options
  final List<String> _activityLevelOptions = [
    'sedentary',
    'lightly_active',
    'moderately_active',
    'very_active',
    'extra_active',
  ];

  // Activity level display names
  final Map<String, String> _activityLevelDisplayNames = {
    'sedentary': 'Sedentary (little or no exercise)',
    'lightly_active': 'Lightly Active (1-3 days/week)',
    'moderately_active': 'Moderately Active (3-5 days/week)',
    'very_active': 'Very Active (6-7 days/week)',
    'extra_active': 'Extra Active (very hard exercise)',
  };

  // Fitness level options
  final List<String> _fitnessLevelOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
  ];

  // Goal timeline options
  final List<String> _goalTimelineOptions = [
    '4_weeks',
    '8_weeks',
    '12_weeks',
    '16_weeks',
    '6_months',
    '1_year',
  ];

  final Map<String, String> _goalTimelineDisplayNames = {
    '4_weeks': '4 Weeks',
    '8_weeks': '8 Weeks',
    '12_weeks': '12 Weeks',
    '16_weeks': '16 Weeks',
    '6_months': '6 Months',
    '1_year': '1 Year',
  };

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _calculateMetrics();
  }

  void _initializeControllers() {
    // Basic info
    _heightController = TextEditingController(
      text: widget.userProfile.height.toString(),
    );
    _weightController = TextEditingController(
      text: widget.userProfile.weight.toString(),
    );
    _targetWeightController = TextEditingController(
      text: widget.userProfile.targetWeight?.toString() ?? '',
    );

    // Phase 1 - Daily Targets
    _dailyStepGoalController = TextEditingController(
      text: (widget.userProfile.dailyStepGoal ?? 10000).toString(),
    );
    _sleepHoursController = TextEditingController(
      text: (widget.userProfile.sleepHours ?? 8).toString(),
    );
    _waterIntakeLitersController = TextEditingController(
      text: (widget.userProfile.waterIntake ?? 2.0).toStringAsFixed(1),
    );
    _waterIntakeGlassesController = TextEditingController(
      text: (widget.userProfile.waterIntakeGlasses ?? 8).toString(),
    );
    _workoutFrequencyController = TextEditingController(
      text: (widget.userProfile.workoutFrequency ?? 3).toString(),
    );
    _workoutDurationController = TextEditingController(
      text: (widget.userProfile.workoutDuration ?? 30).toString(),
    );
    
    // Phase 2
    _bedtimeController = TextEditingController(
      text: widget.userProfile.bedtime ?? '22:00',
    );
    _wakeupTimeController = TextEditingController(
      text: widget.userProfile.wakeupTime ?? '06:00',
    );
    _selectedSleepIssues = List<String>.from(widget.userProfile.sleepIssues ?? []);
    _selectedDietaryPreferences = List<String>.from(widget.userProfile.dietaryPreferences ?? []);
    _selectedWorkoutTypes = List<String>.from(widget.userProfile.preferredWorkouts ?? []);
    _selectedWorkoutLocation = widget.userProfile.workoutLocation ?? 'Gym';


    //Phase 3
    _selectedMedicalConditions = List<String>.from(widget.userProfile.medicalConditions ?? []);
    _otherMedicalConditionController = TextEditingController(
      text: widget.userProfile.otherMedicalCondition ?? '',
    );
    _selectedEquipment = List<String>.from(widget.userProfile.availableEquipment ?? []);
    _hasTrainer = widget.userProfile.hasTrainer ?? false;
    if (widget.userProfile.gender?.toLowerCase() == 'female') {
      _hasPeriods = widget.userProfile.hasPeriods;
      _pregnancyStatus = widget.userProfile.pregnancyStatus ?? '';
      _periodTrackingPreference = widget.userProfile.periodTrackingPreference ?? '';
      _cycleLength = widget.userProfile.cycleLength ?? 28;
      _cycleLengthRegular = widget.userProfile.cycleLengthRegular ?? true;
    }

    // Dropdown values
    _selectedActivityLevel = _mapToActivityLevelKey(widget.userProfile.activityLevel);
    _selectedPrimaryGoal = widget.userProfile.primaryGoal ?? 'General Wellness';
    _selectedWeightGoal = widget.userProfile.weightGoal ?? 'maintain_weight';
    _selectedGoalTimeline = widget.userProfile.goalTimeline ?? '12_weeks';
    _selectedFitnessLevel = widget.userProfile.fitnessLevel ?? 'Beginner';

    // Add listeners for water intake synchronization
    _waterIntakeLitersController.addListener(_onWaterLitersChanged);
    _waterIntakeGlassesController.addListener(_onWaterGlassesChanged);
    
    // Add listeners for metric calculations
    _heightController.addListener(_calculateMetrics);
    _weightController.addListener(_calculateMetrics);
  }

  void _onWaterLitersChanged() {
    if (_waterIntakeLitersController.text.isNotEmpty) {
      final liters = double.tryParse(_waterIntakeLitersController.text) ?? 0;
      final glasses = (liters * 4).round(); // 1 liter = 4 glasses (250ml each)
      
      // Remove listener temporarily to avoid infinite loop
      _waterIntakeGlassesController.removeListener(_onWaterGlassesChanged);
      _waterIntakeGlassesController.text = glasses.toString();
      _waterIntakeGlassesController.addListener(_onWaterGlassesChanged);
    }
  }

  void _onWaterGlassesChanged() {
    if (_waterIntakeGlassesController.text.isNotEmpty) {
      final glasses = int.tryParse(_waterIntakeGlassesController.text) ?? 0;
      final liters = glasses / 4.0; // 1 glass = 250ml = 0.25 liters
      
      // Remove listener temporarily to avoid infinite loop
      _waterIntakeLitersController.removeListener(_onWaterLitersChanged);
      _waterIntakeLitersController.text = liters.toStringAsFixed(1);
      _waterIntakeLitersController.addListener(_onWaterLitersChanged);
    }
  }

  void _calculateMetrics() {
    final height = double.tryParse(_heightController.text) ?? 0;
    final weight = double.tryParse(_weightController.text) ?? 0;
    final age = widget.userProfile.age ?? 25;
    final gender = widget.userProfile.gender ?? 'Male';

    if (height > 0 && weight > 0) {
      // Calculate BMI
      final heightInMeters = height / 100;
      _bmi = weight / (heightInMeters * heightInMeters);

      // Calculate BMR using Mifflin-St Jeor Equation
      if (gender.toLowerCase() == 'male') {
        _bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      } else {
        _bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      }

      // Calculate TDEE based on activity level
      final activityMultipliers = {
        'sedentary': 1.2,
        'lightly_active': 1.375,
        'moderately_active': 1.55,
        'very_active': 1.725,
        'extra_active': 1.9,
      };
      
      _tdee = _bmr * (activityMultipliers[_selectedActivityLevel] ?? 1.55);
      
      setState(() {});
    }
  }

  String _mapToActivityLevelKey(String? activityLevel) {
    if (activityLevel == null || activityLevel.isEmpty) {
      return 'moderately_active';
    }

    if (_activityLevelOptions.contains(activityLevel)) {
      return activityLevel;
    }

    final lowercaseLevel = activityLevel.toLowerCase();
    
    if (lowercaseLevel.contains('sedentary')) {
      return 'sedentary';
    } else if (lowercaseLevel.contains('lightly')) {
      return 'lightly_active';
    } else if (lowercaseLevel.contains('moderately')) {
      return 'moderately_active';
    } else if (lowercaseLevel.contains('very')) {
      return 'very_active';
    } else if (lowercaseLevel.contains('extra')) {
      return 'extra_active';
    }

    return 'moderately_active';
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _dailyStepGoalController.dispose();
    _sleepHoursController.dispose();
    _waterIntakeLitersController.dispose();
    _waterIntakeGlassesController.dispose();
    _workoutFrequencyController.dispose();
    _workoutDurationController.dispose();
    _bedtimeController.dispose();
    _wakeupTimeController.dispose();
    _otherMedicalConditionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(TextEditingController controller, String label) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(controller.text.split(':')[0]),
        minute: int.parse(controller.text.split(':')[1]),
      ),
    );
    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formattedTime;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Build the updated profile with all your fields
      final updatedProfile = widget.userProfile.copyWith(
        height: double.tryParse(_heightController.text) ?? widget.userProfile.height,
        weight: double.tryParse(_weightController.text) ?? widget.userProfile.weight,
        activityLevel: _selectedActivityLevel,
        primaryGoal: _selectedPrimaryGoal,
        weightGoal: _selectedWeightGoal,
        targetWeight: double.tryParse(_targetWeightController.text),
        goalTimeline: _selectedGoalTimeline,
        dailyStepGoal: int.tryParse(_dailyStepGoalController.text) ?? 10000,
        sleepHours: double.tryParse(_sleepHoursController.text) ?? 8.0,
        waterIntake: double.tryParse(_waterIntakeLitersController.text) ?? 2.0,
        waterIntakeGlasses: int.tryParse(_waterIntakeGlassesController.text) ?? 8,
        workoutFrequency: int.tryParse(_workoutFrequencyController.text) ?? 3,
        workoutDuration: int.tryParse(_workoutDurationController.text) ?? 30,
        fitnessLevel: _selectedFitnessLevel,
        bmi: _bmi,
        bmr: _bmr,
        tdee: _tdee,

        // Phase 2 additions
        bedtime: _bedtimeController.text,
        wakeupTime: _wakeupTimeController.text,
        sleepIssues: _selectedSleepIssues,
        dietaryPreferences: _selectedDietaryPreferences,
        preferredWorkouts: _selectedWorkoutTypes,
        workoutLocation: _selectedWorkoutLocation,

        // Phase 3 additions
        medicalConditions: _selectedMedicalConditions,
        otherMedicalCondition: _selectedMedicalConditions.contains('Other') 
            ? _otherMedicalConditionController.text 
            : null,
        availableEquipment: _selectedEquipment,
        hasTrainer: _hasTrainer,
        
        // Women's health (conditional)
        hasPeriods: widget.userProfile.gender?.toLowerCase() == 'female' ? _hasPeriods : null,
        pregnancyStatus: widget.userProfile.gender?.toLowerCase() == 'female' ? _pregnancyStatus : null,
        periodTrackingPreference: widget.userProfile.gender?.toLowerCase() == 'female' 
            ? _periodTrackingPreference : null,
        cycleLength: widget.userProfile.gender?.toLowerCase() == 'female' ? _cycleLength : null,
        cycleLengthRegular: widget.userProfile.gender?.toLowerCase() == 'female' 
            ? _cycleLengthRegular : null,
      );

      // Use Provider to update the profile
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final savedProfile = await userProvider.updateProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return the updated profile to refresh the previous screen
        Navigator.pop(context, savedProfile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save profile: ${e.toString()}';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Account Info Section (Read-only)
            _buildSectionHeader('Account Information'),
            _buildReadOnlyField('Name', widget.userProfile.name),
            _buildReadOnlyField('Email', widget.userProfile.email),
            _buildReadOnlyField('Age', '${widget.userProfile.age ?? 0} years'),
            _buildReadOnlyField('Gender', widget.userProfile.gender ?? 'Not specified'),
            if (widget.userProfile.createdAt != null)
              _buildReadOnlyField(
                'Member Since',
                DateFormat('MMM dd, yyyy').format(widget.userProfile.createdAt!),
              ),

            const SizedBox(height: 24),

            // Body Metrics Section
            _buildSectionHeader('Body Metrics'),
            _buildNumberField(
              'Height (cm)',
              _heightController,
              'Please enter your height',
              min: 100,
              max: 250,
              maxDecimals: 1,
              hintText: 'e.g., 170.5'
            ),
            _buildNumberField(
              'Weight (kg)',
              _weightController,
              'Please enter your weight',
              min: 30,
              max: 300,
              maxDecimals: 2,
              hintText: 'e.g., 67.25'
            ),
            _buildDropdownField(
              'Activity Level',
              _selectedActivityLevel,
              _activityLevelOptions,
              (value) {
                setState(() {
                  _selectedActivityLevel = value!;
                  _calculateMetrics();
                });
              },
              displayNames: _activityLevelDisplayNames,
            ),

            // Calculated Metrics (Read-only)
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calculated Metrics',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricDisplay('BMI', _bmi.toStringAsFixed(1)),
                      _buildMetricDisplay('BMR', '${_bmr.toStringAsFixed(0)} cal'),
                      _buildMetricDisplay('TDEE', '${_tdee.toStringAsFixed(0)} cal'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Goals & Targets Section
            _buildSectionHeader('Goals & Targets'),
            _buildPrimaryGoalDropdown(),
            _buildWeightGoalDropdown(),
            _buildNumberField(
              'Target Weight (kg)',
              _targetWeightController,
              'What is your target weight?',
              min: 30,
              max: 300,
              maxDecimals: 2,
              hintText: 'e.g., 67.25',
              isRequired: false,
            ),
            _buildDropdownField(
              'Goal Timeline',
              _selectedGoalTimeline,
              _goalTimelineOptions,
              (value) => setState(() => _selectedGoalTimeline = value!),
              displayNames: _goalTimelineDisplayNames,
            ),
            _buildNumberField(
              'Daily Step Goal',
              _dailyStepGoalController,
              'Enter your daily step target',
              min: 1000,
              max: 50000,
              isInteger: true,
            ),

            const SizedBox(height: 24),

            // Daily Targets Section
            _buildSectionHeader('Daily Targets'),
            _buildNumberField(
              'Sleep Hours Goal',
              _sleepHoursController,
              'Target hours of sleep per night',
              min: 4,
              max: 12,
              step: 0.5,
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTimeField(
                    'Bedtime',
                    _bedtimeController,
                    'Preferred bedtime',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeField(
                    'Wake Time',
                    _wakeupTimeController,
                    'Preferred wake time',
                  ),
                ),
              ],
            ),
            
            _buildSleepIssuesSelector(),
            
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    'Water Intake (Liters)',
                    _waterIntakeLitersController,
                    'Daily water target',
                    min: 0.5,
                    max: 6.0,
                    step: 0.1,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    'Water (Glasses)',
                    _waterIntakeGlassesController,
                    'Glasses per day',
                    min: 2,
                    max: 24,
                    isInteger: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Nutrition Preferences'),
            _buildDietaryPreferencesSelector(),

            const SizedBox(height: 24),
            _buildSectionHeader('Health Information'),
            _buildMedicalConditionsSelector(),
            if (_selectedMedicalConditions.contains('Other'))
              _buildTextField(
                'Specify Other Condition',
                _otherMedicalConditionController,
                'Please specify your condition',
                isRequired: false,
              ),

            // Exercise Preferences Section
            _buildSectionHeader('Exercise Preferences'),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    'Workout Frequency',
                    _workoutFrequencyController,
                    'Days per week',
                    min: 0,
                    max: 7,
                    isInteger: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNumberField(
                    'Workout Duration',
                    _workoutDurationController,
                    'Minutes per session',
                    min: 10,
                    max: 180,
                    isInteger: true,
                  ),
                ),
              ],
            ),
            _buildDropdownField(
              'Fitness Level',
              _selectedFitnessLevel,
              _fitnessLevelOptions,
              (value) => setState(() => _selectedFitnessLevel = value!),
            ),

            _buildWorkoutTypesSelector(),
            _buildWorkoutLocationDropdown(),
            _buildEquipmentSelector(),
            _buildTrainerToggle(),
            
            const SizedBox(height: 32),

            // Progress Summary
            if (widget.userProfile.startingWeight != null)
              _buildProgressSummary(),

            if (widget.userProfile.gender?.toLowerCase() == 'female') ...[
              const SizedBox(height: 24),
              _buildSectionHeader("Women's Health"),
              _buildWomensHealthSection(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: const Icon(Icons.access_time),
        ),
        onTap: () => _selectTime(controller, label),
      ),
    );
  }

  Widget _buildSleepIssuesSelector() {
    final sleepIssueOptions = [
      'Difficulty falling asleep',
      'Frequent wake-ups',
      'Early morning awakening',
      'Snoring',
      'Sleep apnea',
      'Restless legs',
      'Insomnia',
      'None',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sleep Issues (select all that apply)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sleepIssueOptions.map((issue) {
              final isSelected = _selectedSleepIssues.contains(issue);
              return FilterChip(
                label: Text(issue),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (issue == 'None') {
                      _selectedSleepIssues = selected ? ['None'] : [];
                    } else {
                      if (selected) {
                        _selectedSleepIssues.remove('None');
                        _selectedSleepIssues.add(issue);
                      } else {
                        _selectedSleepIssues.remove(issue);
                      }
                    }
                  });
                },
                selectedColor: Colors.blue.withOpacity(0.3),
                checkmarkColor: Colors.blue,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryPreferencesSelector() {
    final dietaryOptions = [
      'Vegetarian',
      'Vegan',
      'Pescatarian',
      'Keto',
      'Paleo',
      'Mediterranean',
      'Low Carb',
      'Low Fat',
      'Gluten Free',
      'Dairy Free',
      'Halal',
      'Kosher',
      'None',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dietary Preferences',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dietaryOptions.map((diet) {
              final isSelected = _selectedDietaryPreferences.contains(diet);
              return FilterChip(
                label: Text(diet),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (diet == 'None') {
                      _selectedDietaryPreferences = selected ? ['None'] : [];
                    } else {
                      if (selected) {
                        _selectedDietaryPreferences.remove('None');
                        _selectedDietaryPreferences.add(diet);
                      } else {
                        _selectedDietaryPreferences.remove(diet);
                      }
                    }
                  });
                },
                selectedColor: Colors.green.withOpacity(0.3),
                checkmarkColor: Colors.green,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        enabled: false,
      ),
    );
  }

  Widget _buildWorkoutTypesSelector() {
    final workoutTypes = [
      'Running',
      'Walking',
      'Cycling',
      'Swimming',
      'Yoga',
      'Pilates',
      'Weight Training',
      'HIIT',
      'CrossFit',
      'Dancing',
      'Martial Arts',
      'Sports',
      'Home Workouts',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preferred Workout Types',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: workoutTypes.map((workout) {
              final isSelected = _selectedWorkoutTypes.contains(workout);
              return FilterChip(
                label: Text(workout),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedWorkoutTypes.add(workout);
                    } else {
                      _selectedWorkoutTypes.remove(workout);
                    }
                  });
                },
                selectedColor: Colors.orange.withOpacity(0.3),
                checkmarkColor: Colors.orange,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutLocationDropdown() {
    final locationOptions = [
      'Home',
      'Gym',
      'Outdoor',
      'Studio',
      'Mixed',
    ];

    return _buildDropdownField(
      'Workout Location',
      _selectedWorkoutLocation,
      locationOptions,
      (value) => setState(() => _selectedWorkoutLocation = value!),
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController controller,
    String? validationMessage, {
    double? min,
    double? max,
    bool isRequired = true,
    bool isInteger = false,
    int maxDecimals = 2,
    String? hintText,
    double step = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: !isInteger,
        ),
        inputFormatters: [
          if (!isInteger)
            FilteringTextInputFormatter.allow(
              RegExp('^\\d+\\.?\\d{0,$maxDecimals}'),
            ),
          if (isInteger)
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixIcon: const Icon(Icons.edit, size: 18),
        ),
        validator: (value) {
          if (!isRequired && (value == null || value.isEmpty)) {
            return null;
          }
          if (value == null || value.isEmpty) {
            return validationMessage;
          }
          final number = isInteger
              ? int.tryParse(value)?.toDouble()
              : double.tryParse(value);
          if (number == null) {
            return 'Please enter a valid number';
          }
          if (min != null && number < min) {
            return 'Minimum value is $min';
          }
          if (max != null && number > max) {
            return 'Maximum value is $max';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    T value,
    List<T> items,
    Function(T?) onChanged, {
    Map<T, String>? displayNames,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: items.contains(value) ? value : items.first,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        items: items.map((item) {
          final displayName = displayNames?[item] ?? item.toString();
          return DropdownMenuItem<T>(
            value: item,
            child: Text(displayName),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPrimaryGoalDropdown() {
    final primaryGoalOptions = [
      'Lose Weight',
      'Gain Weight',
      'Build Muscle',
      'Improve Fitness',
      'Maintain Health',
      'General Wellness',
    ];

    return _buildDropdownField(
      'Primary Goal',
      _selectedPrimaryGoal,
      primaryGoalOptions,
      (value) => setState(() => _selectedPrimaryGoal = value!),
    );
  }

  Widget _buildWeightGoalDropdown() {
    final weightGoalOptions = {
      'lose_weight': 'Lose Weight',
      'gain_weight': 'Gain Weight',
      'maintain_weight': 'Maintain Weight',
    };

    return _buildDropdownField(
      'Weight Goal',
      _selectedWeightGoal,
      weightGoalOptions.keys.toList(),
      (value) => setState(() => _selectedWeightGoal = value!),
      displayNames: weightGoalOptions,
    );
  }

  Widget _buildMetricDisplay(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalConditionsSelector() {
    final medicalConditions = [
      'Diabetes',
      'Hypertension',
      'Heart Disease',
      'Asthma',
      'Arthritis',
      'Thyroid Disorder',
      'PCOS',
      'Anemia',
      'High Cholesterol',
      'Anxiety',
      'Depression',
      'Back Pain',
      'Knee Problems',
      'Allergies',
      'Other',
      'None',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Medical Conditions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'This helps us provide safer exercise and nutrition recommendations',
                child: Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: medicalConditions.map((condition) {
              final isSelected = _selectedMedicalConditions.contains(condition);
              return FilterChip(
                label: Text(condition),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (condition == 'None') {
                      _selectedMedicalConditions = selected ? ['None'] : [];
                      _otherMedicalConditionController.clear();
                    } else {
                      if (selected) {
                        _selectedMedicalConditions.remove('None');
                        _selectedMedicalConditions.add(condition);
                      } else {
                        _selectedMedicalConditions.remove(condition);
                        if (condition == 'Other') {
                          _otherMedicalConditionController.clear();
                        }
                      }
                    }
                  });
                },
                selectedColor: Colors.red.withOpacity(0.2),
                checkmarkColor: Colors.red,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSelector() {
    final equipmentOptions = [
      'Dumbbells',
      'Barbell',
      'Resistance Bands',
      'Kettlebells',
      'Pull-up Bar',
      'Treadmill',
      'Exercise Bike',
      'Rowing Machine',
      'Yoga Mat',
      'Foam Roller',
      'Jump Rope',
      'Medicine Ball',
      'TRX Straps',
      'Bench',
      'None',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Equipment',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: equipmentOptions.map((equipment) {
              final isSelected = _selectedEquipment.contains(equipment);
              return FilterChip(
                label: Text(equipment),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (equipment == 'None') {
                      _selectedEquipment = selected ? ['None'] : [];
                    } else {
                      if (selected) {
                        _selectedEquipment.remove('None');
                        _selectedEquipment.add(equipment);
                      } else {
                        _selectedEquipment.remove(equipment);
                      }
                    }
                  });
                },
                selectedColor: Colors.purple.withOpacity(0.3),
                checkmarkColor: Colors.purple,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal Trainer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Do you work with a personal trainer?',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Switch(
              value: _hasTrainer,
              onChanged: (value) {
                setState(() {
                  _hasTrainer = value;
                });
              },
              activeColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWomensHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period tracking preference
        _buildDropdownField(
          'Period Tracking',
          _periodTrackingPreference,
          [
            'track_periods',
            'general_wellness',
            'no_tracking',
          ],
          (value) => setState(() => _periodTrackingPreference = value!),
          displayNames: {
            'track_periods': 'Track my periods',
            'general_wellness': 'General wellness only',
            'no_tracking': 'No period tracking',
          },
        ),

        // Pregnancy status
        _buildDropdownField(
          'Current Status',
          _pregnancyStatus,
          [
            'not_pregnant',
            'pregnant',
            'breastfeeding',
            'trying_to_conceive',
            'prefer_not_to_say',
          ],
          (value) => setState(() => _pregnancyStatus = value!),
          displayNames: {
            'not_pregnant': 'Not pregnant',
            'pregnant': 'Currently pregnant',
            'breastfeeding': 'Breastfeeding',
            'trying_to_conceive': 'Trying to conceive',
            'prefer_not_to_say': 'Prefer not to say',
          },
        ),

        // Only show cycle fields if tracking periods
        if (_periodTrackingPreference == 'track_periods') ...[
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  'Cycle Length (days)',
                  TextEditingController(text: _cycleLength.toString()),
                  'Average cycle length',
                  min: 21,
                  max: 40,
                  isInteger: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.pink[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Regular Cycle',
                        style: TextStyle(fontSize: 14),
                      ),
                      Switch(
                        value: _cycleLengthRegular,
                        onChanged: (value) {
                          setState(() {
                            _cycleLengthRegular = value;
                          });
                        },
                        activeColor: Colors.pink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],

        // Informational note
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.pink[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.pink[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This information helps us provide personalized health insights',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.pink[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String? validationMessage, {
    bool isRequired = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        validator: isRequired
            ? (value) {
                if (value == null || value.isEmpty) {
                  return validationMessage;
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildProgressSummary() {
    final startWeight = widget.userProfile.startingWeight ?? widget.userProfile.weight;
    final currentWeight = double.tryParse(_weightController.text) ?? widget.userProfile.weight;
    final weightChange = currentWeight - startWeight;
    final isLoss = weightChange < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoss
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weight Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressMetric(
                'Starting',
                '${startWeight.toStringAsFixed(2)} kg',
                Icons.flag,
              ),
              Icon(
                isLoss ? Icons.trending_down : Icons.trending_up,
                color: isLoss ? Colors.green : Colors.orange,
                size: 30,
              ),
              _buildProgressMetric(
                'Current',
                '${currentWeight.toStringAsFixed(2)} kg',
                Icons.monitor_weight,
              ),
              _buildProgressMetric(
                isLoss ? 'Lost' : 'Gained',
                '${weightChange.abs().toStringAsFixed(2)} kg',
                isLoss ? Icons.arrow_downward : Icons.arrow_upward,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}