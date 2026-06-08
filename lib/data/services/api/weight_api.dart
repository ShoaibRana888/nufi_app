// lib/data/services/api/weight_api.dart
import 'dart:convert';
import 'package:user_onboarding/data/models/weight_entry.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Weight tracking API.
class WeightApi {
  static final WeightApi _instance = WeightApi._internal();

  factory WeightApi() => _instance;

  WeightApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<String> saveWeightEntry(WeightEntry weightEntry) async {
    try {
      print('[WeightApi] Saving weight entry: ${weightEntry.weight} kg');

      final response = await _client.post(
        '/weight',
        body: jsonEncode({
          'user_id': weightEntry.userId,
          'date': weightEntry.date.toIso8601String(),
          'weight': weightEntry.weight,
          'notes': weightEntry.notes,
          'body_fat_percentage': weightEntry.bodyFatPercentage,
          'muscle_mass_kg': weightEntry.muscleMassKg,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final entryId = data['id'] ?? weightEntry.id;

        // ✅ UPDATE CHAT CONTEXT
        await _chat.updateChatContext(
          weightEntry.userId,
          'weight',
          {'weight': weightEntry.weight},
          date: weightEntry.date
        );

        await _chat.rebuildChatContext(weightEntry.userId);

        return entryId;
      } else {
        throw Exception('Failed to save weight entry');
      }
    } catch (e) {
      print('[WeightApi] Weight entry error: $e');
      rethrow;
    }
  }

  // Get weight history
  Future<List<WeightEntry>> getWeightHistory(String userId, {int limit = 50}) async {
    try {
      print('[WeightApi] Getting weight history for user: $userId');

      final response = await _client.get('/weight/$userId?limit=$limit');

      print('[WeightApi] Weight history response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['weights'] != null && data['weights'] is List) {
          return (data['weights'] as List)
              .map((item) => WeightEntry.fromMap(item))
              .toList();
        }
        return [];
      } else {
        print('[WeightApi] Weight history error response: ${response.body}');
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get weight history');
      }
    } catch (e) {
      print('[WeightApi] Weight history error: $e');
      return [];
    }
  }

  // Get latest weight entry
  Future<WeightEntry?> getLatestWeight(String userId) async {
    try {
      print('[WeightApi] Getting latest weight for user: $userId');

      final response = await _client.get('/weight/$userId/latest');

      print('[WeightApi] Latest weight response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['weight'] != null) {
          return WeightEntry.fromMap(data['weight']);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to get latest weight');
      }
    } catch (e) {
      print('[WeightApi] Latest weight error: $e');
      return null;
    }
  }

  // Delete weight entry
  Future<bool> deleteWeightEntry(String entryId) async {
    try {
      print('[WeightApi] Deleting weight entry: $entryId');

      final response = await _client.delete('/weight/$entryId');

      print('[WeightApi] Delete weight response status: ${response.statusCode}');

      return response.statusCode == 200;
    } catch (e) {
      print('[WeightApi] Delete weight error: $e');
      return false;
    }
  }

  // Update user's current weight in profile
  Future<void> updateUserWeight(String userId, double newWeight) async {
    try {
      print('[WeightApi] Updating user weight to $newWeight kg');

      final response = await _client.patch(
        '/user/$userId/weight',
        body: jsonEncode({
          'weight': newWeight,
        }),
      );

      print('[WeightApi] Update weight response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update user weight');
      }
    } catch (e) {
      print('[WeightApi] Update weight error: $e');
      rethrow;
    }
  }

  Future<bool> setStartingWeight(String userId, double startingWeight) async {
    try {
      print('[WeightApi] Setting starting weight: $startingWeight kg for user: $userId');

      final response = await _client.post(
        '/user/$userId/set-starting-weight',
        body: jsonEncode({
          'starting_weight': startingWeight,
        }),
      );

      print('[WeightApi] Set starting weight response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[WeightApi] Starting weight set successfully');
        return true;
      } else {
        print('[WeightApi] Failed to set starting weight: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[WeightApi] Starting weight error: $e');
      return false;
    }
  }
}
