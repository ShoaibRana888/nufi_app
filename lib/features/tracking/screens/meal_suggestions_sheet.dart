// lib/features/tracking/widgets/meal_suggestions_sheet.dart

import 'package:flutter/material.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';

class MealSuggestionsSheet extends StatefulWidget {
  final String userId;
  final String? mealType;
  final Function(Map<String, dynamic>) onSuggestionSelected;

  const MealSuggestionsSheet({
    Key? key,
    required this.userId,
    this.mealType,
    required this.onSuggestionSelected,
  }) : super(key: key);

  @override
  State<MealSuggestionsSheet> createState() => _MealSuggestionsSheetState();
}

class _MealSuggestionsSheetState extends State<MealSuggestionsSheet>
    with SingleTickerProviderStateMixin {
  final MealApi _apiService = MealApi();
  late TabController _tabController;

  List<Map<String, dynamic>> _aiSuggestions = [];
  List<Map<String, dynamic>> _quickSuggestions = [];
  bool _isLoadingAI = true;
  bool _isLoadingQuick = true;
  Map<String, dynamic>? _context;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    // Load quick suggestions first (faster)
    _loadQuickSuggestions();
    // Then load AI suggestions
    _loadAISuggestions();
  }

  Future<void> _loadQuickSuggestions() async {
    try {
      final data = await _apiService.getQuickMealSuggestions(
        widget.userId,
        mealType: widget.mealType,
      );

      if (mounted) {
        setState(() {
          _quickSuggestions = List<Map<String, dynamic>>.from(
            data['suggestions'] ?? [],
          );
          _isLoadingQuick = false;
        });
      }
    } catch (e) {
      print('Error loading quick suggestions: $e');
      if (mounted) {
        setState(() => _isLoadingQuick = false);
      }
    }
  }

  Future<void> _loadAISuggestions() async {
    try {
      final data = await _apiService.getMealSuggestions(
        widget.userId,
        mealType: widget.mealType,
        numSuggestions: 5,
      );

      if (mounted) {
        setState(() {
          _aiSuggestions = List<Map<String, dynamic>>.from(
            data['suggestions'] ?? [],
          );
          _context = data['context'];
          _isLoadingAI = false;
        });
      }
    } catch (e) {
      print('Error loading AI suggestions: $e');
      if (mounted) {
        setState(() => _isLoadingAI = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Meal Suggestions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_context != null)
                      Chip(
                        label: Text(
                          '${_context!['remaining_calories']} cal left',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.green[100],
                      ),
                  ],
                ),
              ),

              // Tab bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '✨ AI Suggestions'),
                  Tab(text: '⚡ Quick Add'),
                ],
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.orange,
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAISuggestionsTab(scrollController),
                    _buildQuickSuggestionsTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAISuggestionsTab(ScrollController scrollController) {
    if (_isLoadingAI) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating personalized suggestions...'),
          ],
        ),
      );
    }

    if (_aiSuggestions.isEmpty) {
      return const Center(
        child: Text('No suggestions available'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _aiSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _aiSuggestions[index];
        return _buildAISuggestionCard(suggestion);
      },
    );
  }

  Widget _buildAISuggestionCard(Map<String, dynamic> suggestion) {
    final tags = List<String>.from(suggestion['tags'] ?? []);
    final difficulty = suggestion['difficulty'] ?? 'easy';

    Color difficultyColor;
    switch (difficulty) {
      case 'easy':
        difficultyColor = Colors.green;
        break;
      case 'medium':
        difficultyColor = Colors.orange;
        break;
      case 'hard':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => widget.onSuggestionSelected({
          'food_item': suggestion['name'],
          'quantity': '1 serving',
          'calories': suggestion['estimated_calories'],
          'protein_g': suggestion['estimated_protein_g'],
          'carbs_g': suggestion['estimated_carbs_g'],
          'fat_g': suggestion['estimated_fat_g'],
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      suggestion['name'] ?? 'Meal',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: difficultyColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      difficulty,
                      style: TextStyle(
                        fontSize: 11,
                        color: difficultyColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                suggestion['description'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 12),

              // Nutrition info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNutrientChip(
                    '${suggestion['estimated_calories']} cal',
                    Colors.orange,
                  ),
                  _buildNutrientChip(
                    '${suggestion['estimated_protein_g']}g P',
                    Colors.red,
                  ),
                  _buildNutrientChip(
                    '${suggestion['estimated_carbs_g']}g C',
                    Colors.blue,
                  ),
                  _buildNutrientChip(
                    '${suggestion['prep_time_minutes']} min',
                    Colors.grey,
                  ),
                ],
              ),

              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ],

              if (suggestion['why_suggested'] != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        suggestion['why_suggested'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildQuickSuggestionsTab(ScrollController scrollController) {
    if (_isLoadingQuick) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quickSuggestions.isEmpty) {
      return const Center(
        child: Text('No previous meals found'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _quickSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _quickSuggestions[index];
        return _buildQuickSuggestionTile(suggestion);
      },
    );
  }

  Widget _buildQuickSuggestionTile(Map<String, dynamic> suggestion) {
    return ListTile(
      onTap: () => widget.onSuggestionSelected({
        'food_item': suggestion['food_item'],
        'quantity': '1 serving',
        'calories': suggestion['calories'],
        'protein_g': suggestion['protein_g'],
        'carbs_g': suggestion['carbs_g'],
        'fat_g': suggestion['fat_g'],
      }),
      leading: CircleAvatar(
        backgroundColor: Colors.orange[100],
        child: Text(
          '${suggestion['frequency']}x',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(suggestion['food_item'] ?? 'Meal'),
      subtitle: Text(
        '${suggestion['calories']?.round() ?? 0} cal • '
        '${suggestion['protein_g']?.round() ?? 0}g P • '
        '${suggestion['carbs_g']?.round() ?? 0}g C • '
        '${suggestion['fat_g']?.round() ?? 0}g F',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
    );
  }
}