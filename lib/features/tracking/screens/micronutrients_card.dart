// lib/features/tracking/widgets/micronutrients_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:user_onboarding/data/services/api/meal_api.dart';

class MicronutrientsCard extends StatefulWidget {
  final String userId;
  final DateTime? selectedDate;

  const MicronutrientsCard({
    Key? key,
    required this.userId,
    this.selectedDate,
  }) : super(key: key);

  @override
  State<MicronutrientsCard> createState() => _MicronutrientsCardState();
}

class _MicronutrientsCardState extends State<MicronutrientsCard> {
  final MealApi _apiService = MealApi();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(MicronutrientsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final date = widget.selectedDate ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final response = await _apiService.getMicronutrientSummary(
        widget.userId,
        date: dateStr,
      );

      if (mounted) {
        setState(() {
          _data = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading micronutrients: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.science, color: Colors.purple),
            title: const Text(
              'Micronutrients',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
              },
            ),
          ),
          if (_isExpanded) _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_data == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No data available'),
      );
    }

    final percentages = Map<String, dynamic>.from(_data!['percentages'] ?? {});
    final highlights = Map<String, dynamic>.from(_data!['highlights'] ?? {});

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highlights section
          if ((highlights['excellent'] as List?)?.isNotEmpty ?? false) ...[
            _buildHighlightSection(
              'Excellent',
              List<String>.from(highlights['excellent']),
              Colors.green,
              Icons.check_circle,
            ),
            const SizedBox(height: 12),
          ],

          if ((highlights['high'] as List?)?.isNotEmpty ?? false) ...[
            _buildHighlightSection(
              'Watch Out',
              List<String>.from(highlights['high']),
              Colors.red,
              Icons.warning,
            ),
            const SizedBox(height: 12),
          ],

          if ((highlights['low'] as List?)?.isNotEmpty ?? false) ...[
            _buildHighlightSection(
              'Could Use More',
              List<String>.from(highlights['low']),
              Colors.orange,
              Icons.info,
            ),
            const SizedBox(height: 12),
          ],

          const Divider(),
          const SizedBox(height: 8),

          // Vitamins
          const Text(
            'Vitamins',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildNutrientRow('Vitamin A', percentages['vitamin_a_mcg'] ?? 0),
          _buildNutrientRow('Vitamin C', percentages['vitamin_c_mg'] ?? 0),
          _buildNutrientRow('Vitamin D', percentages['vitamin_d_mcg'] ?? 0),
          _buildNutrientRow('Vitamin E', percentages['vitamin_e_mg'] ?? 0),
          _buildNutrientRow('Vitamin K', percentages['vitamin_k_mcg'] ?? 0),
          _buildNutrientRow('Vitamin B12', percentages['vitamin_b12_mcg'] ?? 0),

          const SizedBox(height: 16),

          // Minerals
          const Text(
            'Minerals',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildNutrientRow('Calcium', percentages['calcium_mg'] ?? 0),
          _buildNutrientRow('Iron', percentages['iron_mg'] ?? 0),
          _buildNutrientRow('Potassium', percentages['potassium_mg'] ?? 0),
          _buildNutrientRow('Magnesium', percentages['magnesium_mg'] ?? 0),
          _buildNutrientRow('Zinc', percentages['zinc_mg'] ?? 0),

          const SizedBox(height: 16),

          // Other
          const Text(
            'Other',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildNutrientRow('Fiber', percentages['fiber_g'] ?? 0),
          _buildNutrientRow(
            'Cholesterol',
            percentages['cholesterol_mg'] ?? 0,
            isLimit: true,
          ),
          _buildNutrientRow(
            'Saturated Fat',
            percentages['saturated_fat_g'] ?? 0,
            isLimit: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightSection(
    String title,
    List<String> items,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.map((item) {
              return Chip(
                label: Text(
                  item,
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: color.withOpacity(0.2),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow(String name, num percentage, {bool isLimit = false}) {
    final pct = percentage.toDouble();

    Color barColor;
    if (isLimit) {
      // For cholesterol/sat fat, lower is better
      barColor = pct > 100 ? Colors.red : (pct > 70 ? Colors.orange : Colors.green);
    } else {
      // For vitamins/minerals, higher is better (up to 100%)
      barColor = pct >= 80
          ? Colors.green
          : (pct >= 50 ? Colors.orange : Colors.red);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: barColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}