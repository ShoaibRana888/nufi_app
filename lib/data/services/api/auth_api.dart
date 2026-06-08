// lib/data/services/api/auth_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';

/// Authentication, onboarding and user-profile API.
class AuthApi {
  static final AuthApi _instance = AuthApi._internal();

  factory AuthApi() => _instance;

  AuthApi._internal();

  final ApiClient _client = ApiClient();

  // Complete onboarding using unified backend format
  Future<Map<String, dynamic>> completeOnboarding(Map<String, dynamic> onboardingData) async {
    try {
      // Ensure water_intake_glasses is included
      if (onboardingData['dietaryPreferences'] != null) {
        final dietPrefs = onboardingData['dietaryPreferences'] as Map<String, dynamic>;

        // Ensure both water intake values are present
        if (!dietPrefs.containsKey('waterIntakeGlasses') && dietPrefs.containsKey('waterIntake')) {
          dietPrefs['waterIntakeGlasses'] = ((dietPrefs['waterIntake'] as double) * 4).round();
        } else if (dietPrefs.containsKey('waterIntakeGlasses') && !dietPrefs.containsKey('waterIntake')) {
          dietPrefs['waterIntake'] = (dietPrefs['waterIntakeGlasses'] as int) / 4.0;
        }
      }

      final response = await _client.post(
        '/onboarding/complete',
        body: jsonEncode(onboardingData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to complete onboarding');
      }
    } catch (e) {
      debugPrint('API error completing onboarding: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<UserProfile> updateUserProfile(UserProfile userProfile) async {
    try {
      print('[AuthApi] Updating profile directly in database for user: ${userProfile.id}');

      final requestBody = {
        // Basic metrics
        'height': userProfile.height,
        'weight': userProfile.weight,
        'activity_level': userProfile.activityLevel,
        'bmi': userProfile.bmi,
        'bmr': userProfile.bmr,
        'tdee': userProfile.tdee,

        // Goals
        'primary_goal': userProfile.primaryGoal,
        'weight_goal': userProfile.weightGoal,
        'target_weight': userProfile.targetWeight,
        'goal_timeline': userProfile.goalTimeline,

        // Phase 1
        'daily_step_goal': userProfile.dailyStepGoal,
        'sleep_hours': userProfile.sleepHours,
        'water_intake': userProfile.waterIntake,
        'water_intake_glasses': userProfile.waterIntakeGlasses,
        'workout_frequency': userProfile.workoutFrequency,
        'workout_duration': userProfile.workoutDuration,
        'fitness_level': userProfile.fitnessLevel,

        // Phase 2
        'bedtime': userProfile.bedtime,
        'wakeup_time': userProfile.wakeupTime,
        'sleep_issues': userProfile.sleepIssues ?? [],
        'dietary_preferences': userProfile.dietaryPreferences ?? [],
        'preferred_workouts': userProfile.preferredWorkouts ?? [],
        'workout_location': userProfile.workoutLocation,

        // Phase 3
        'medical_conditions': userProfile.medicalConditions ?? [],
        'other_medical_condition': userProfile.otherMedicalCondition,
        'available_equipment': userProfile.availableEquipment ?? [],
        'has_trainer': userProfile.hasTrainer,

        // Women's Health (only if female)
        if (userProfile.gender?.toLowerCase() == 'female') ...{
          'has_periods': userProfile.hasPeriods,
          'pregnancy_status': userProfile.pregnancyStatus,
          'period_tracking_preference': userProfile.periodTrackingPreference,
          'cycle_length': userProfile.cycleLength,
          'cycle_length_regular': userProfile.cycleLengthRegular,
        },
      };

      // Remove null values
      requestBody.removeWhere((key, value) => value == null);

      print('[AuthApi] Sending update with ${requestBody.keys.length} fields');

      final response = await _client.put(
        '/users/update-user/${userProfile.id}',
        body: jsonEncode(requestBody),
      );

      print('[AuthApi] Update response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['userProfile'] != null) {
          print('[AuthApi] ✅ Profile updated successfully in database');
          print('[AuthApi] Updated fields: ${responseData['updatedFields']}');

          // Return the updated profile from database
          return UserProfile.fromMap(responseData['userProfile']);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update profile');
      }
    } catch (e) {
      debugPrint('❌ API error updating profile: $e');
      rethrow;
    }
  }

  // Login user
  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      print('[AuthApi] Attempting login for: $email');

      final body = jsonEncode({
        'email': email,
        'password': password,
      });

      final response = await _client.post(
        '/auth/login',
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('[AuthApi] ❌ Request timed out');
          throw Exception('Request timed out');
        },
      );

      print('[AuthApi] Response status: ${response.statusCode}');
      print('[AuthApi] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? true,
          'user': data['user'],
          'message': data['message'] ?? 'Login successful',
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('[AuthApi] ❌ Login failed: ${errorData}');
        throw Exception(errorData['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print('[AuthApi] ❌ Login error: $e');
      rethrow;
    }
  }

  // Save user profile using the new unified format
  Future<String> saveUserProfile(UserProfile userProfile) async {
    try {
      // Convert UserProfile to onboarding format
      final onboardingData = _convertUserProfileToOnboardingFormat(userProfile);

      final response = await completeOnboarding(onboardingData);

      if (response['success'] == true) {
        return response['userId'];
      } else {
        throw Exception('Failed to save user profile');
      }
    } catch (e) {
      debugPrint('API error when saving user profile: $e');
      rethrow;
    }
  }

  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      print('[AuthApi] Fetching profile from database for user: $userId');

      final response = await _client.get('/users/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserProfile.fromMap(data);
      } else {
        throw Exception('Failed to fetch profile');
      }
    } catch (e) {
      debugPrint('❌ API error fetching profile: $e');
      rethrow;
    }
  }

  Future<UserProfile> getUserProfileById(String userId) async {
    try {
      final response = await _client.get('/users/$userId');

      print('[AuthApi] User data from API: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // The API returns data wrapped in a response object
        if (data['success'] == true && data['userProfile'] != null) {
          // Extract the actual user profile data
          final userProfileData = data['userProfile'];

          return UserProfile.fromApiResponse(userProfileData);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to get user profile');
      }
    } catch (e) {
      print('[AuthApi] Error getting user profile: $e');
      rethrow;
    }
  }

  // Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      // Try to login with a dummy password to check if email exists
      final response = await _client.post(
        '/login',
        body: jsonEncode({
          'email': email,
          'password': 'dummy_password_for_check',
        }),
      );

      // If we get a 401, it means the email exists but password is wrong
      return response.statusCode == 401;
    } catch (e) {
      debugPrint('API error when checking email: $e');
      return false;
    }
  }

  // Helper method to convert UserProfile to onboarding format
  Map<String, dynamic> _convertUserProfileToOnboardingFormat(UserProfile userProfile) {
    return {
      'basicInfo': {
        'name': userProfile.name,
        'email': userProfile.email,
        'password': userProfile.password ?? 'defaultpassword123',
        'gender': userProfile.gender,
        'age': userProfile.age,
        'height': userProfile.height,
        'weight': userProfile.weight,
        'activityLevel': userProfile.activityLevel,
        'bmi': userProfile.formData?['bmi'] ?? 0.0,
        'bmr': userProfile.formData?['bmr'] ?? 0.0,
        'tdee': userProfile.formData?['tdee'] ?? 0.0,
      },
      'primaryGoal': userProfile.primaryGoal,
      'weightGoal': {
        'weightGoal': userProfile.weightGoal,
        'targetWeight': userProfile.targetWeight,
        'timeline': userProfile.goalTimeline ?? '',
      },
      'sleepInfo': {
        'sleepHours': userProfile.sleepHours,
        'bedtime': userProfile.bedtime,
        'wakeupTime': userProfile.wakeupTime,
        'sleepIssues': userProfile.sleepIssues,
      },
      'dietaryPreferences': {
        'dietaryPreferences': userProfile.dietaryPreferences,
        'waterIntake': userProfile.waterIntake,
        'medicalConditions': userProfile.medicalConditions,
        'otherCondition': userProfile.otherMedicalCondition,
      },
      'workoutPreferences': {
        'workoutTypes': userProfile.preferredWorkouts,
        'frequency': userProfile.workoutFrequency,
        'duration': userProfile.workoutDuration,
      },
      'exerciseSetup': {
        'workoutLocation': userProfile.workoutLocation,
        'equipment': userProfile.availableEquipment,
        'fitnessLevel': userProfile.fitnessLevel,
        'hasTrainer': userProfile.hasTrainer,
      },
    };
  }
}
