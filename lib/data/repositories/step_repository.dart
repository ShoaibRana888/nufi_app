// lib/data/repositories/step_repository.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/step_entry.dart';
import 'package:user_onboarding/data/services/api/step_api.dart';
import 'package:intl/intl.dart';

class StepRepository {
  static const String _stepsKey = 'step_entries';

  // NEW: Get step entry for a specific date
  static Future<StepEntry?> getStepEntryByDate(String userId, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    try {
      // Try API first
      final apiEntry = await StepApi().getStepsByDate(userId, dateStr);
      if (apiEntry != null) {
        await _saveToLocal(apiEntry);
        return apiEntry;
      }
    } catch (e) {
      print('Error getting steps by date from API: $e');
    }

    // Fallback to local storage
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final stepsJson = prefs.getString('${_stepsKey}_${userId}_$dateKey');
    
    if (stepsJson != null) {
      return StepEntry.fromMap(jsonDecode(stepsJson));
    }
    
    return null;
  }

  static Future<StepEntry?> getTodayStepEntry(String userId) async {
    return getStepEntryByDate(userId, DateTime.now());
  }

  static Future<List<StepEntry>> getStepEntriesInRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final apiEntries = await StepApi().getStepsInRange(userId, startDate, endDate);
      if (apiEntries.isNotEmpty) {
        for (final entry in apiEntries) {
          await _saveToLocal(entry);
        }
        return apiEntries;
      }
    } catch (e) {
      print('Error getting steps range from API: $e');
    }

    // Fallback to local storage
    final entries = <StepEntry>[];
    final prefs = await SharedPreferences.getInstance();
    
    for (var date = startDate; 
         date.isBefore(endDate.add(const Duration(days: 1))); 
         date = date.add(const Duration(days: 1))) {
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final entryJson = prefs.getString('${_stepsKey}_${userId}_$dateKey');
      
      if (entryJson != null) {
        entries.add(StepEntry.fromMap(jsonDecode(entryJson)));
      }
    }
    
    return entries;
  }

  static Future<void> saveStepEntry(StepEntry entry) async {
    try {
      await StepApi().saveStepEntry(entry);
    } catch (e) {
      print('Error saving step entry to API: $e');
    }
    await _saveToLocal(entry);
  }

  static Future<void> _saveToLocal(StepEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${entry.date.year}-${entry.date.month}-${entry.date.day}';
    final key = '${_stepsKey}_${entry.userId}_$dateKey';
    await prefs.setString(key, jsonEncode(entry.toMap()));
  }

  static Future<List<StepEntry>> getAllStepEntries(String userId) async {
    try {
      final apiEntries = await StepApi().getAllSteps(userId);
      if (apiEntries.isNotEmpty) {
        // Save to local storage
        for (final entry in apiEntries) {
          await _saveToLocal(entry);
        }
        return apiEntries;
      }
    } catch (e) {
      print('Error getting all steps from API: $e');
    }

    // Fallback to local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final stepKeys = keys.where((key) => key.startsWith('${_stepsKey}_$userId'));
      
      final List<StepEntry> entries = [];
      for (final key in stepKeys) {
        final entryJson = prefs.getString(key);
        if (entryJson != null) {
          try {
            entries.add(StepEntry.fromMap(jsonDecode(entryJson)));
          } catch (e) {
            print('Error parsing step entry from local storage: $e');
          }
        }
      }
      
      print('📦 Loaded ${entries.length} entries from local storage');
      return entries;
    } catch (e) {
      print('Error loading from local storage: $e');
      return [];
    }
  }

  static Future<void> deleteStepEntry(String userId, DateTime date) async {
    try {
      await StepApi().deleteStepEntry(userId, date);
    } catch (e) {
      print('Error deleting step entry from API: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final key = '${_stepsKey}_${userId}_$dateKey';
    await prefs.remove(key);
  }
}