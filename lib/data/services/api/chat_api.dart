// lib/data/services/api/chat_api.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';

/// Chat + chat-context API.
///
/// For now this holds only the cross-cutting context-sync helpers that every
/// activity write (water, steps, weight, ...) calls after saving. The
/// conversational chat methods will move here when the chat domain is split.
class ChatApi {
  static final ChatApi _instance = ChatApi._internal();

  factory ChatApi() => _instance;

  ChatApi._internal();

  final ApiClient _client = ApiClient();

  Future<void> updateChatContext(
    String userId,
    String activityType,
    Map<String, dynamic> data,
    {DateTime? date}
  ) async {
    try {
      // Use provided date or today
      final targetDate = date ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      print('[ChatApi] Updating chat context for $activityType on $dateStr');

      // Add the date to the data if not present
      if (!data.containsKey('date') && !data.containsKey('created_at')) {
        data['created_at'] = targetDate.toIso8601String();
      }

      final response = await _client.post(
        '/chat/context/update/$userId?activity_type=$activityType',
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        print('[ChatApi] ✅ Chat context updated successfully for $activityType');
      } else {
        // Don't throw - this is non-critical, chat can rebuild if needed
        print('[ChatApi] ⚠️ Context update failed (${response.statusCode}), will sync on next chat');
      }
    } catch (e) {
      // Silent failure - the chat will rebuild context if needed
      print('[ChatApi] ⚠️ Context update error (non-critical): $e');
    }
  }

  Future<bool> rebuildChatContext(String userId, {DateTime? date}) async {
    try {
      final dateStr = date != null
        ? DateFormat('yyyy-MM-dd').format(date)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

      print('[ChatApi] Force rebuilding chat context for $dateStr');

      final response = await _client.post(
        '/chat/context/rebuild/$userId?date=$dateStr',
      );

      if (response.statusCode == 200) {
        print('[ChatApi] ✅ Chat context rebuilt successfully');
        return true;
      } else {
        print('[ChatApi] ❌ Failed to rebuild context: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[ChatApi] ❌ Context rebuild error: $e');
      return false;
    }
  }

  Future<String> sendChatMessage(String userId, Map<String, dynamic> messageData) async {
    try {
      print('[ChatApi] Sending message for user: $userId');

      final response = await _client.post(
        '/chat',
        body: jsonEncode({
          'user_id': userId,
          'message': messageData['message'],
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'Sorry, I couldn\'t generate a response.';
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      print('[ChatApi] Error sending message: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getChatContext(String userId, {DateTime? date}) async {
    try {
      final dateStr = date != null
        ? DateFormat('yyyy-MM-dd').format(date)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await _client.get('/chat/context/$userId?date=$dateStr');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ChatApi] Context loaded (cached)');
        return data;
      } else {
        throw Exception('Failed to get context');
      }
    } catch (e) {
      print('[ChatApi] Error getting context: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> getCachedChatContext(String userId, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final response = await _client.get('/chat/context/cached/$userId?date=$dateStr');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get cached context');
      }
    } catch (e) {
      print('[ChatApi] Error getting cached context: $e');
      // Fallback to regular context
      return getChatContext(userId);
    }
  }

  Future<bool> checkAndResetDailyContext(String userId) async {
    try {
      // Check if context needs reset
      final checkResponse = await _client.get('/chat/context/check/$userId');

      if (checkResponse.statusCode == 200) {
        final checkData = jsonDecode(checkResponse.body);

        if (checkData['needs_reset'] == true) {
          print('[ChatApi] 📅 New day detected, resetting context...');

          // Trigger daily reset
          final resetResponse = await _client.post('/chat/context/daily-reset/$userId');

          if (resetResponse.statusCode == 200) {
            print('[ChatApi] ✅ Daily context reset complete');
            return true;
          }
        } else {
          print('[ChatApi] 📊 Context is current for today');
        }
      }
      return false;
    } catch (e) {
      print('[ChatApi] ❌ Daily context check error: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    try {
      final response = await _client.get('/chat/history/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['success'] == true && data['messages'] != null) {
          return List<Map<String, dynamic>>.from(data['messages']);
        }
      }
      return [];
    } catch (e) {
      print('[ChatApi] Chat history error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String userId) async {
    try {
      final response = await _client.get('/chat/messages/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['messages']);
        }
      }
      return [];
    } catch (e) {
      print('[ChatApi] Get chat messages error: $e');
      return [];
    }
  }

  Future<bool> clearChatMessages(String userId) async {
    try {
      final response = await _client.delete('/chat/messages/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[ChatApi] Clear chat messages error: $e');
      return false;
    }
  }

  Future<bool> clearChatHistory(String userId) async {
    try {
      final response = await _client.delete('/chat/history/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('[ChatApi] Clear chat history error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getUserFramework(String userId) async {
    try {
      print('[ChatApi] Getting user framework for: $userId');

      final response = await _client.get('/user/$userId/framework');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data is Map<String, dynamic>) {
          return data; // Return the whole response
        }
        return {'success': false, 'framework': null};
      } else {
        return {'success': false, 'framework': null};
      }
    } catch (e) {
      print('[ChatApi] Framework error: $e');
      return {'success': false, 'framework': null};
    }
  }

  Future<Map<String, dynamic>> compareFrameworks() async {
    try {
      final response = await _client.get('/frameworks/compare');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['frameworks'] ?? {};
      } else {
        throw Exception('Failed to get framework comparison: ${response.body}');
      }
    } catch (e) {
      print('[ChatApi] Framework comparison error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getWeeklyContext(String userId, {String? date}) async {
    try {
      final queryParams = date != null ? '?date=$date' : '';
      final response = await _client.get('/weekly/context/$userId$queryParams');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get weekly context');
      }
    } catch (e) {
      print('[ChatApi] Get weekly context error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentWeeks(String userId, {int weeks = 4}) async {
    try {
      final response = await _client.get('/weekly/recent/$userId?weeks=$weeks');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['weeks'] ?? []);
      } else {
        throw Exception('Failed to get recent weeks');
      }
    } catch (e) {
      print('[ChatApi] Get recent weeks error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> rebuildWeeklyContext(String userId, {String? date}) async {
    try {
      final body = date != null ? {'date': date} : {};
      final response = await _client.post('/weekly/rebuild/$userId', body: jsonEncode(body));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to rebuild weekly context');
      }
    } catch (e) {
      print('[ChatApi] Rebuild weekly context error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getWeeklySummaries(String userId, {int weeks = 12}) async {
    try {
      final response = await _client.get('/weekly/summary/$userId?weeks=$weeks');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['summaries'] ?? []);
      } else {
        throw Exception('Failed to get weekly summaries');
      }
    } catch (e) {
      print('[ChatApi] Get weekly summaries error: $e');
      return [];
    }
  }
}
