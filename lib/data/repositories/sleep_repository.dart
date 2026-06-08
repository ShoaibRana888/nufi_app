import 'package:user_onboarding/data/models/sleep_entry.dart';
import 'package:user_onboarding/data/services/api/sleep_api.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class SleepRepository {
  final _uuid = const Uuid();
  final SleepApi _apiService = SleepApi();
  static const String _sleepEntriesKey = 'sleep_entries';

  // Create sleep entry using API
  Future<SleepEntry> createSleepEntry(SleepEntry entry) async {
    final id = _uuid.v4();
    final entryWithId = entry.copyWith(id: id);
    
    // Always save to local storage first
    await _saveToLocalStorage(entryWithId);
    print('✅ Sleep entry saved to local storage');
    
    // Try to sync with backend
    try {
      final response = await _apiService.createSleepEntry({
        'user_id': entry.userId,
        'date': "${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}-${entry.date.day.toString().padLeft(2, '0')}",
        'bedtime': entry.bedtime?.toIso8601String(),
        'wake_time': entry.wakeTime?.toIso8601String(),
        'total_hours': entry.totalHours,
        'quality_score': entry.qualityScore,
        'deep_sleep_hours': entry.deepSleepHours,
      });
      
      print('✅ Sleep entry synced to backend');
      
      // Update local entry with server ID if different
      if (response['id'] != null && response['id'] != id) {
        final serverEntry = entryWithId.copyWith(id: response['id']);
        await _saveToLocalStorage(serverEntry);
        return serverEntry;
      }
    } catch (e) {
      // Check if it's a duplicate entry error
      if (e.toString().contains('already exists')) {
        print('⚠️ Entry already exists, updating instead');
        // Try to update instead
        return await updateSleepEntry(entryWithId);
      } else {
        print('📱 Backend unavailable, will sync later: $e');
      }
    }
    
    return entryWithId;
  }

  // Update sleep entry using API
  Future<SleepEntry> updateSleepEntry(SleepEntry entry) async {
    // Update local storage first
    await _updateInLocalStorage(entry);
    print('✅ Sleep entry updated in local storage');
    
    // Try to sync with backend
    try {
      if (entry.id != null) {
        await _apiService.updateSleepEntry(entry.id!, {
          'bedtime': entry.bedtime?.toIso8601String(),
          'wake_time': entry.wakeTime?.toIso8601String(),
          'total_hours': entry.totalHours,
          'quality_score': entry.qualityScore,
          'deep_sleep_hours': entry.deepSleepHours,
        });
        print('✅ Sleep entry synced to backend');
      }
    } catch (e) {
      print('📱 Backend update failed, using local storage: $e');
    }
    
    return entry;
  }

  // Get sleep entry by date using API
  Future<SleepEntry?> getSleepEntryByDate(String userId, DateTime date) async {
    try {
      print('[SleepRepository] Getting sleep entry for date: ${DateFormat('yyyy-MM-dd').format(date)}');
      
      final response = await _apiService.getSleepEntryByDate(
        userId, 
        DateFormat('yyyy-MM-dd').format(date)
      );
      
      // Check if response and entry exist
      if (response != null && response['success'] == true && response['entry'] != null) {
        print('Sleep entry found in backend');
        // Pass only the entry data, not the whole response
        return SleepEntry.fromMap(response['entry']);
      } else {
        print('No sleep entry found for date: ${DateFormat('yyyy-MM-dd').format(date)}');
        return null;
      }
      
    } catch (e) {
      print('Error getting sleep entry: $e');
      return null;
    }
  }

  // Get sleep history using API
  Future<List<SleepEntry>> getSleepHistory(String userId, {int limit = 30}) async {
    print('📊 Getting sleep history for user: $userId');
    
    // Try backend first
    try {
      final response = await _apiService.getSleepHistory(userId, limit: limit);
      
      print('[SleepRepository] Raw API response: $response');
      print('[SleepRepository] Response type: ${response.runtimeType}');
      print('[SleepRepository] Response length: ${response.length}');
      
      if (response.isNotEmpty) {
        print('[SleepRepository] First entry raw data: ${response.first}');
        
        // Parse each entry
        final entries = <SleepEntry>[];
        for (var data in response) {
          try {
            print('[SleepRepository] Parsing entry: $data');
            final entry = SleepEntry.fromMap(data);
            entries.add(entry);
            print('[SleepRepository] Successfully parsed entry with id: ${entry.id}');
          } catch (e) {
            print('[SleepRepository] ❌ Error parsing entry: $e');
            print('[SleepRepository] Problematic data: $data');
          }
        }
        
        print('✅ Sleep history loaded from backend: ${entries.length} entries');
        return entries;
      } else {
        print('[SleepRepository] API returned empty list');
      }
    } catch (e) {
      print('⚠️ Backend history failed with error: $e');
      print('⚠️ Error type: ${e.runtimeType}');
    }
    
    // Fallback to local storage
    print('📱 Falling back to local storage');
    final localEntries = await _getFromLocalStorage(userId, limit: limit);
    print('📱 Local storage returned ${localEntries.length} entries');
    return localEntries;
}

  // Get sleep stats using API
  Future<Map<String, dynamic>> getSleepStats(String userId, {int days = 30}) async {
    try {
      final stats = await _apiService.getSleepStats(userId, days: days);
      
      if (stats.isNotEmpty) {
        print('✅ Sleep stats loaded from backend');
        return stats;
      }
    } catch (e) {
      print('⚠️ Backend stats failed: $e');
    }
    
    // Calculate from local storage
    return await _calculateLocalStats(userId, days: days);
  }

  // Local storage methods remain the same
  Future<void> _saveToLocalStorage(SleepEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_sleepEntriesKey);
    List<Map<String, dynamic>> entries = [];
    
    if (entriesJson != null) {
      entries = List<Map<String, dynamic>>.from(json.decode(entriesJson));
    }
    
    // Remove existing entry for the same date if any
    entries.removeWhere((e) => 
      (e['user_id'] == entry.userId || e['userId'] == entry.userId) &&  // Check both formats
      DateTime.parse(e['date']).day == entry.date.day &&
      DateTime.parse(e['date']).month == entry.date.month &&
      DateTime.parse(e['date']).year == entry.date.year
    );
    
    // Ensure consistent format when saving
    final entryMap = entry.toMap();
    // Make sure we save with snake_case to match backend
    if (entryMap['userId'] != null && entryMap['user_id'] == null) {
      entryMap['user_id'] = entryMap['userId'];
      entryMap.remove('userId');
    }
    
    entries.add(entryMap);
    await prefs.setString(_sleepEntriesKey, json.encode(entries));
  }

  Future<void> _updateInLocalStorage(SleepEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_sleepEntriesKey);
    
    if (entriesJson != null) {
      List<Map<String, dynamic>> entries = List<Map<String, dynamic>>.from(json.decode(entriesJson));
      
      final index = entries.indexWhere((e) => e['id'] == entry.id);
      if (index != -1) {
        entries[index] = entry.toMap();
        await prefs.setString(_sleepEntriesKey, json.encode(entries));
      } else {
        await _saveToLocalStorage(entry);
      }
    }
  }

  Future<SleepEntry?> _getFromLocalStorageByDate(String userId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_sleepEntriesKey);
    
    if (entriesJson != null) {
      List<Map<String, dynamic>> entries = List<Map<String, dynamic>>.from(json.decode(entriesJson));
      
      final entry = entries.firstWhere(
        (e) => e['userId'] == userId && 
               DateTime.parse(e['date']).day == date.day &&
               DateTime.parse(e['date']).month == date.month &&
               DateTime.parse(e['date']).year == date.year,
        orElse: () => {},
      );
      
      if (entry.isNotEmpty) {
        return SleepEntry.fromMap(entry);
      }
    }
    
    return null;
  }

  Future<List<SleepEntry>> _getFromLocalStorage(String userId, {int limit = 30}) async {
    print('[SleepRepository] Getting from local storage for user: $userId');
    
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString(_sleepEntriesKey);
    
    print('[SleepRepository] Local storage raw data: $entriesJson');
    
    if (entriesJson != null) {
      List<Map<String, dynamic>> entries = List<Map<String, dynamic>>.from(json.decode(entriesJson));
      
      print('[SleepRepository] Found ${entries.length} total entries in local storage');
      
      
      final userEntries = entries
          .where((e) => 
              e['user_id'] == userId ||  // Check snake_case
              e['userId'] == userId)      // Check camelCase
          .map((e) => SleepEntry.fromMap(e))
          .take(limit)
          .toList();
      
      print('[SleepRepository] Filtered to ${userEntries.length} entries for user $userId');
      
      return userEntries;
    }
    
    print('[SleepRepository] No local storage data found');
    return [];
  }

  Future<Map<String, dynamic>> _calculateLocalStats(String userId, {int days = 30}) async {
    final entries = await _getFromLocalStorage(userId, limit: days);
    
    if (entries.isEmpty) {
      return {
        'avg_sleep': 0.0,
        'avg_quality': 0.0,
        'avg_deep_sleep': 0.0,
        'entries_count': 0,
      };
    }
    
    double totalSleep = 0;
    double totalQuality = 0;
    double totalDeepSleep = 0;
    
    for (final entry in entries) {
      totalSleep += entry.totalHours;
      totalQuality += entry.qualityScore;
      totalDeepSleep += entry.deepSleepHours;
    }
    
    return {
      'avg_sleep': totalSleep / entries.length,
      'avg_quality': totalQuality / entries.length,
      'avg_deep_sleep': totalDeepSleep / entries.length,
      'entries_count': entries.length,
    };
  }
}