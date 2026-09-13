// lib/data/services/chat_service.dart
import 'package:user_onboarding/data/services/api/chat_api.dart';

class ChatService {
  static final ChatApi _apiService = ChatApi();

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

  /// Get chat history for a user. Bounded to the most recent [limit] messages
  /// by default; pass [before] (ISO created_at) to page older messages.
  static Future<List<Map<String, dynamic>>> getChatHistory(
    String userId, {
    int limit = 100,
    String? before,
  }) async {
    try {
      print('[ChatService] Getting chat history for user: $userId');
      return await _apiService.getChatHistory(userId, limit: limit, before: before);
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
}
