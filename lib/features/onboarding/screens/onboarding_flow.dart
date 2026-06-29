// lib/features/onboarding/screens/onboarding_flow.dart

import 'package:flutter/material.dart';
import 'package:user_onboarding/data/services/connectivity_service.dart';
import 'package:user_onboarding/data/services/data_manager.dart';
import 'package:user_onboarding/features/home/screens/home_page.dart';
import 'package:user_onboarding/features/onboarding/screens/basic_info_page.dart';
import 'package:user_onboarding/features/onboarding/screens/period_cycle_page.dart';
import 'package:user_onboarding/features/onboarding/screens/sleep_info_page.dart';
import 'package:user_onboarding/features/onboarding/screens/weight_goal_page.dart';
import 'package:user_onboarding/features/onboarding/screens/exercise_setup_page.dart';
import 'package:user_onboarding/features/onboarding/screens/dietary_preferences_page.dart';
import 'package:user_onboarding/features/onboarding/screens/workout_preferences_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/providers/user_provider.dart';
import 'package:user_onboarding/data/services/notification_service.dart';
import 'package:user_onboarding/services/fcm_service.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _totalPages = 6;

  // Form data
  final _formData = {
    'name': '',
    'email': '',
    'gender': '',
    'age': 0,
    'height': 0.0,
    'weight': 0.0,
    'activityLevel': '',
    'hasPeriods': null,
    'lastPeriodDate': '',
    'cycleLength': 28,
    'cycleLengthRegular': true,
    'pregnancyStatus': '',
    'trackingPreference': '',
    'primaryGoal': '',
    'weightGoal': '',
    'targetWeight': 0.0,
    'goalTimeline': '',
    'sleepHours': 8.0,
    'bedtime': '10:00 PM',        
    'wakeupTime': '6:00 AM',
    'sleepIssues': <String>[],
    'dietaryPreferences': <String>[],
    'waterIntake': 2.0,
    'waterIntakeGlasses': 8,
    'dailyMealsCount': 3,
    'dailyStepGoal': 10000, 
    'medicalConditions': <String>[],
    'otherMedicalCondition': '',
    'preferredWorkouts': <String>[],
    'workoutFrequency': 3,
    'workoutDuration': 30,
    'workoutLocation': '',
    'availableEquipment': <String>[],
    'fitnessLevel': 'Beginner',
    'hasTrainer': false,
  };

  final DataManager _dataManager = DataManager();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    // Check connectivity when the widget is initialized
    _checkConnectivity();
    // Listen to connectivity changes
    _setupConnectivityListener();
  }

  void _checkConnectivity() async {
    final isConnected = await _connectivityService.isConnected();
    setState(() {
      _isConnected = isConnected;
    });
  }

  void _setupConnectivityListener() {
    _connectivityService.setupConnectivityListener((isConnected) {
      setState(() {
        _isConnected = isConnected;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateTotalPages() {
    setState(() {
      if (_formData['gender'] == 'Female') {
        _totalPages = 7; // Add 1 for period cycle page
      } else {
        _totalPages = 6;
      }
    });
  }

  String _getPrimaryGoalFromWeightGoal(String weightGoal) {
    const goalMapping = {
      'lose_weight': 'Lose Weight',
      'gain_weight': 'Gain Weight',
      'maintain_weight': 'Maintain Weight',  
    };
    
    // Default to 'Improve Fitness' only if no match found
    return goalMapping[weightGoal]!;
  }

  void _onDataChanged(String key, dynamic value) {
    setState(() {
      _formData[key] = value;
    });
  // Update total pages when gender is set
    if (key == 'gender') {
      _updateTotalPages();
    }

    if (key == 'weightGoal' && value != null && value.toString().isNotEmpty) {
      final primaryGoal = _getPrimaryGoalFromWeightGoal(value.toString());
      setState(() {
        _formData['primaryGoal'] = primaryGoal;
      });
      print('Auto-mapped primary goal: $primaryGoal based on weight goal: $value');
    }

    // Sync water intake values
    if (key == 'waterIntake') {
      // Convert litres to glasses (1 glass = 250ml)
      setState(() {
        _formData['waterIntakeGlasses'] = ((value as double) * 4).round();
      });
    } else if (key == 'waterIntakeGlasses') {
      // Convert glasses to litres
      setState(() {
        _formData['waterIntake'] = (value as int) / 4.0;
      });
    }
  }

  Future<void> _setupNotifications(String userId, Map<String, dynamic> userProfile) async {
    try {
      final fcmService = FCMService();
      await fcmService.subscribeToNotifications(userId);
      print('✅ New user subscribed to FCM notifications');
      
      // Keep old notification service as fallback
      final notificationService = NotificationService();
      final permissionGranted = await notificationService.requestPermissions();
      
      if (permissionGranted) {
        await notificationService.scheduleAllNotifications(userId, userProfile);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'notifications_last_scheduled_$userId',
          DateTime.now().toIso8601String(),
        );
        
        print('✅ All notifications scheduled for new user: $userId');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Daily reminders are now active!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error setting up notifications: $e');
    }
  }
  
  bool _validateCurrentPage() {
    // Determine the actual page index considering female-only period cycle page
    int actualPageIndex = _currentPage;
    bool isFemale = _formData['gender'] == 'Female';

    // Adjust page indices for non-female users (skip period cycle page)
    if (!isFemale && _currentPage >= 1) {
      actualPageIndex = _currentPage + 1;
    }

    switch (actualPageIndex) {
      case 0: // Basic Info Page
        return _validateBasicInfo();
      case 1: // Period Cycle Page (Female only)
        return _validatePeriodCycle();
      case 2: // Weight Goal Page
        return _validateWeightGoal();
      case 3: // Sleep Info Page
        return _validateSleepInfo();
      case 4: // Dietary Preferences Page
        return _validateDietaryPreferences();
      case 5: // Workout Preferences Page
        return _validateWorkoutPreferences();
      case 6: // Exercise Setup Page
        return _validateExerciseSetup();
      default:
        return true;
    }
  }

  bool _validateBasicInfo() {
    // Check required fields
    if (_formData['name'] == null || (_formData['name'] as String).trim().isEmpty) {
      _showValidationError('Please enter your name');
      return false;
    }
    
    if (_formData['email'] == null || (_formData['email'] as String).trim().isEmpty) {
      _showValidationError('Please enter your email');
      return false;
    }
    
    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_formData['email'] as String)) {
      _showValidationError('Please enter a valid email address');
      return false;
    }
    
    if (_formData['password'] == null || (_formData['password'] as String).length < 6) {
      _showValidationError('Password must be at least 6 characters');
      return false;
    }

    if (_formData['confirmPassword'] == null || 
        (_formData['confirmPassword'] as String).isEmpty) {
          _showValidationError('Please confirm your password');
      return false;
    }

    if (_formData['password'] != _formData['confirmPassword']) {
          _showValidationError('Passwords do not match');
      return false;
    }
    
    if (_formData['gender'] == null || (_formData['gender'] as String).isEmpty) {
      _showValidationError('Please select your gender');
      return false;
    }
    
    if (_formData['age'] == null || _formData['age'] == 0) {
      _showValidationError('Please enter your age');
      return false;
    }
    
    // Validate age range
    int age = _formData['age'] as int;
    if (age < 13 || age > 120) {
      _showValidationError('Please enter a valid age (13-120)');
      return false;
    }
    
    if (_formData['height'] == null || _formData['height'] == 0.0) {
      _showValidationError('Please enter your height');
      return false;
    }
    
    // Validate height range (in cm)
    double height = _formData['height'] as double;
    if (height < 100 || height > 250) {
      _showValidationError('Please enter a valid height (100-250 cm)');
      return false;
    }
    
    if (_formData['weight'] == null || _formData['weight'] == 0.0) {
      _showValidationError('Please enter your weight');
      return false;
    }
    
    // Validate weight range (in kg)
    double weight = _formData['weight'] as double;
    if (weight < 30 || weight > 300) {
      _showValidationError('Please enter a valid weight (30-300 kg)');
      return false;
    }
    
    if (_formData['activityLevel'] == null || (_formData['activityLevel'] as String).isEmpty) {
      _showValidationError('Please select your activity level');
      return false;
    }
    
    return true;
  }

  bool _validatePeriodCycle() {
    // Only validate if user is female
    if (_formData['gender'] != 'Female') return true;
    
    if (_formData['hasPeriods'] == null) {
      _showValidationError('Please indicate if you have regular periods');
      return false;
    }
    
    // If user has periods, require additional info
    if (_formData['hasPeriods'] == true) {
      if (_formData['lastPeriodDate'] == null || (_formData['lastPeriodDate'] as String).isEmpty) {
        _showValidationError('Please enter your last period date');
        return false;
      }
      
      if (_formData['cycleLengthRegular'] == null) {
        _showValidationError('Please indicate if your cycle is regular');
        return false;
      }
    }
    
    if (_formData['pregnancyStatus'] == null || (_formData['pregnancyStatus'] as String).isEmpty) {
      _showValidationError('Please select your pregnancy status');
      return false;
    }
    
    if (_formData['trackingPreference'] == null || (_formData['trackingPreference'] as String).isEmpty) {
      _showValidationError('Please select your tracking preference');
      return false;
    }
    
    return true;
  }

  bool _validateWeightGoal() {
    if (_formData['weightGoal'] == null || (_formData['weightGoal'] as String).isEmpty) {
      _showValidationError('Please select your weight goal');
      return false;
    }
    
    // If not maintaining weight, require target weight
    if (_formData['weightGoal'] != 'maintain_weight' && _formData['weightGoal'] != 'Maintain Weight') {
      if (_formData['targetWeight'] == null || _formData['targetWeight'] == 0.0) {
        _showValidationError('Please enter your target weight');
        return false;
      }
      
      double currentWeight = _formData['weight'] as double? ?? 0.0;
      double targetWeight = _formData['targetWeight'] as double? ?? 0.0;
      
      // Validate target weight based on goal
      if (_formData['weightGoal'] == 'lose_weight' || _formData['weightGoal'] == 'Lose Weight') {
        if (targetWeight >= currentWeight) {
          _showValidationError('Target weight should be less than current weight for weight loss');
          return false;
        }
      } else if (_formData['weightGoal'] == 'gain_weight' || _formData['weightGoal'] == 'Gain Weight') {
        if (targetWeight <= currentWeight) {
          _showValidationError('Target weight should be more than current weight for weight gain');
          return false;
        }
      }
      
      // Check for reasonable weight goals (not more than 50% change)
      double percentChange = ((targetWeight - currentWeight).abs() / currentWeight) * 100;
      if (percentChange > 50) {
        _showValidationError('Please set a more realistic target weight (less than 50% change)');
        return false;
      }
    }
    
    if (_formData['goalTimeline'] == null || (_formData['goalTimeline'] as String).isEmpty) {
      _showValidationError('Please select your timeline');
      return false;
    }
    
    return true;
  }

  bool _validateSleepInfo() {
    if (_formData['sleepHours'] == null) {
      _showValidationError('Please select your sleep duration');
      return false;
    }
    
    double sleepHours = _formData['sleepHours'] as double;
    if (sleepHours < 3 || sleepHours > 12) {
      _showValidationError('Please select a valid sleep duration (3-12 hours)');
      return false;
    }
    
    if (_formData['bedtime'] == null || (_formData['bedtime'] as String).isEmpty) {
      _showValidationError('Please select your bedtime');
      return false;
    }
    
    if (_formData['wakeupTime'] == null || (_formData['wakeupTime'] as String).isEmpty) {
      _showValidationError('Please select your wake-up time');
      return false;
    }
    
    // Sleep issues can be optional, no validation needed
    return true;
  }

  bool _validateDietaryPreferences() {
    // Dietary preferences are optional but meals count is required
    if (_formData['dailyMealsCount'] == null || _formData['dailyMealsCount'] == 0) {
      _showValidationError('Please select your daily meals count');
      return false;
    }
    
    // Water intake should have default values, but validate if present
    if (_formData['waterIntake'] != null) {
      double waterIntake = _formData['waterIntake'] as double;
      if (waterIntake < 0.5 || waterIntake > 10) {
        _showValidationError('Please enter a valid water intake (0.5-10 liters)');
        return false;
      }
    }
    
    // At least one dietary preference or "No restrictions" should be selected
    List<String>? dietaryPrefs = _formData['dietaryPreferences'] as List<String>?;
    if (dietaryPrefs == null || dietaryPrefs.isEmpty) {
      _showValidationError('Please select at least one dietary preference or "No restrictions"');
      return false;
    }
    
    // At least one medical condition or "None" should be selected
    List<String>? medicalConditions = _formData['medicalConditions'] as List<String>?;
    if (medicalConditions == null || medicalConditions.isEmpty) {
      _showValidationError('Please select your medical conditions or "None"');
      return false;
    }
    
    return true;
  }

  bool _validateWorkoutPreferences() {
    // At least one workout type should be selected
    List<String>? workoutTypes = _formData['preferredWorkouts'] as List<String>?;
    if (workoutTypes == null || workoutTypes.isEmpty) {
      _showValidationError('Please select at least one workout type');
      return false;
    }
    
    if (_formData['workoutFrequency'] == null || _formData['workoutFrequency'] == 0) {
      _showValidationError('Please select your workout frequency');
      return false;
    }
    
    if (_formData['workoutDuration'] == null || _formData['workoutDuration'] == 0) {
      _showValidationError('Please select your workout duration');
      return false;
    }
    
    return true;
  }

  bool _validateExerciseSetup() {
    if (_formData['workoutLocation'] == null || (_formData['workoutLocation'] as String).isEmpty) {
      _showValidationError('Please select where you workout');
      return false;
    }
    
    // At least one equipment option should be selected (including "None")
    List<String>? equipment = _formData['availableEquipment'] as List<String>?;
    if (equipment == null || equipment.isEmpty) {
      _showValidationError('Please select your available equipment or "None"');
      return false;
    }
    
    if (_formData['fitnessLevel'] == null || (_formData['fitnessLevel'] as String).isEmpty) {
      _showValidationError('Please select your fitness level');
      return false;
    }
    
    if (_formData['hasTrainer'] == null) {
      _showValidationError('Please indicate if you work with a trainer');
      return false;
    }
    
    // Validate step goal
    if (_formData['dailyStepGoal'] == null || _formData['dailyStepGoal'] == 0) {
      _showValidationError('Please set your daily step goal');
      return false;
    }
    
    int stepGoal = _formData['dailyStepGoal'] as int;
    if (stepGoal < 1000 || stepGoal > 50000) {
      _showValidationError('Please set a realistic step goal (1,000-50,000 steps)');
      return false;
    }
    
    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Update the _nextPage method
  void _nextPage() {
    // Validate current page before proceeding
    if (!_validateCurrentPage()) {
      return; // Don't proceed if validation fails
    }
    
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Final validation before submission
      if (_validateCurrentPage()) {
        _submitFormData();
      }
    }
  }

  Widget _buildCurrentPage() {
    // Determine the actual page index considering female-only period cycle page
    int actualPageIndex = _currentPage;
    bool isFemale = _formData['gender'] == 'Female';

    // Adjust page indices for non-female users (skip period cycle page)
    if (!isFemale && _currentPage >= 1) {
      actualPageIndex = _currentPage + 1;
    }

    switch (actualPageIndex) {
      case 0:
        return BasicInfoPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      case 1:
        // Show period cycle page only for females
        return PeriodCyclePage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      case 2:
        return WeightGoalPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      case 3:
        return SleepInfoPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      case 4:
        return DietaryPreferencesPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      case 5:
        return WorkoutPreferencesPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      case 6:
        return CurrentExerciseSetupPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
      default:
        return BasicInfoPage(
          formData: _formData,
          onDataChanged: _onDataChanged,
        );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitFormData() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // For maintain weight, set target weight to current weight
      if (_formData['weightGoal'] == 'maintain_weight' || 
          _formData['weightGoal'] == 'Maintain Weight') {
        _formData['targetWeight'] = _formData['weight'];
      }
    
      // Convert form data to unified onboarding format
      final onboardingData = {
        'basicInfo': {
          'name': _formData['name'],
          'email': _formData['email'],
          'password': _formData['password'] ?? 'defaultpassword123',
          'gender': _formData['gender'],
          'age': _formData['age'],
          'height': _formData['height'],
          'weight': _formData['weight'],
          'activityLevel': _formData['activityLevel'],
          'bmi': _formData['bmi'] ?? 0.0,
          'bmr': _formData['bmr'] ?? 0.0,
          'tdee': _formData['tdee'] ?? 0.0,
          'dailyStepGoal': _formData['dailyStepGoal'] ?? 10000,
        },
        if (_formData['gender'] == 'Female') 
        'periodCycle': {
          'hasPeriods': _formData['hasPeriods'],
          'lastPeriodDate': _formData['lastPeriodDate'],
          'cycleLength': _formData['cycleLength'],
          'cycleLengthRegular': _formData['cycleLengthRegular'],
          'pregnancyStatus': _formData['pregnancyStatus'],
          'trackingPreference': _formData['trackingPreference'],
        },
        'primaryGoal': _formData['primaryGoal'],
        'weightGoal': {
          'weightGoal': _formData['weightGoal'],
          'targetWeight': _formData['targetWeight'],
          'timeline': _formData['goalTimeline'] ?? '12_weeks',
        },
        'sleepInfo': {
          'sleepHours': _formData['sleepHours'],
          'bedtime': _formData['bedtime'],
          'wakeupTime': _formData['wakeupTime'],
          'sleepIssues': _formData['sleepIssues'],
        },
        'dietaryPreferences': {
          'dietaryPreferences': _formData['dietaryPreferences'],
          'waterIntake': _formData['waterIntake'],
          'waterIntakeGlasses': _formData['waterIntakeGlasses'],
          'dailyMealsCount': _formData['dailyMealsCount'] ?? 3,
          'medicalConditions': _formData['medicalConditions'],
          'otherCondition': _formData['otherMedicalCondition'],
        },
        'workoutPreferences': {
          'workoutTypes': _formData['preferredWorkouts'],
          'frequency': _formData['workoutFrequency'],
          'duration': _formData['workoutDuration'],
        },
        'exerciseSetup': {
          'workoutLocation': _formData['workoutLocation'],
          'equipment': _formData['availableEquipment'],
          'fitnessLevel': _formData['fitnessLevel'],
          'hasTrainer': _formData['hasTrainer'],
        },
      };

      // Complete onboarding
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = await userProvider.completeOnboarding(onboardingData);
      
      if (userId == null || userProvider.userProfile == null) {
        throw Exception('Failed to complete onboarding');
      }

      final userProfile = userProvider.userProfile!;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_set_step_goal_${userProfile.id}', true);

      await _setupNotifications(
        userProfile.id, 
        {
          'daily_meals_count': _formData['dailyMealsCount'] ?? 3,
          'wakeup_time': _formData['wakeupTime'] ?? '06:00',
        },
      );

      if (!mounted) return;
      
      // Close loading indicator
      Navigator.pop(context);
      
      // Show success dialog and navigate
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                const SizedBox(height: 20),
                const Text(
                  'You\'re all set!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thank you for providing your information. Your personalized health journey is ready!',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    // Navigate to home screen and clear navigation stack
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(userProfile: userProfile),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      // Close loading indicator
      Navigator.pop(context);
      
      // Get error message from provider if available
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final errorMessage = userProvider.error ?? error.toString();
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create profile: $errorMessage'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  userProvider.clearError();
                },
                child: const Text('Try Again'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Connectivity indicator
            if (!_isConnected)
              Container(
                width: double.infinity,
                color: Colors.amber,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Theme.of(context).colorScheme.onSurface),
                    SizedBox(width: 8),
                    Text(
                      'Offline Mode - Data will be saved locally',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _totalPages,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _totalPages,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildCurrentPage();
                },
              ),
            ),


            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage > 0
                      ? TextButton(
                          onPressed: _previousPage,
                          child: const Text('Back'),
                        )
                      : const SizedBox(width: 80),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(_currentPage < _totalPages - 1 ? 'Next' : 'Finish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}