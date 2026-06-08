// lib/data/services/api/meal_api.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/services/api/api_client.dart';
import 'package:user_onboarding/data/services/api/chat_api.dart';

/// Meal logging + nutrition API.
class MealApi {
  static final MealApi _instance = MealApi._internal();

  factory MealApi() => _instance;

  MealApi._internal();

  final ApiClient _client = ApiClient();
  final ChatApi _chat = ChatApi();

  Future<Map<String, dynamic>> analyzeMeal(Map<String, dynamic> mealData) async {
    try {
      final response = await _client.post(
        '/meals/analyze',
        body: jsonEncode({
          'user_id': mealData['user_id'],
          'food_item': mealData['food_item'],
          'quantity': mealData['quantity'] ?? '1 serving',
          'meal_type': mealData['meal_type'],
          'meal_date': mealData['meal_date'] ?? DateTime.now().toIso8601String(),
          'preparation': mealData['preparation'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Full response: $data');

        Map<String, dynamic> normalizedMeal;

        // Check if it's the flutter_compat response format
        if (data['success'] == true && data['meal'] != null) {
          final meal = data['meal'];
          // Return normalized format for the UI
          normalizedMeal = {
            'id': meal['id'],
            'food_item': meal['name'] ?? meal['food_item'],
            'quantity': meal['quantity'],
            'meal_type': mealData['meal_type'], // Keep original
            'calories': meal['calories'],
            'protein_g': meal['protein'] ?? meal['protein_g'],
            'carbs_g': meal['carbs'] ?? meal['carbs_g'],
            'fat_g': meal['fat'] ?? meal['fat_g'],
            'fiber_g': meal['fiber'] ?? meal['fiber_g'],
            'sugar_g': meal['sugar'] ?? meal['sugar_g'],
            'sodium_mg': meal['sodium'] ?? meal['sodium_mg'],
            'healthiness_score': meal['healthiness_score'],
            'suggestions': meal['suggestions'],
            'nutrition_notes': meal['nutrition_notes'],
            'components': meal['components'],
            'data_source': meal['data_source'],
            'meal_date': meal['logged_at'] ?? DateTime.now().toIso8601String(),
          };
        } else {
          // Handle other response formats
          normalizedMeal = data;
        }

        // ✅ UPDATE CHAT CONTEXT AFTER SUCCESSFUL MEAL SAVE
        await _chat.updateChatContext(
          mealData['user_id'],
          'meal',
          normalizedMeal,
          date: mealData['meal_date'] != null
            ? DateTime.parse(mealData['meal_date'])
            : DateTime.now()
        );

        await _chat.rebuildChatContext(mealData['user_id']);

        return normalizedMeal;

      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception(errorBody['error'] ?? errorBody['detail'] ?? 'Failed to analyze meal');
      }
    } catch (e) {
      throw Exception('Error analyzing meal: $e');
    }
  }

  Future<Map<String, dynamic>> analyzeMealWithParams({
    required String userId,
    required String foodItem,
    required String quantity,
    required String mealType,
    String? mealDate,
    String? preparation,
  }) async {
    return analyzeMeal({
      'user_id': userId,
      'food_item': foodItem,
      'quantity': quantity,
      'meal_type': mealType,
      'meal_date': mealDate ?? DateTime.now().toIso8601String(),
      'preparation': preparation,
    });
  }

  /// Get energy balance for a specific date
  Future<Map<String, dynamic>> getEnergyBalance(String userId, {String? date}) async {
    try {
      final dateParam = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _client.get('/meals/energy-balance/$userId?date=$dateParam');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get energy balance');
      }
    } catch (e) {
      print('[MealApi] Energy balance error: $e');
      rethrow;
    }
  }

  /// Get remaining macros adjusted for exercise
  Future<Map<String, dynamic>> getRemainingMacros(String userId, {String? date}) async {
    try {
      final dateParam = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _client.get('/meals/remaining-macros/$userId?date=$dateParam');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get remaining macros');
      }
    } catch (e) {
      print('[MealApi] Remaining macros error: $e');
      rethrow;
    }
  }

  /// Get nutrition trends for charting
  Future<Map<String, dynamic>> getNutritionTrends(String userId, {int days = 30}) async {
    try {
      final response = await _client.get('/meals/trends/$userId?days=$days');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get nutrition trends');
      }
    } catch (e) {
      print('[MealApi] Nutrition trends error: $e');
      rethrow;
    }
  }

  /// Get macro breakdown for pie charts
  Future<Map<String, dynamic>> getMacroBreakdown(String userId, {int days = 7}) async {
    try {
      final response = await _client.get('/meals/macro-breakdown/$userId?days=$days');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get macro breakdown');
      }
    } catch (e) {
      print('[MealApi] Macro breakdown error: $e');
      rethrow;
    }
  }

  /// Get AI-powered meal suggestions
  Future<Map<String, dynamic>> getMealSuggestions(
    String userId, {
    String? mealType,
    bool considerExercise = true,
    int numSuggestions = 5,
  }) async {
    try {
      final response = await _client.post(
        '/suggestions/meals',
        body: jsonEncode({
          'user_id': userId,
          'meal_type': mealType,
          'consider_exercise': considerExercise,
          'num_suggestions': numSuggestions,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get meal suggestions');
      }
    } catch (e) {
      print('[MealApi] Meal suggestions error: $e');
      rethrow;
    }
  }

  /// Get quick suggestions based on past meals
  Future<Map<String, dynamic>> getQuickMealSuggestions(
    String userId, {
    String? mealType,
  }) async {
    try {
      String url = '/suggestions/quick/$userId';
      if (mealType != null) {
        url += '?meal_type=$mealType';
      }

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get quick suggestions');
      }
    } catch (e) {
      print('[MealApi] Quick suggestions error: $e');
      rethrow;
    }
  }

  /// Get micronutrient summary
  Future<Map<String, dynamic>> getMicronutrientSummary(
    String userId, {
    String? date,
  }) async {
    try {
      final dateParam = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _client.get('/meals/micronutrients/$userId?date=$dateParam');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get micronutrient summary');
      }
    } catch (e) {
      print('[MealApi] Micronutrients error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> analyzeMealBatch({
    required String userId,
    required List<Map<String, String>> foodItems,
    required String mealType,
    String? mealDate,
  }) async {
    try {
      // Combine items into a single description for the parser
      final description = foodItems
          .map((item) => '${item['quantity'] ?? '1 serving'} ${item['food']}')
          .join(', ');

      return await analyzeMeal({
        'user_id': userId,
        'food_item': description,
        'quantity': '1 serving',
        'meal_type': mealType,
        'meal_date': mealDate ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Error in batch analysis: $e');
    }
  }

  // Get meal history
  Future<List<Map<String, dynamic>>> getMealHistory(String userId, {String? date}) async {
    try {
      String url = '/meals/history/$userId';
      if (date != null) {
        url += '?date=$date';
      }

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['meals'] != null) {
          final meals = List<Map<String, dynamic>>.from(data['meals']);
          return meals;
        }
      }

      throw Exception('Failed to load meal history');
    } catch (e) {
      print('❌ Error getting meal history: $e');
      return [];
    }
  }

  // Get daily nutrition summary
  Future<Map<String, dynamic>> getDailySummary(String userId, {String? date}) async {
    try {
      final dateParam = date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _client.get('/daily-summary/$userId?date=$dateParam');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle the response structure - check multiple possible paths
        final mealsData = data['meals'] ?? data['totals'] ?? {};
        final totalsData = data['totals'] ?? data['meals'] ?? {};

        final result = {
          'totals': {
            'calories': (totalsData['calories'] ??
                        totalsData['total_calories'] ??
                        totalsData['calories_consumed'] ?? 0.0).toDouble(),
            'protein_g': (totalsData['protein_g'] ??
                        totalsData['total_protein'] ?? 0.0).toDouble(),
            'carbs_g': (totalsData['carbs_g'] ??
                      totalsData['total_carbs'] ?? 0.0).toDouble(),
            'fat_g': (totalsData['fat_g'] ??
                    totalsData['total_fat'] ?? 0.0).toDouble(),
            'fiber_g': (totalsData['fiber_g'] ??
                      totalsData['total_fiber'] ?? 0.0).toDouble(),
            'sugar_g': (totalsData['sugar_g'] ??
                      totalsData['total_sugar'] ?? 0.0).toDouble(),
            'sodium_mg': (totalsData['sodium_mg'] ??
                        totalsData['total_sodium'] ?? 0.0).toDouble(),
          },
          'meals_count': mealsData['meals_count'] ?? mealsData['total_count'] ?? 0,
        };

        return result;
      }

      throw Exception('Failed to load daily summary: ${response.statusCode}');
    } catch (e) {
      print('❌ Error getting daily summary: $e');
      return {
        'totals': {
          'calories': 0.0,
          'protein_g': 0.0,
          'carbs_g': 0.0,
          'fat_g': 0.0,
          'fiber_g': 0.0,
          'sugar_g': 0.0,
          'sodium_mg': 0.0,
        },
        'meals_count': 0,
      };
    }
  }

  // Delete a meal
  Future<bool> deleteMeal(String mealId, String userId) async {
    try {
      final response = await _client.delete('/meals/$mealId');

      if (response.statusCode == 200) {
        // ✅ UPDATE CHAT CONTEXT AFTER DELETION
        await _chat.updateChatContext(
          userId,
          'meal_delete',
          {'meal_id': mealId, 'deleted': true}
        );

        await _chat.rebuildChatContext(userId);

        return true;
      }
      return false;
    } catch (e) {
      print('[MealApi] Delete meal error: $e');
      return false;
    }
  }

  // Update a meal
  Future<Map<String, dynamic>> updateMeal(String mealId, Map<String, dynamic> mealData) async {
    try {
      final response = await _client.put(
        '/meals/$mealId',
        body: json.encode(mealData),
      );

      if (response.statusCode == 200) {
        final updatedMeal = json.decode(response.body);

        // ✅ UPDATE CHAT CONTEXT AFTER MEAL UPDATE
        if (mealData['user_id'] != null) {
          await _chat.updateChatContext(
            mealData['user_id'],
            'meal',
            updatedMeal
          );
        }

        await _chat.rebuildChatContext(mealData['user_id']);

        return updatedMeal;
      }

      throw Exception('Failed to update meal');
    } catch (e) {
      print('Error updating meal: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> getMealPresets(String userId) async {
    try {
      final response = await _client.get('/meals/presets/$userId');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to load presets');
    } catch (e) {
      print('Error getting presets: $e');
      return {'success': false, 'presets': []};
    }
  }

  Future<Map<String, dynamic>> createPreset(Map<String, dynamic> presetData) async {
    try {
      final response = await _client.post(
        '/meals/presets/create',
        body: jsonEncode(presetData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to create preset');
    } catch (e) {
      print('Error creating preset: $e');
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> usePreset(String presetId, Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        '/meals/presets/$presetId/use',
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to use preset');
    } catch (e) {
      print('Error using preset: $e');
      return {'success': false};
    }
  }

  Future<bool> deleteMealPreset(String presetId) async {
    try {
      final response = await _client.delete('/meals/presets/$presetId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Preset deleted successfully');
        return true;
      } else if (response.statusCode == 404) {
        print('⚠️ Preset not found');
        return false;
      } else {
        print('❌ Failed to delete preset: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting preset: $e');
      return false;
    }
  }
}
