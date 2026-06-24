// lib/data/models/weight_entry.dart
class WeightEntry {
  final String? id;
  final String userId;
  final DateTime date;
  final double weight;
  final String? notes;
  final double? bodyFatPercentage;
  final double? muscleMassKg;
  final DateTime createdAt;
  final bool sharedWithChat;

  WeightEntry({
    this.id,
    required this.userId,
    required this.date,
    required this.weight,
    this.notes,
    this.bodyFatPercentage,
    this.muscleMassKg,
    DateTime? createdAt,
    this.sharedWithChat = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'weight': weight,
      'notes': notes,
      'body_fat_percentage': bodyFatPercentage,
      'muscle_mass_kg': muscleMassKg,
      'created_at': createdAt.toIso8601String(),
      'shared_with_chat': sharedWithChat,
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'],
      userId: map['user_id'],
      date: DateTime.parse(map['date']).toLocal(),
      weight: map['weight']?.toDouble() ?? 0.0,
      notes: map['notes'],
      bodyFatPercentage: map['body_fat_percentage']?.toDouble(),
      muscleMassKg: map['muscle_mass_kg']?.toDouble(),
      createdAt: map['created_at'] != null
      ? DateTime.parse(map['created_at']).toLocal()
      : DateTime.now(),
      sharedWithChat: map['shared_with_chat'] != false,
    );
  }

  WeightEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    double? weight,
    String? notes,
    double? bodyFatPercentage,
    double? muscleMassKg,
    DateTime? createdAt,
    bool? sharedWithChat,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      muscleMassKg: muscleMassKg ?? this.muscleMassKg,
      createdAt: createdAt ?? this.createdAt,
      sharedWithChat: sharedWithChat ?? this.sharedWithChat,
    );
  }
}