// lib/data/services/api/water_api.dart
import 'dart:convert';
import 'package:user_onboarding/data/models/water_entry.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Water tracking API.
class WaterApi {
  static final WaterApi _instance = WaterApi._internal();

  factory WaterApi() => _instance;

  WaterApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<String> saveWaterEntry(WaterEntry waterEntry) async {
    try {
      print('[WaterApi] Saving water entry: ${waterEntry.glassesConsumed} glasses');

      final response = await _client.post(
        '/water',
        body: jsonEncode(waterEntry.toMap()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final entryId = data['id'] ?? waterEntry.id ?? DateTime.now( ).millisecondsSinceEpoch.toString(); 

        // ✅ UPDATE CHAT CONTEXT
        await _chat.updateChatContext(
          waterEntry.userId,
          'water',
          waterEntry.toMap(),
          date: waterEntry.date
        );

        await _chat.rebuildChatContext(waterEntry.userId);

        return entryId;
      } else {
        throw Exception('Failed to save water entry');
      }
    } catch (e) {
      print('[WaterApi] Water save error: $e');
      rethrow;
    }
  }

  // Get water history
  Future<List<WaterEntry>> getWaterHistory(String userId, {int limit = 30}) async {
    try {
      final response = await _client.get('/water/$userId?limit=$limit');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['entries'] != null) {
          return (data['entries'] as List)
              .map((entry) => WaterEntry.fromMap(entry))
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('Error getting water history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getWaterStats(String userId, {int days = 7}) async {
    try {
      print('[WaterApi] Getting water stats for user: $userId, days: $days');

      final response = await _client.get('/water/$userId/stats?days=$days');

      print('[WaterApi] Water stats response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['stats'] ?? {};
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get water stats');
      }
    } catch (e) {
      print('[WaterApi] Water stats error: $e');
      return {};
    }
  }

  // Get today's water entry
  Future<Map<String, dynamic>> getTodaysWater(String userId) async {
    try {
      print('[WaterApi] 💧 Getting today\'s water for user: $userId');

      final response = await _client.get('/water/$userId/today');

      print('[WaterApi] 💧 Water response status: ${response.statusCode}');
      print('[WaterApi] 💧 Water response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is Map<String, dynamic>) {
          final entry = data['entry'];

          if (entry == null) {
            // No water logged today - return default structure
            return {
              'success': true,
              'glasses': 0,
              'total_ml': 0.0,
              'target_ml': 2000.0,
              'entry': null,
            };
          }

          // Parse the entry safely
          return {
            'success': true,
            'glasses': (entry['glasses_consumed'] ?? 0).toInt(),
            'total_ml': (entry['total_ml'] ?? 0.0).toDouble(),
            'target_ml': (entry['target_ml'] ?? 2000.0).toDouble(),
            'entry': entry,
          };
        }
      }

      // Error case
      return {
        'success': false,
        'glasses': 0,
        'total_ml': 0.0,
        'target_ml': 2000.0,
        'entry': null,
      };
    } catch (e) {
      print('[WaterApi] 💧 Water error: $e');
      return {
        'success': false,
        'glasses': 0,
        'total_ml': 0.0,
        'target_ml': 2000.0,
        'entry': null,
      };
    }
  }

  Future<Map<String, dynamic>> getWaterByDate(String userId, String date) async {
    try {
      final response = await _client.get('/water/$userId?date=$date');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false};
    } catch (e) {
      print('Error getting water by date: $e');
      return {'success': false};
    }
  }
}
