// lib/data/services/api/exercise_api.dart
import 'dart:convert';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Exercise tracking API.
class ExerciseApi {
  static final ExerciseApi _instance = ExerciseApi._internal();

  factory ExerciseApi() => _instance;

  ExerciseApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<Map<String, dynamic>> createExerciseEntry(Map<String, dynamic> exerciseData) async {
    // This just calls the existing logExercise method
    return await logExercise(exerciseData);
  }

  Future<Map<String, dynamic>> logExercise(Map<String, dynamic> exerciseData) async {
    try {
      print('[ExerciseApi] Logging exercise: ${exerciseData['exercise_name']}');

      final response = await _client.post(
        '/exercise/log',
        body: jsonEncode(exerciseData),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // ✅ UPDATE CHAT CONTEXT
        await _chat.updateChatContext(
          exerciseData['user_id'],
          'exercise',
          responseData['exercise'] ?? exerciseData
        );

        return responseData;
      } else {
        throw Exception('Failed to log exercise');
      }
    } catch (e) {
      print('[ExerciseApi] Exercise log error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExerciseLogs(
    String userId, {
    String? startDate,
    String? endDate,
    String? exerciseType,
    int limit = 50,
  }) async {
    try {
      print('[ExerciseApi] Getting exercise logs for user: $userId');

      String url = '/exercise/logs/$userId?limit=$limit';

      if (startDate != null) url += '&start_date=$startDate';
      if (endDate != null) url += '&end_date=$endDate';
      if (exerciseType != null) url += '&exercise_type=$exerciseType';

      print('[ExerciseApi] Exercise logs URL: $url');

      final response = await _client.get(url);

      print('[ExerciseApi] Exercise logs response status: ${response.statusCode}');
      print('[ExerciseApi] Exercise logs response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Handle different response formats
        if (data is Map<String, dynamic>) {
          if (data['exercises'] != null && data['exercises'] is List) {
            return List<Map<String, dynamic>>.from(data['exercises']);
          }
          if (data['success'] == true && data['exercises'] is List) {
            return List<Map<String, dynamic>>.from(data['exercises']);
          }
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }

        print('[ExerciseApi] No exercises found in response');
        return [];
      } else {
        print('[ExerciseApi] Exercise logs error: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[ExerciseApi] Exercise logs error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getExerciseStats(String userId, {int days = 30}) async {
    try {
      print('[ExerciseApi] Getting exercise stats for user: $userId');

      final response = await _client.get('/exercise/stats/$userId?days=$days');

      print('[ExerciseApi] Exercise stats response status: ${response.statusCode}');
      print('[ExerciseApi] Exercise stats response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Handle different response formats
        if (data is Map<String, dynamic>) {
          if (data['stats'] != null && data['stats'] is Map) {
            return Map<String, dynamic>.from(data['stats']);
          }
        }

        // ✅ Return default stats if response is unexpected format
        print('[ExerciseApi] Unexpected stats response format, returning defaults');
        return _getDefaultStats();
      } else {
        print('[ExerciseApi] Exercise stats error: ${response.body}');
        return _getDefaultStats();
      }
    } catch (e) {
      print('[ExerciseApi] Exercise stats error: $e');
      return _getDefaultStats();
    }
  }

  Map<String, dynamic> _getDefaultStats() {
    return {
      'total_workouts': 0,
      'total_minutes': 0,
      'total_calories': 0.0,
      'avg_duration': 0.0,
      'most_common_type': null,
      'type_breakdown': <String, int>{},
    };
  }

  Future<void> deleteExerciseLog(String exerciseId, String userId) async {
    try {
      final response = await _client.delete('/exercise/log/$exerciseId?user_id=$userId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete exercise: ${response.body}');
      }
    } catch (e) {
      print('Error deleting exercise: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExerciseHistory(
    String userId, {
    String? date,
    int limit = 20,
  }) async {
    try {
      String url = '/exercise/history/$userId?limit=$limit';
      if (date != null) {
        url += '&date=$date';
      }

      print('[ExerciseApi] Fetching exercise history: $url');

      final response = await _client.get(url);

      print('[ExerciseApi] Exercise history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['exercises'] ?? []);
      } else {
        print('[ExerciseApi] Failed to get exercise history: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[ExerciseApi] Get exercise history error: $e');
      return [];
    }
  }

  // Add method to get weekly summary
  Future<Map<String, dynamic>> getWeeklyExerciseSummary(String userId) async {
    try {
      final response = await _client.get('/exercise/weekly-summary/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['summary'] ?? {};
      } else {
        print('[ExerciseApi] Weekly summary error: ${response.body}');
        return {};
      }
    } catch (e) {
      print('[ExerciseApi] Weekly summary error: $e');
      return {};
    }
  }

  // Add method to delete exercise
  Future<bool> deleteExercise(String exerciseId) async {
    try {
      final response = await _client.delete('/exercise/$exerciseId');

      return response.statusCode == 200;
    } catch (e) {
      print('[ExerciseApi] Delete exercise error: $e');
      return false;
    }
  }

  // Add method to update exercise
  Future<Map<String, dynamic>> updateExercise(
    String exerciseId,
    Map<String, dynamic> updateData
  ) async {
    try {
      final response = await _client.put(
        '/exercise/$exerciseId',
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update exercise');
      }
    } catch (e) {
      print('[ExerciseApi] Update exercise error: $e');
      return {'success': false};
    }
  }
}
