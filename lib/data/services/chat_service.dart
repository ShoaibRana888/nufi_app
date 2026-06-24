// lib/data/services/chat_service.dart
import 'package:user_onboarding/data/services/api/chat_api.dart';
import 'package:user_onboarding/data/models/user_profile.dart';

class ChatService {
  static final ChatApi _apiService = ChatApi();
  static Map<String, dynamic>? _cachedContext;
  static DateTime? _lastContextFetch;

  /// Send message with context version tracking
  static Future<String> sendMessage(
    String userId, 
    String message, {
    Map<String, dynamic>? context,
    int? contextVersion,
    bool forceRebuild = false,
  }) async {
    // NOTE: The backend rebuilds the chat context server-side from the user's
    // logged activities, so we intentionally do NOT fetch or send client-side
    // context here (it was previously ignored by the /chat endpoint, adding a
    // wasted round-trip per message). `context`/`contextVersion` are retained
    // only for backwards-compatible call sites.
    try {
      // Force rebuild if requested or if we suspect stale data
      if (forceRebuild) {
        await _apiService.rebuildChatContext(userId);
      }

      return await _apiService.sendChatMessage(userId, {
        'message': message,
      });
    } catch (e) {
      print('[ChatService] Error sending message: $e');

      // If chat fails, try rebuilding context and retry once
      try {
        print('[ChatService] Attempting to rebuild context and retry...');
        await _apiService.rebuildChatContext(userId);

        return await _apiService.sendChatMessage(userId, {
          'message': message,
        });
      } catch (retryError) {
        print('[ChatService] Retry also failed: $retryError');
        throw retryError;
      }
    }
  }

  /// Get chat history for a user (if you implement this later)
  static Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    try {
      print('[ChatService] Getting chat history for user: $userId');
      return await _apiService.getChatHistory(userId);
    } catch (e) {
      print('[ChatService] Error getting chat history: $e');
      return [];
    }
  }

  /// Get user context - now always cached
  static Future<Map<String, dynamic>> getUserContext(String userId) async {
    try {
      final response = await _apiService.getChatContext(userId);
      
      // Extract the context data
      if (response['success'] == true || response['context'] != null) {
        return response['context'] ?? response;
      } else {
        return response;
      }
    } catch (e) {
      print('[ChatService] Error getting context: $e');
      // Return minimal context on error
      return {
        'user_profile': {},
        'today_progress': {
          'date': DateTime.now().toIso8601String(),
          'meals_logged': 0,
          'total_calories': 0,
        },
      };
    }
  }

  /// Force rebuild context if sync issues
  static Future<bool> rebuildContext(String userId) async {
    try {
      return await _apiService.rebuildChatContext(userId);
    } catch (e) {
      print('[ChatService] Error rebuilding context: $e');
      return false;
    }
  }

  /// Get user's personalized framework
  static Future<Map<String, dynamic>?> getUserFramework(String userId) async {
    try {
      print('[ChatService] Getting framework for user: $userId');
      final response = await _apiService.getUserFramework(userId);
      
      if (response['success'] == true) {
        return response['framework'];
      }
      return null;
    } catch (e) {
      print('[ChatService] Error getting user framework: $e');
      return null;
    }
  }

  /// Send a quick action message (like "Show my progress")
  static Future<String> sendQuickAction(String userId, String action, {Map<String, dynamic>? context}) async {
    final Map<String, String> actionMessages = {
      'progress': 'Show me my progress summary with specific numbers',
      'today_plan': 'What should I focus on today based on my current progress?',
      'meal_ideas': 'Suggest healthy meals that fit my goals and dietary preferences',
      'workout_tips': 'What exercises should I do today based on my fitness level and goals?',
      'motivation': 'Give me some motivation based on my recent progress',
      'sleep_advice': 'How can I improve my sleep based on my current sleep patterns?',
      'water_reminder': 'Remind me about my hydration goals',
      'supplement_check': 'Review my supplement adherence and give advice',
    };

    final message = actionMessages[action] ?? action;
    return await sendMessage(userId, message, context: context);
  }

  /// Generate welcome message based on user profile
  static String generateWelcomeMessage(UserProfile userProfile) {
    final userName = userProfile.name.isNotEmpty ? userProfile.name : 'there';
    final goal = userProfile.primaryGoal.isNotEmpty ? userProfile.primaryGoal.toLowerCase() : 'your health goals';
    
    final List<String> welcomeVariations = [
      'Hi $userName! 👋\n\nI\'m your AI health coach and I have access to all your health data, activity logs, and progress. I can help you with $goal and provide personalized recommendations based on your actual data.\n\nWhat would you like to talk about today?',
      
      'Welcome back, $userName! 🌟\n\nI\'ve been keeping track of your progress and I\'m here to help you achieve $goal. I know your preferences, your recent activity, and can give you personalized advice.\n\nHow can I support you today?',
      
      'Hey $userName! 💪\n\nReady to continue your journey toward $goal? I have insights into your recent meals, workouts, sleep, and more. Let\'s make today count!\n\nWhat\'s on your mind?',
    ];

    // Rotate welcome messages based on hour of day
    final hour = DateTime.now().hour;
    final index = hour % welcomeVariations.length;
    
    return welcomeVariations[index];
  }

  /// Generate context summary for chat initialization
  static Future<String> generateContextSummary(String userId) async {
    try {
      final context = await getUserContext(userId);
      final userProfile = context['user_profile'] ?? {};
      final recentActivity = context['recent_activity'] ?? {};
      
      final List<String> summaryParts = [];
      
      // Add recent activity highlights
      if (recentActivity['meals_this_week'] != null && recentActivity['meals_this_week'] > 0) {
        summaryParts.add('${recentActivity['meals_this_week']} meals logged this week');
      }
      
      if (recentActivity['workouts_this_week'] != null && recentActivity['workouts_this_week'] > 0) {
        summaryParts.add('${recentActivity['workouts_this_week']} workouts completed');
      }
      
      if (recentActivity['avg_sleep_hours'] != null && recentActivity['avg_sleep_hours'] > 0) {
        summaryParts.add('averaging ${recentActivity['avg_sleep_hours']} hours of sleep');
      }
      
      if (summaryParts.isEmpty) {
        return 'I\'m ready to help you get started with tracking your health journey!';
      }
      
      return 'Recent highlights: ${summaryParts.join(', ')}. Let\'s keep building on this progress!';
      
    } catch (e) {
      print('[ChatService] Error generating context summary: $e');
      return 'I\'m here to help you with your health goals!';
    }
  }

  /// Check if user has sufficient data for personalized advice
  static Future<bool> hasUserData(String userId) async {
    try {
      final context = await getUserContext(userId);
      final recentActivity = context['recent_activity'] ?? {};
      
      final hasRecentMeals = (recentActivity['meals_this_week'] ?? 0) > 0;
      final hasRecentExercise = (recentActivity['workouts_this_week'] ?? 0) > 0;
      final hasWeightData = context['goals_progress']?['weight_progress']?['status'] != 'no_data';
      
      return hasRecentMeals || hasRecentExercise || hasWeightData;
    } catch (e) {
      print('[ChatService] Error checking user data: $e');
      return false;
    }
  }

  /// Generate smart suggestions based on user context
  static Future<List<String>> getSmartSuggestions(String userId) async {
    try {
      final context = await getUserContext(userId);
      final userProfile = context['user_profile'] ?? {};
      final recentActivity = context['recent_activity'] ?? {};
      final weightGoal = userProfile['weight_goal'] ?? 'maintain_weight';
      
      final List<String> suggestions = [];
      
      // Goal-specific suggestions
      switch (weightGoal) {
        case 'lose_weight':
          suggestions.addAll([
            'How many calories should I eat today?',
            'What are the best exercises for weight loss?',
            'Help me plan a high-protein meal',
          ]);
          break;
        case 'gain_weight':
          suggestions.addAll([
            'What foods can help me gain healthy weight?',
            'Plan my strength training for this week',
            'How often should I eat to gain weight?',
          ]);
          break;
        default:
          suggestions.addAll([
            'Help me maintain a balanced diet',
            'What\'s a good mix of cardio and strength training?',
            'How can I improve my overall health?',
          ]);
      }
      
      // Activity-based suggestions
      if ((recentActivity['workouts_this_week'] ?? 0) == 0) {
        suggestions.add('I haven\'t exercised this week, motivate me!');
      }
      
      if ((recentActivity['avg_sleep_hours'] ?? 0) < 7) {
        suggestions.add('How can I improve my sleep quality?');
      }
      
      // Time-based suggestions
      final hour = DateTime.now().hour;
      if (hour < 10) {
        suggestions.add('What should I have for breakfast?');
      } else if (hour < 14) {
        suggestions.add('Suggest a healthy lunch');
      } else if (hour < 18) {
        suggestions.add('I need an afternoon energy boost');
      } else {
        suggestions.add('Plan a light dinner for tonight');
      }
      
      // Shuffle and return top 4
      suggestions.shuffle();
      return suggestions.take(4).toList();
      
    } catch (e) {
      print('[ChatService] Error getting smart suggestions: $e');
      return [
        'Show me my progress',
        'What should I focus on today?',
        'Give me healthy meal ideas',
        'Motivate me to stay on track',
      ];
    }
  }

  static String formatContextSummary(Map<String, dynamic> context) {
    final today = context['today_progress'] ?? {};
    final parts = <String>[];
    
    if (today['meals_logged'] != null && today['meals_logged'] > 0) {
      parts.add('${today['meals_logged']} meals (${today['total_calories']} cal)');
    }
    
    if (today['water_glasses'] != null && today['water_glasses'] > 0) {
      parts.add('${today['water_glasses']} water');
    }
    
    if (today['steps'] != null && today['steps'] > 0) {
      parts.add('${today['steps']} steps');
    }
    
    return parts.isEmpty 
      ? 'No activity logged yet today'
      : 'Today: ${parts.join(', ')}';
  }


  /// Clear conversation (if you implement conversation storage)
  static Future<void> clearConversation(String userId) async {
    try {
      // This would clear stored conversation history
      // Implementation depends on your storage strategy
      print('[ChatService] Clearing conversation for user: $userId');
    } catch (e) {
      print('[ChatService] Error clearing conversation: $e');
    }
  }

  /// Get coaching tip based on user's current situation
  static Future<String> getDailyTip(String userId) async {
    try {
      final message = 'Give me one specific tip for today based on my current progress and goals';
      return await sendMessage(userId, message);
    } catch (e) {
      print('[ChatService] Error getting daily tip: $e');
      return 'Focus on making one healthy choice at a time. Small consistent actions lead to big results!';
    }
  }
}