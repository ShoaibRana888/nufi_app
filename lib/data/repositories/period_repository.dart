// lib/data/repositories/period_repository.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:user_onboarding/data/models/period_entry.dart';
import 'package:user_onboarding/data/services/api/period_api.dart';
import 'package:user_onboarding/data/services/database_service.dart';

class PeriodRepository {
  static final PeriodApi _apiService = PeriodApi();

  static Future<String> savePeriodEntry(PeriodEntry entry) async {
    final id = entry.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Primary path: API (source of truth for logging).
    try {
      return await _apiService.savePeriodEntry(entry);
    } catch (apiError) {
      print('⚠️ API period save failed, attempting offline DB fallback: $apiError');

      // Offline fallback: direct DB.
      if (!kIsWeb && DatabaseService.isInitialized) {
        try {
          await DatabaseService.insertPeriod(r'''
            INSERT INTO period_tracking (id, user_id, start_date, end_date, flow_intensity, symptoms, mood, notes)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (id) DO UPDATE SET
              end_date = $4,
              flow_intensity = $5,
              symptoms = $6,
              mood = $7,
              notes = $8
          ''', [
            id,
            entry.userId,
            entry.startDate.toIso8601String(),
            entry.endDate?.toIso8601String(),
            entry.flowIntensity,
            entry.symptoms,
            entry.mood,
            entry.notes,
          ]);
          return id;
        } catch (dbError) {
          print('❌ Offline DB fallback also failed: $dbError');
        }
      }

      // Both paths failed — surface the error so the UI can react.
      rethrow;
    }
  }

  static Future<bool> deletePeriodEntry(String periodId) async {
    // Primary path: API.
    try {
      return await _apiService.deletePeriodEntry(periodId);
    } catch (apiError) {
      print('⚠️ API period delete failed, attempting offline DB fallback: $apiError');

      // Offline fallback: direct DB.
      if (!kIsWeb && DatabaseService.isInitialized) {
        try {
          await DatabaseService.execute(
            'DELETE FROM period_tracking WHERE id = @id',
            {'id': periodId}
          );
          return true;
        } catch (dbError) {
          print('❌ Offline DB fallback also failed: $dbError');
        }
      }
      return false;
    }
  }

  static Future<List<PeriodEntry>> getPeriodHistory(String userId, {int limit = 12}) async {
    // Primary path: API.
    try {
      return await _apiService.getPeriodHistory(userId, limit: limit);
    } catch (apiError) {
      print('⚠️ API period history failed, attempting offline DB fallback: $apiError');

      // Offline fallback: direct DB.
      if (!kIsWeb && DatabaseService.isInitialized) {
        try {
          final results = await DatabaseService.queryPeriods(r'''
            SELECT * FROM period_tracking
            WHERE user_id = $1
            ORDER BY start_date DESC
            LIMIT $2
          ''', [userId, limit]);

          return results.map((row) => PeriodEntry.fromMap(row)).toList();
        } catch (dbError) {
          print('Error fetching period history from DB: $dbError');
        }
      }
      return [];
    }
  }

  static Future<PeriodEntry?> getCurrentPeriod(String userId) async {
    try {
      final history = await getPeriodHistory(userId, limit: 1);
      if (history.isNotEmpty && history.first.endDate == null) {
        return history.first;
      }
      return null;
    } catch (e) {
      print('Error fetching current period: $e');
      return null;
    }
  }
}