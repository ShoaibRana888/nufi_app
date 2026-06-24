// lib/data/services/api/sleep_api.dart
import 'dart:convert';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Sleep tracking API.
class SleepApi {
  static final SleepApi _instance = SleepApi._internal();

  factory SleepApi() => _instance;

  SleepApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<Map<String, dynamic>> createSleepEntry(Map<String, dynamic> sleepData) async {
    try {
      print('[SleepApi] Saving sleep entry');

      final response = await _client.post(
        '/sleep/entries',
        body: jsonEncode(sleepData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // ✅ UPDATE CHAT CONTEXT
        await _chat.updateChatContext(
          sleepData['user_id'],
          'sleep',
          responseData['entry'] ?? sleepData
        );

        return responseData;
      } else {
        throw Exception('Failed to save sleep entry');
      }
    } catch (e) {
      print('[SleepApi] Sleep save error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSleepEntryByDate(String userId, String date) async {
    try {
      print('[SleepApi] Getting sleep entry for user: $userId, date: $date');

      final response = await _client.get('/sleep/entries/$userId/$date');

      print('[SleepApi] Sleep entry response status: ${response.statusCode}');
      print('[SleepApi] Sleep entry response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        print('[SleepApi] No sleep entry found for date: $date');
        return null;
      } else {
        print('[SleepApi] Sleep entry error response: ${response.body}');
        throw Exception('Failed to get sleep entry: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[SleepApi] Get sleep entry error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateSleepEntry(String entryId, Map<String, dynamic> updateData) async {
    try {
      final response = await _client.put(
        '/sleep/entries/$entryId',
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update sleep entry');
      }
    } catch (e) {
      print('[SleepApi] Update sleep entry error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSleepHistory(String userId, {int limit = 30}) async {
    try {
      print('[SleepApi] Getting sleep history for user: $userId');

      // Make sure to use the correct URL
      final url = '/sleep/entries/$userId?limit=$limit';
      print('[SleepApi] Request URL: $url');

      final response = await _client.get(url);

      print('[SleepApi] Sleep history response status: ${response.statusCode}');
      print('[SleepApi] Sleep history response body: ${response.body}');

      if (response.statusCode == 200) {
        // The backend returns an array directly
        final dynamic decodedBody = jsonDecode(response.body);
        print('[SleepApi] Decoded body type: ${decodedBody.runtimeType}');

        if (decodedBody is List) {
          final List<Map<String, dynamic>> result = [];
          for (var item in decodedBody) {
            result.add(Map<String, dynamic>.from(item));
          }
          print('[SleepApi] Returning ${result.length} entries');
          return result;
        } else {
          print('[SleepApi] ERROR: Response is not a List, it is: ${decodedBody.runtimeType}');
          return [];
        }
      } else {
        print('[SleepApi] Failed to get sleep history. Status: ${response.statusCode}');
        print('[SleepApi] Error body: ${response.body}');
        return [];
      }
    } catch (e, stackTrace) {
      print('[SleepApi] Sleep history error: $e');
      print('[SleepApi] Stack trace: $stackTrace');
      return [];
    }
  }

  Future<bool> deleteSleepEntry(String entryId) async {
    try {
      print('[SleepApi] Deleting sleep entry: $entryId');

      final response = await _client.delete('/sleep/entries/$entryId');

      print('[SleepApi] Delete sleep response status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('[SleepApi] Delete sleep error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getSleepStats(String userId, {int days = 30}) async {
    try {
      print('[SleepApi] Getting sleep stats for user: $userId, days: $days');

      final response = await _client.get('/sleep/stats/$userId?days=$days');

      print('[SleepApi] Sleep stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'] ?? {};
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get sleep stats');
      }
    } catch (e) {
      print('[SleepApi] Sleep stats error: $e');
      return {};
    }
  }
}
