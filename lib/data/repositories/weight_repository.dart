// lib/data/repositories/weight_repository.dart
import 'package:uuid/uuid.dart';
import 'package:user_onboarding/data/models/weight_entry.dart';
import 'package:user_onboarding/data/services/database_service.dart';
import 'package:user_onboarding/data/services/api/weight_api.dart';

class WeightRepository {
  static final Uuid _uuid = Uuid();

  static Future<String> saveWeightEntry(WeightEntry weightEntry) async {
    try {
      // Use API service instead of database
      final apiService = WeightApi();
      return await apiService.saveWeightEntry(weightEntry);
    } catch (e) {
      print('[WeightRepository] Failed to save weight entry: $e');
      rethrow;
    }
  }

  static Future<List<WeightEntry>> getWeightHistory(String userId, {int limit = 50}) async {
    try {
      // Use API service instead of database
      final apiService = WeightApi();
      return await apiService.getWeightHistory(userId, limit: limit);
    } catch (e) {
      print('[WeightRepository] Failed to get weight history: $e');
      return [];
    }
  }

  static Future<WeightEntry?> getLatestWeight(String userId) async {
    try {
      // Use API service instead of database
      final apiService = WeightApi();
      return await apiService.getLatestWeight(userId);
    } catch (e) {
      print('[WeightRepository] Failed to get latest weight: $e');
      return null;
    }
  }

  static Future<bool> deleteWeightEntry(String id) async {
    try {
      await DatabaseService.execute('''
        DELETE FROM weight_entries WHERE id = @id
      ''', {
        'id': id,
      });
      return true;
    } catch (e) {
      print('[WeightRepository] Failed to delete weight entry: $e');
      return false;
    }
  }

  static Future<WeightEntry?> getWeightForDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final result = await DatabaseService.query('''
        SELECT * FROM weight_entries 
        WHERE user_id = @userId 
        AND date >= @startDate 
        AND date < @endDate
        ORDER BY date DESC 
        LIMIT 1
      ''', {
        'userId': userId,
        'startDate': startOfDay.toIso8601String(),
        'endDate': endOfDay.toIso8601String(),
      });

      if (result.isNotEmpty) {
        return WeightEntry.fromMap(result.first);
      }
      return null;
    } catch (e) {
      print('[WeightRepository] Failed to get weight for date: $e');
      return null;
    }
  }
}