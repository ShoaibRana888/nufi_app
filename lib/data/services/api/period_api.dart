// lib/data/services/api/period_api.dart
import 'dart:convert';
import 'package:user_onboarding/data/models/period_entry.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';

/// Period tracking API.
class PeriodApi {
  static final PeriodApi _instance = PeriodApi._internal();

  factory PeriodApi() => _instance;

  PeriodApi._internal();

  final ApiClient _client = ApiClient();

  Future<String> savePeriodEntry(PeriodEntry entry) async {
    try {
      final response = await _client.post(
        '/period',
        body: jsonEncode({
          'id': entry.id,
          'user_id': entry.userId,
          'start_date': entry.startDate.toIso8601String(),
          'end_date': entry.endDate?.toIso8601String(),
          'flow_intensity': entry.flowIntensity,
          'symptoms': entry.symptoms,
          'mood': entry.mood,
          'notes': entry.notes,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['id'] ?? entry.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      } else {
        throw Exception('Failed to save period entry: ${response.body}');
      }
    } catch (e) {
      print('Error saving period entry to API: $e');
      rethrow;
    }
  }

  Future<List<PeriodEntry>> getPeriodHistory(String userId, {int limit = 12}) async {
    try {
      print('[PeriodApi] Getting period history for user: $userId');

      final response = await _client.get('/period/$userId?limit=$limit');

      print('[PeriodApi] Period history response status: ${response.statusCode}');
      print('[PeriodApi] Period history response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);

        // ✅ Handle different response formats
        List<dynamic> periodsData = [];

        if (responseData is Map<String, dynamic>) {
          // If response is wrapped in an object
          if (responseData['periods'] != null && responseData['periods'] is List) {
            periodsData = responseData['periods'];
          } else if (responseData['success'] == true && responseData['periods'] is List) {
            periodsData = responseData['periods'];
          }
        } else if (responseData is List) {
          // If response is directly a list
          periodsData = responseData;
        }

        return periodsData
            .where((item) => item is Map<String, dynamic>)
            .map<PeriodEntry>((item) => PeriodEntry.fromMap(item as Map<String, dynamic>))
            .toList();
      } else {
        print('[PeriodApi] Period history error: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[PeriodApi] Period history error: $e');
      return [];
    }
  }

  Future<PeriodEntry?> getCurrentPeriod(String userId) async {
    try {
      final response = await _client.get('/period/$userId/current');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          return PeriodEntry.fromMap(data);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching current period from API: $e');
      return null;
    }
  }

  Future<bool> deletePeriodEntry(String periodId) async {
    try {
      final response = await _client.delete('/period/$periodId');

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting period entry from API: $e');
      return false;
    }
  }

  Future<bool> endPeriod(String periodId, DateTime endDate) async {
    try {
      final response = await _client.put(
        '/period/$periodId/end',
        body: jsonEncode({
          'end_date': endDate.toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error ending period: $e');
      return false;
    }
  }

  Future<String> createCustomPeriod(PeriodEntry entry) async {
    try {
      final response = await _client.post(
        '/period/custom',
        body: jsonEncode({
          'user_id': entry.userId,
          'start_date': entry.startDate.toIso8601String(),
          'end_date': entry.endDate?.toIso8601String(),
          'flow_intensity': entry.flowIntensity,
          'symptoms': entry.symptoms,
          'mood': entry.mood,
          'notes': entry.notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      } else {
        throw Exception('Failed to create custom period: ${response.body}');
      }
    } catch (e) {
      print('Error creating custom period: $e');
      rethrow;
    }
  }
}
