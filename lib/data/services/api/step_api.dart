// lib/data/services/api/step_api.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Step tracking API.
class StepApi {
  static final StepApi _instance = StepApi._internal();

  factory StepApi() => _instance;

  StepApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<StepEntry?> getTodaySteps(String userId) async {
    try {
      print('[StepApi] Getting today\'s steps for user: $userId');

      final response = await _client.get('/steps/$userId/today');

      print('[StepApi] Today\'s steps response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        // Handle if response is a Map with 'entry' field
        if (responseData is Map<String, dynamic>) {
          final Map<String, dynamic> data = responseData;

          if (data['entry'] != null && data['entry'] is Map<String, dynamic>) {
            return StepEntry.fromMap(data['entry'] as Map<String, dynamic>);
          }
        }

        // Handle if response is directly a StepEntry object
        if (responseData is Map<String, dynamic>) {
          return StepEntry.fromMap(responseData);
        }

        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        print('[StepApi] Today\'s steps HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('[StepApi] Today\'s steps error: $e');
      return null;
    }
  }

  Future<StepEntry?> getStepsByDate(String userId, String date) async {
    try {
      final response = await _client.get('/steps/$userId?date=$date');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['entry'] != null) {
          return StepEntry.fromMap(data['entry']);
        }
      }
      return null;
    } catch (e) {
      print('Error getting steps by date: $e');
      return null;
    }
  }

  Future<List<StepEntry>> getStepsInRange(
    String userId,
    DateTime startDate,
    DateTime endDate
  ) async {
    try {
      final start = DateFormat('yyyy-MM-dd').format(startDate);
      final end = DateFormat('yyyy-MM-dd').format(endDate);
      final response = await _client.get('/steps/$userId/range?start=$start&end=$end');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['entries'] != null) {
          return (data['entries'] as List)
              .map((e) => StepEntry.fromMap(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting steps in range: $e');
      return [];
    }
  }

  Future<void> saveStepEntry(StepEntry entry) async {
    try {
      final response = await _client.post(
        '/steps',
        body: jsonEncode(entry.toMap()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ UPDATE CHAT CONTEXT
        await _chat.updateChatContext(
          entry.userId,
          'steps',
          entry.toMap(),
          date: entry.date
        );
      } else {
        throw Exception('Failed to save step entry');
      }
    } catch (e) {
      throw Exception('Failed to save step entry: $e');
    }
  }

  Future<List<StepEntry>> getAllSteps(String userId) async {
    try {
      print('[StepApi] Getting all steps for user: $userId');

      final response = await _client.get('/steps/$userId');

      print('[StepApi] All steps response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        // Handle if response is directly a List
        if (responseData is List) {
          print('[StepApi] Response is a direct list with ${responseData.length} items');
          return responseData
              .where((item) => item is Map<String, dynamic>)
              .map<StepEntry>((item) => StepEntry.fromMap(item as Map<String, dynamic>))
              .toList();
        }

        // Handle if response is a Map with 'entries' field
        if (responseData is Map<String, dynamic>) {
          final Map<String, dynamic> data = responseData;

          if (data['entries'] != null && data['entries'] is List) {
            final List<dynamic> entries = data['entries'] as List<dynamic>;
            print('[StepApi] Found ${entries.length} step entries in entries field');

            return entries
                .where((item) => item is Map<String, dynamic>)
                .map<StepEntry>((item) => StepEntry.fromMap(item as Map<String, dynamic>))
                .toList();
          }
        }

        print('[StepApi] No valid entries found in response');
        print('[StepApi] Response structure: ${responseData.runtimeType}');
        return [];
      } else {
        print('[StepApi] HTTP Error ${response.statusCode}: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[StepApi] Get all steps error: $e');
      return [];
    }
  }

  Future<void> deleteStepEntry(String userId, DateTime date) async {
    try {
      final response = await _client.delete('/steps/$userId/${date.toIso8601String()}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete step entry: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to delete step entry: $e');
    }
  }

  Future<Map<String, dynamic>> getStepStats(String userId, {int days = 7}) async {
    try {
      print('[StepApi] Getting step stats for user: $userId, days: $days');

      final response = await _client.get('/steps/$userId/stats?days=$days');

      print('[StepApi] Step stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'] ?? {};
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get step stats');
      }
    } catch (e) {
      print('[StepApi] Step stats error: $e');
      return {};
    }
  }
}
