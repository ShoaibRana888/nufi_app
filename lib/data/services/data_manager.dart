// lib/data/services/data_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/repositories/user_repository.dart';
import 'package:user_onboarding/data/services/api/auth_api.dart';
import 'package:user_onboarding/data/services/api/weight_api.dart';
import 'package:user_onboarding/data/services/connectivity_service.dart';
import 'package:user_onboarding/data/services/database_service.dart';
import 'package:user_onboarding/data/services/exercise_data_service.dart';
import 'package:user_onboarding/data/models/weight_entry.dart';
import 'package:user_onboarding/data/repositories/weight_repository.dart';
import 'package:user_onboarding/data/managers/user_manager.dart';
import 'package:user_onboarding/utils/profile_update_notifier.dart';


class DataManager {
  static final DataManager _instance = DataManager._internal();
  final ConnectivityService _connectivityService = ConnectivityService();
  final AuthApi _apiService = AuthApi();
  final WeightApi _weightApi = WeightApi();

  // Local storage keys
  static const String userIdKey = 'user_id';
  static const String userProfileKey = 'user_profile';
  static const String onboardingCompletedKey = 'onboarding_completed';

  factory DataManager() {
    return _instance;
  }

  DataManager._internal();

  // Helper method for logging
  void _log(String message) {
    print('[DataManager] $message');
  }

  // Initialize data manager
  Future<void> initialize() async {
    try {
      // Everything goes through API
      _log('DataManager initialized - using API service');
    } catch (e) {
      _log('Initialize error: $e');
    }
  }

  // Save user profile
  Future<String?> saveUserProfile(UserProfile userProfile) async {
    try {
      _log('Starting to save user profile for ${userProfile.name}');
      
      // Save to backend/database first
      final userId = await completeOnboarding(userProfile.toOnboardingFormat());
      
      if (userId != null) {
        // Also save to local storage for offline access
        await _saveUserProfileLocally(userProfile.copyWith(id: userId));
        _log('User profile saved both remotely and locally');
      }
      
      return userId;
    } catch (e) {
      _log('Failed to save user profile: $e');
      rethrow;
    }
  }

  Future<void> _saveUserProfileLocally(UserProfile userProfile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = jsonEncode(userProfile.toMap());
      await prefs.setString(userProfileKey, profileJson);
      await prefs.setString(userIdKey, userProfile.id ?? '');
    } catch (e) {
      _log('Failed to save user profile locally: $e');
      rethrow;
    }
  }

  // Load user profile
  Future<UserProfile?> loadUserProfile() async {
    try {
      _log('Loading user profile');
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      
      // Get user ID from shared preferences
      final userId = prefs.getString(userIdKey);
      
      // Check if connected to the internet and if user ID exists
      final isConnected = await _connectivityService.isConnected();
      
      // Add null check for userId
      if (isConnected && userId != null && userId.isNotEmpty) {
        try {
          // Try to load from remote source
          UserProfile? userProfile;
          
          // ALWAYS use API service, regardless of platform
          _log('Loading user profile via API');
          userProfile = await _apiService.getUserProfileById(userId);
          
          if (userProfile != null) {
            _log('User profile loaded from API');

            if (userProfile.id == null || userProfile.id!.isEmpty) {
              userProfile = userProfile.copyWith(id: userId);
              _log('Fixed missing ID in remote profile');
            }
          
            // Save the corrected profile locally
            await _saveUserProfileLocally(userProfile);

            return userProfile;
          }
        } catch (e) {
          _log('Failed to load user profile from API: $e');
          _log('Falling back to local storage...');
        }
      }
      
      // Fall back to local storage
      final userProfileJson = prefs.getString(userProfileKey);
      
      if (userProfileJson != null && userProfileJson.isNotEmpty) {
        try {
          // Load user profile from local storage
          final userProfileData = jsonDecode(userProfileJson);

          if (userId != null && userId.isNotEmpty) {
            userProfileData['id'] = userId; // Add the user ID to the profile data
          }

          final userProfile = UserProfile.fromMap(userProfileData);
          _log('User profile loaded from local storage');
          _log('UserProfile ID: ${userProfile.id}');
          return userProfile;
        } catch (e) {
          _log('Failed to load user profile from local storage: $e');
        }
      }
    
      _log('No user profile found');
      return null;
    } catch (e) {
      _log('Failed to load user profile: $e');
      return null;
    }
  }

  Future<String?> completeOnboarding(Map<String, dynamic> onboardingData) async {
    try {
      _log('Starting onboarding completion');
      
      final prefs = await SharedPreferences.getInstance();
      final isConnected = await _connectivityService.isConnected();
      
      String? userId;
      
      if (isConnected) {
        try {
          // Complete onboarding via API
          final response = await _apiService.completeOnboarding(onboardingData);
          
          if (response['success'] == true) {
            userId = response['userId']?.toString();
            
            if (userId != null) {
              // Save user ID
              await prefs.setString(userIdKey, userId);
              await prefs.setBool(onboardingCompletedKey, true);
              
              // Fetch the complete user profile from backend
              _log('Fetching user profile after onboarding...');
              final userProfile = await _apiService.getUserProfileById(userId);
              
              if (userProfile != null) {
                // Save to local storage
                await _saveUserProfileLocally(userProfile);
                
                // Set user as logged in with UserManager
                await UserManager.setCurrentUser(userProfile);
                
                _log('User profile fetched and saved after onboarding');
              }
              
              return userId;
            }
          }
        } catch (e) {
          _log('Failed to complete onboarding remotely: $e');
          // Continue with offline mode
        }
      }
      
      // Offline mode: Generate local ID and save data
      if (userId == null) {
        userId = DateTime.now().millisecondsSinceEpoch.toString();
        await prefs.setString(userIdKey, userId);
        await prefs.setBool(onboardingCompletedKey, true);
        
        // Create and save user profile locally
        final basicInfo = onboardingData['basicInfo'] ?? {};
        final userProfileData = {
          'id': userId,
          'name': basicInfo['name'] ?? '',
          'email': basicInfo['email'] ?? '',
          // ... map other fields from onboardingData
        };
        
        final userProfile = UserProfile.fromMap(userProfileData);
        await _saveUserProfileLocally(userProfile);
        await UserManager.setCurrentUser(userProfile);
        
        _log('Onboarding completed offline with local ID: $userId');
      }
      
      return userId;
    } catch (e) {
      _log('Failed to complete onboarding: $e');
      return null;
    }
  }

  Future<UserProfile?> getUserProfileById(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // First try to get from local storage
      final userProfileJson = prefs.getString(userProfileKey);
      if (userProfileJson != null) {
        final userMap = jsonDecode(userProfileJson);
        return UserProfile.fromMap(userMap);
      }
      
      // If not found locally and we have connectivity, try API
      final isConnected = await _connectivityService.isConnected();
      if (isConnected) {
        try {
          return await _apiService.getUserProfileById(userId);
        } catch (e) {
          _log('Could not fetch user profile from API: $e');
        }
      }
      
      return null;
    } catch (e) {
      _log('Error getting user profile by ID: $e');
      return null;
    }
  }

  Future<bool> setStartingWeight(String userId, double startingWeight) async {
    try {
      _log('Setting starting weight: $startingWeight kg for user: $userId');
      
      final isConnected = await _connectivityService.isConnected();
      
      if (isConnected) {
        if (kIsWeb) {
          // For web, use API service
          try {
            final result = await _weightApi.setStartingWeight(userId, startingWeight);
            if (result) {
              _log('Starting weight set successfully via API');
              return true;
            } else {
              _log('Failed to set starting weight via API');
              return false;
            }
          } catch (e) {
            _log('API starting weight failed: $e');
            return false;
          }
        } else {
          // For native, could use database directly
          _log('Setting starting weight via database not implemented yet');
          return false;
        }
      } else {
        _log('Cannot set starting weight while offline');
        return false;
      }
    } catch (e) {
      _log('Failed to set starting weight: $e');
      return false;
    }
  }

  Future<String> saveWeightEntry(WeightEntry weightEntry) async {
    try {
      _log('Saving weight entry for user: ${weightEntry.userId}');
      _log('Weight: ${weightEntry.weight} kg');
      _log('Date: ${weightEntry.date}');
      
      final isConnected = await _connectivityService.isConnected();
      
      if (isConnected) {
        if (kIsWeb) {
          // For web, use API service
          try {
            _log('Using API service to save weight entry');
            final result = await _weightApi.saveWeightEntry(weightEntry);
            _log('Weight entry saved via API with ID: $result');
            return result;
          } catch (e) {
            _log('API save failed, falling back to local storage: $e');
            await _saveWeightEntryLocally(weightEntry);
            return weightEntry.id ?? DateTime.now().millisecondsSinceEpoch.toString();
          }
        } else {
          // For native, try database first, fallback to local
          try {
            final result = await WeightRepository.saveWeightEntry(weightEntry);
            _log('Weight entry saved to database');
            return result;
          } catch (e) {
            _log('Database save failed, falling back to local storage: $e');
            await _saveWeightEntryLocally(weightEntry);
            return weightEntry.id ?? DateTime.now().millisecondsSinceEpoch.toString();
          }
        }
      } else {
        // Save locally when offline
        await _saveWeightEntryLocally(weightEntry);
        _log('Weight entry saved locally (offline)');
        return weightEntry.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      }
    } catch (e) {
      _log('Failed to save weight entry: $e');
      // Final fallback to local storage
      try {
        await _saveWeightEntryLocally(weightEntry);
        return weightEntry.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      } catch (localError) {
        _log('Even local save failed: $localError');
        rethrow;
      }
    }
  }

  Future<List<WeightEntry>> getWeightHistory(String userId, {int limit = 50}) async {
    try {
      _log('Loading weight history for user: $userId');
      
      // ALWAYS use API service now (works for both web and mobile)
      try {
        final result = await _weightApi.getWeightHistory(userId, limit: limit);
        _log('Weight history loaded via API: ${result.length} entries');
        return result;
      } catch (e) {
        _log('API load failed, falling back to local storage: $e');
        return await _loadWeightHistoryLocally(userId);
      }
      
    } catch (e) {
      _log('Failed to load weight history: $e');
      return [];
    }
  }

  Future<WeightEntry?> getLatestWeight(String userId) async {
    try {
      _log('Loading latest weight for user: $userId');
      
      final isConnected = await _connectivityService.isConnected();
      
      if (isConnected) {
        if (kIsWeb) {
          try {
            final result = await _weightApi.getLatestWeight(userId);
            _log('Latest weight loaded via API');
            return result;
          } catch (e) {
            _log('API load failed, falling back to local storage: $e');
            final history = await _loadWeightHistoryLocally(userId);
            return history.isNotEmpty ? history.first : null;
          }
        } else {
          try {
            final result = await WeightRepository.getLatestWeight(userId);
            _log('Latest weight loaded from database');
            return result;
          } catch (e) {
            _log('Database load failed, falling back to local storage: $e');
            final history = await _loadWeightHistoryLocally(userId);
            return history.isNotEmpty ? history.first : null;
          }
        }
      } else {
        // Load from local storage when offline
        final history = await _loadWeightHistoryLocally(userId);
        return history.isNotEmpty ? history.first : null;
      }
    } catch (e) {
      _log('Failed to load latest weight: $e');
      return null;
    }
  }

  // Update user's current weight in profile
  Future<void> updateUserWeight(String userId, double newWeight) async {
    try {
      _log('Updating user weight to $newWeight kg');
      
      // Always update local profile, regardless of weight increase/decrease
      final userProfile = await loadUserProfile();
      if (userProfile != null) {
        final updatedProfile = userProfile.copyWith(weight: newWeight);
        await _saveUserProfileLocally(updatedProfile);
        _log('User weight updated locally to $newWeight kg');
      }

      // Try to update remotely if connected
      final isConnected = await _connectivityService.isConnected();
      if (isConnected) {
        try {
          if (kIsWeb) {
            await _weightApi.updateUserWeight(userId, newWeight);
            _log('User weight updated via API');
          } else {
            // For native apps, update via database
            await DatabaseService.execute('''
              UPDATE users SET weight = @weight WHERE id = @userId
            ''', {
              'weight': newWeight,
              'userId': userId,
            });
            _log('User weight updated via database');
          }
        } catch (e) {
          _log('Failed to update weight remotely, but local update succeeded: $e');
          // Don't throw here since local update succeeded
        }
      }
    } catch (e) {
      _log('Failed to update user weight: $e');
      // Don't rethrow since this is a non-critical operation
    }
  }

  // Clear weight data (for logout)
  Future<void> clearWeightData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'weight_entries_$userId';
      await prefs.remove(key);
      _log('Weight data cleared for user: $userId');
    } catch (e) {
      _log('Failed to clear weight data: $e');
    }
  }

  Future<UserProfile> updateUserProfile(UserProfile userProfile) async {
    try {
      _log('Starting to update user profile for ${userProfile.name}');
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      
      // Check if connected to the internet
      final isConnected = await _connectivityService.isConnected();
      
      UserProfile updatedProfile = userProfile;
      
      if (isConnected) {
        try {
          // Update via API and get the updated profile back
          _log('Updating user profile via API');
          updatedProfile = await _apiService.updateUserProfile(userProfile);
          _log('User profile updated remotely');
        } catch (e) {
          _log('Failed to update user profile remotely: $e');
          // Don't rethrow - we'll still save locally
        }
      }
      
      // Always update local storage with the latest profile
      await _saveUserProfileLocally(updatedProfile);

      await UserManager.setCurrentUser(updatedProfile);

      ProfileUpdateNotifier().notifyProfileUpdate(updatedProfile);

      _log('User profile updated in local storage and UserManager');

      return updatedProfile; // Return the updated profile
    } catch (e) {
      _log('Failed to update user profile: $e');
      rethrow;
    }
  }

  Future<bool> deleteWeightEntry(String entryId) async {
    try {
      _log('Deleting weight entry: $entryId');
      
      final isConnected = await _connectivityService.isConnected();
      
      if (isConnected) {
        if (kIsWeb) {
          // For web, use API service (you'll need to implement this in ApiService)
          try {
            await _weightApi.deleteWeightEntry(entryId);
            _log('Weight entry deleted via API');
            return true;
          } catch (e) {
            _log('API delete failed: $e');
            return false;
          }
        } else {
          // For native, use database
          try {
            final result = await WeightRepository.deleteWeightEntry(entryId);
            _log('Weight entry deleted from database');
            return result;
          } catch (e) {
            _log('Database delete failed: $e');
            return false;
          }
        }
      } else {
        // When offline, remove from local storage
        try {
          // You'll need to implement local deletion logic
          _log('Offline delete not implemented yet');
          return false;
        } catch (e) {
          _log('Local delete failed: $e');
          return false;
        }
      }
    } catch (e) {
      _log('Failed to delete weight entry: $e');
      return false;
    }
  }

  Future<void> _deleteWeightEntryLocally(String entryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
    
      final userId = prefs.getString(userIdKey);
      if (userId != null) {
        final key = 'weight_entries_$userId';
        final existingJson = prefs.getString(key) ?? '[]';
        final List<dynamic> existingList = jsonDecode(existingJson);
        
        // Remove the entry with matching ID
        existingList.removeWhere((item) => item['id'] == entryId);
        
        // Save back to preferences
        await prefs.setString(key, jsonEncode(existingList));
      }
    } catch (e) {
      _log('Failed to delete weight entry locally: $e');
      rethrow;
    }
  }

  Future<void> _saveWeightEntryLocally(WeightEntry weightEntry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'weight_entries_${weightEntry.userId}';
      
      // Get existing entries
      final existingJson = prefs.getString(key) ?? '[]';
      final List<dynamic> existingList = jsonDecode(existingJson);
      
      // Add new entry (with generated ID if none exists)
      final entryToSave = weightEntry.id != null 
          ? weightEntry 
          : weightEntry.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
      
      existingList.add(entryToSave.toMap());
      
      // Sort by date (newest first)
      existingList.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
      
      // Save back to preferences
      await prefs.setString(key, jsonEncode(existingList));
    } catch (e) {
      _log('Failed to save weight entry locally: $e');
      rethrow;
    }
  }

  Future<List<WeightEntry>> _loadWeightHistoryLocally(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'weight_entries_$userId';
      final existingJson = prefs.getString(key) ?? '[]';
      final List<dynamic> existingList = jsonDecode(existingJson);
      
      return existingList.map((item) => WeightEntry.fromMap(item)).toList();
    } catch (e) {
      _log('Failed to load weight history locally: $e');
      return [];
    }
  }

  // Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(onboardingCompletedKey) ?? false;
    } catch (e) {
      _log('Failed to check if onboarding is completed: $e');
      return false;
    }
  }

  // Synchronize local data with remote
  Future<void> synchronizeData() async {
    try {
      _log('Starting data synchronization');
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      
      // Check if connected to the internet
      final isConnected = await _connectivityService.isConnected();
      
      if (!isConnected) {
        _log('No internet connection. Skipping synchronization.');
        return;
      }
      
      // Get user ID from shared preferences
      final userId = prefs.getString(userIdKey);
      
      // Get user profile from local storage
      final userProfileJson = prefs.getString(userProfileKey);
      
      if (userProfileJson == null || userProfileJson.isEmpty) {
        _log('No local user profile found. Skipping synchronization.');
        return;
      }
      
      // Parse user profile
      UserProfile userProfile = UserProfile.fromMap(jsonDecode(userProfileJson));
      
      // Ensure the profile has the correct ID
      if (userId != null && userId.isNotEmpty) {
        if (userProfile.id == null || userProfile.id!.isEmpty) {
          userProfile = userProfile.copyWith(id: userId);
        }
      }
      
      // Add null check for userId
      if (userId != null && userId.isNotEmpty) {
        // User already exists remotely, update it
        try {
          _log('Synchronizing user profile via API');
          await _apiService.updateUserProfile(userProfile); // FIXED: Use new method signature
          _log('User profile synchronized with remote source');
        } catch (e) {
          _log('Failed to synchronize user profile: $e');
        }
      } else {
        // User does not exist remotely, create it
        try {
          _log('Creating new user profile via API');
          final newUserId = await _apiService.saveUserProfile(userProfile);
          
          // Save user ID to shared preferences
          await prefs.setString(userIdKey, newUserId);
          
          _log('New user profile created remotely with ID: $newUserId');
        } catch (e) {
          _log('Failed to create new user profile: $e');
        }
      }
    } catch (e) {
      _log('Failed to synchronize data: $e');
    }
  }

  Future<bool> saveExercises(String userId, List<Map<String, dynamic>> exercises) async {
    final exerciseService = ExerciseDataService();
    return await exerciseService.saveExercises(userId, exercises);
  }

  // Load exercises
  Future<List<Map<String, dynamic>>> loadExercises(String userId) async {
    final exerciseService = ExerciseDataService();
    return await exerciseService.loadExercises(userId);
  }

  // Add exercise
  Future<bool> addExercise(String userId, Map<String, dynamic> exercise) async {
    final exerciseService = ExerciseDataService();
    return await exerciseService.addExercise(userId, exercise);
  }

  Future<void> clearData() async {
    try {
      _log('Clearing all user data');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Get user ID from shared preferences
      final userId = prefs.getString(userIdKey);
      
      // Check if connected to the internet and if user ID exists
      final isConnected = await _connectivityService.isConnected(); 
      
      if (userId != null) {
        await clearWeightData(userId);
      }

      if (isConnected && userId != null && userId.isNotEmpty) {
        try {
          _log('Remote user profile deletion not implemented');
        } catch (e) {
          _log('Failed to delete user profile from remote source: $e');
        }
      }
      
      
    final keysToRemove = <String>[];
      for (String key in prefs.getKeys()) {
        if (!key.contains('supplement_')) {
          keysToRemove.add(key);
        }
      }
      
      // Remove non-supplement keys
      for (String key in keysToRemove) {
        await prefs.remove(key);
      }
      
      _log('Local data cleared (preserved supplement preferences)');
    } catch (e) {
      _log('Failed to clear data: $e');
      rethrow;
    }
  }

  // Login user method
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      _log('=== LOGIN PROCESS STARTED ===');
      _log('Starting login for: $email');
      
      // Check connectivity first
      final isConnected = await _connectivityService.isConnected();
      if (!isConnected) {
        throw Exception('No internet connection');
      }
      
      // Attempt login with timeout
      final result = await _apiService.loginUser(email, password).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _log('Login timed out after 15 seconds');
          throw Exception('Login request timed out. Please check your connection.');
        },
      );
      
      _log('API Response received: ${result}');
      
      if (result['success'] == true && result['user'] != null) {
        final userData = result['user'];
        final userId = userData['id'];
        
        _log('✅ Login API call successful');
        _log('User ID from API: $userId');
        _log('User data keys: ${userData.keys}');
        
        // Save user data locally
        final prefs = await SharedPreferences.getInstance();
        
        // Save user ID
        await prefs.setString(userIdKey, userId);
        _log('✅ Saved user_id to SharedPreferences: $userId');
        
        // Save email
        await prefs.setString('user_email', email);
        _log('✅ Saved user_email to SharedPreferences');
        
        // Mark as logged in
        await prefs.setBool('is_logged_in', true);
        _log('✅ Marked is_logged_in as true');
        
        // Mark onboarding as completed (since they can login, they must have completed onboarding)
        await prefs.setBool(onboardingCompletedKey, true);
        _log('✅ Marked onboarding_completed as true');
        
        // Fetch and save the full user profile
        try {
          _log('Fetching full user profile from API...');
          final userProfile = await _apiService.getUserProfileById(userId);
          
          if (userProfile != null) {
            _log('✅ User profile fetched successfully');
            _log('Profile ID: ${userProfile.id}');
            _log('Profile Name: ${userProfile.name}');
            
            // Save profile locally
            await _saveUserProfileLocally(userProfile);
            _log('✅ User profile saved to local storage');
            
            // Also save via UserManager
            await UserManager.setCurrentUser(userProfile);
            _log('✅ User profile saved via UserManager');
          } else {
            _log('⚠️ getUserProfileById returned null');
          }
        } catch (profileError) {
          _log('❌ Error fetching user profile: $profileError');
          // Don't fail the login if profile fetch fails - we'll try again later
        }
        
        // Debug: Print all SharedPreferences keys
        _log('=== SharedPreferences Keys After Login ===');
        for (var key in prefs.getKeys()) {
          _log('Key: $key = ${prefs.get(key)}');
        }
        _log('=========================================');
        
        _log('=== LOGIN PROCESS COMPLETED SUCCESSFULLY ===');
        return {
          'success': true,
          'user': userData,
          'message': 'Login successful',
        };
      } else {
        _log('❌ Login failed: Invalid response from API');
        throw Exception(result['message'] ?? 'Login failed');
      }
    } catch (e) {
      _log('❌ Login failed with error: $e');
      _log('Error type: ${e.runtimeType}');
      
      // Clear any cached login state
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', false);
        _log('Cleared is_logged_in flag');
      } catch (prefsError) {
        _log('Error clearing prefs: $prefsError');
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Login failed: $e',
      };
    }
  }

  // Check if user has valid login
  Future<bool> hasValidLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(userIdKey);
      final onboardingCompleted = prefs.getBool(onboardingCompletedKey) ?? false;
      
      return userId != null && userId.isNotEmpty && onboardingCompleted;
    } catch (e) {
      _log('Error checking login status: $e');
      return false;
    }
  }

  // Clear login data
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _log('User logged out');
    } catch (e) {
      _log('Error during logout: $e');
    }
  }
}