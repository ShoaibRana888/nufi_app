// lib/data/services/api/sharing_api.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';

/// Client for the user-controlled "share with AI chat" toggles.
///
/// Each logged activity carries a `shared_with_chat` flag. Hiding an activity
/// removes it from what the AI coach can see (enforced server-side) without
/// deleting the underlying data. The backend rebuilds the affected day's
/// chat context automatically after each toggle.
class SharingApi {
  static final SharingApi _instance = SharingApi._internal();

  factory SharingApi() => _instance;

  SharingApi._internal();

  final ApiClient _client = ApiClient();

  /// Per-entry tables (meal/exercise/weight/sleep) are toggled by row [itemId].
  Future<bool> setEntrySharing({
    required String userId,
    required String activityType,
    required String itemId,
    required bool shared,
  }) {
    return _setSharing(userId, {
      'activity_type': activityType,
      'item_id': itemId,
      'shared': shared,
    });
  }

  /// Per-day aggregates (water/steps) are toggled by [date].
  Future<bool> setDateSharing({
    required String userId,
    required String activityType,
    required DateTime date,
    required bool shared,
  }) {
    return _setSharing(userId, {
      'activity_type': activityType,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'shared': shared,
    });
  }

  /// Supplements are toggled by [date] (optionally a single [supplementName]).
  Future<bool> setSupplementSharing({
    required String userId,
    required DateTime date,
    required bool shared,
    String? supplementName,
  }) {
    return _setSharing(userId, {
      'activity_type': 'supplement',
      'date': DateFormat('yyyy-MM-dd').format(date),
      if (supplementName != null) 'supplement_name': supplementName,
      'shared': shared,
    });
  }

  Future<bool> _setSharing(String userId, Map<String, dynamic> body) async {
    try {
      final response = await _client.patch('/sharing/$userId', body: jsonEncode(body));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      print('[SharingApi] ⚠️ Toggle failed (${response.statusCode}): ${response.body}');
      return false;
    } catch (e) {
      print('[SharingApi] ❌ Toggle error: $e');
      return false;
    }
  }

  /// Per-activity-type defaults for new entries, e.g. {'weight': false}.
  Future<Map<String, bool>> getDefaults(String userId) async {
    try {
      final response = await _client.get('/sharing/$userId/defaults');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final defaults = (data['defaults'] as Map?) ?? {};
        return defaults.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return {};
    } catch (e) {
      print('[SharingApi] ❌ getDefaults error: $e');
      return {};
    }
  }

  /// Merge per-activity-type defaults. Pass `true` to reset a type to the
  /// implicit shared default, `false` to hide that type by default.
  Future<Map<String, bool>> setDefaults(String userId, Map<String, bool> defaults) async {
    try {
      final response = await _client.put(
        '/sharing/$userId/defaults',
        body: jsonEncode({'defaults': defaults}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = (data['defaults'] as Map?) ?? {};
        return result.map((k, v) => MapEntry(k.toString(), v == true));
      }
      return defaults;
    } catch (e) {
      print('[SharingApi] ❌ setDefaults error: $e');
      return defaults;
    }
  }
}
