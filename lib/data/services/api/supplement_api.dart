// lib/data/services/api/supplement_api.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Supplement tracking API.
class SupplementApi {
  static final SupplementApi _instance = SupplementApi._internal();

  factory SupplementApi() => _instance;

  SupplementApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<Map<String, dynamic>> saveSupplementPreferences(String userId, List<Map<String, dynamic>> supplements) async {
    try {
      print('[SupplementApi] Saving supplement preferences for user: $userId');

      final response = await _client.post(
        '/supplements/preferences',
        body: jsonEncode({
          'user_id': userId,
          'supplements': supplements,
        }),
      );

      print('[SupplementApi] Save preferences response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to save supplement preferences');
      }
    } catch (e) {
      print('[SupplementApi] Error saving supplement preferences: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSupplementStatus(String userId, {String? date}) async {
    try {
      print('[SupplementApi] 💊 Getting supplement status for user: $userId');

      String url = '/supplements/status/$userId';
      if (date != null) {
        url += '?date=$date';
      }

      print('[SupplementApi] 💊 Status URL: $url');

      final response = await _client.get(url);

      print('[SupplementApi] 💊 Status response status: ${response.statusCode}');
      print('[SupplementApi] 💊 Status response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('[SupplementApi] 💊 Status error response: ${response.body}');
        return {'success': false, 'status': {}};
      }
    } catch (e) {
      print('[SupplementApi] 💊 Status error: $e');
      return {'success': false, 'status': {}};
    }
  }

  Future<Map<String, bool>> getSupplementStatusByDate(String userId, String date) async {
    try {
      final response = await _client.get('/supplements/$userId/status?date=$date');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['status'] != null) {
          return _parseStatusMap(data['status']);
        }
      }
      return {};
    } catch (e) {
      print('Error getting supplement status by date: $e');
      return {};
    }
  }

  /// The backend returns supplement status either as `{name: bool}` or as
  /// `{name: {"taken": bool, ...}}`. Normalise both into `{name: bool}`.
  Map<String, bool> _parseStatusMap(dynamic status) {
    final result = <String, bool>{};
    if (status is Map) {
      status.forEach((key, value) {
        if (value is bool) {
          result[key.toString()] = value;
        } else if (value is Map) {
          result[key.toString()] = value['taken'] == true;
        }
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getSupplementHistoryInRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final start = DateFormat('yyyy-MM-dd').format(startDate);
      final end = DateFormat('yyyy-MM-dd').format(endDate);
      final response = await _client.get('/supplements/$userId/history?start=$start&end=$end');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['history'] != null) {
          return List<Map<String, dynamic>>.from(data['history']);
        }
      }
      return [];
    } catch (e) {
      print('Error getting supplement history: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSupplementPreferences(String userId) async {
    try {
      print('[SupplementApi] Getting supplement preferences for user: $userId');

      final response = await _client.get('/supplements/preferences/$userId');

      print('[SupplementApi] Get preferences response status: ${response.statusCode}');
      print('[SupplementApi] Get preferences response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['preferences'] != null) {
          print('[SupplementApi] Successfully parsed ${data['preferences'].length} preferences');
          return List<Map<String, dynamic>>.from(data['preferences']);
        }
        return [];
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get supplement preferences');
      }
    } catch (e) {
      print('[SupplementApi] Error getting supplement preferences: $e');
      return []; // Return empty list on error instead of throwing
    }
  }

  // Log daily supplement intake
  Future<Map<String, dynamic>> logSupplementIntake(Map<String, dynamic> logData) async {
    try {
      print('[SupplementApi] Logging supplement intake: ${logData['supplement_name']} = ${logData['taken']}');

      final response = await _client.post(
        '/supplements/log',
        body: jsonEncode(logData),
      );

      print('[SupplementApi] Log supplement response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // ✅ UPDATE CHAT CONTEXT
        await _chat.updateChatContext(
          logData['user_id'],
          'supplement',
          logData
        );

        return responseData;
      } else {
        throw Exception('Failed to save supplement entry');
      }
    } catch (e) {
      print('[SupplementApi] Supplement save error: $e');
      rethrow;
    }
  }

  // Get supplement history
  Future<List<Map<String, dynamic>>> getSupplementHistory(String userId, {String? supplementName, int days = 30}) async {
    try {
      print('[SupplementApi] Getting supplement history for user: $userId');

      String url = '/supplements/history/$userId?days=$days';
      if (supplementName != null) {
        url += '&supplement_name=$supplementName';
      }

      final response = await _client.get(url);

      print('[SupplementApi] Supplement history response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get supplement history');
      }
    } catch (e) {
      print('[SupplementApi] Supplement history error: $e');
      return [];
    }
  }

  Future<Map<String, bool>> getTodaysSupplementStatus(String userId) async {
    try {
      print('[SupplementApi] Getting today\'s supplement status for user: $userId');

      final response = await _client.get('/supplements/status/$userId');

      print('[SupplementApi] Supplement status response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['status'] != null) {
          return _parseStatusMap(data['status']);
        }
        return {};
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get supplement status');
      }
    } catch (e) {
      print('[SupplementApi] Error getting supplement status: $e');
      return {}; // Return empty map on error instead of throwing
    }
  }
}
