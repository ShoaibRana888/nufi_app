// lib/data/models/period_entry.dart
class PeriodEntry {
  final String? id;
  final String userId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? flowIntensity;
  final List<String>? symptoms;
  final String? mood;
  final String? notes;
  final DateTime? createdAt;
  final bool sharedWithChat;

  PeriodEntry({
    this.id,
    required this.userId,
    required this.startDate,
    this.endDate,
    this.flowIntensity,
    this.symptoms,
    this.mood,
    this.notes,
    this.createdAt,
    this.sharedWithChat = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'flow_intensity': flowIntensity,
      'symptoms': symptoms,
      'mood': mood,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'shared_with_chat': sharedWithChat,
    };
  }

  factory PeriodEntry.fromMap(Map<String, dynamic> map) {
    return PeriodEntry(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? map['userId']?.toString() ?? '',
      startDate: DateTime.parse(map['start_date'] ?? map['startDate']).toLocal(),  // ← Added .toLocal()
      endDate: map['end_date'] != null || map['endDate'] != null 
          ? DateTime.parse(map['end_date'] ?? map['endDate']).toLocal()  // ← Added .toLocal()
          : null,
      flowIntensity: map['flow_intensity'] ?? map['flowIntensity'],
      symptoms: map['symptoms'] != null 
          ? List<String>.from(map['symptoms']) 
          : null,
      mood: map['mood'],
      notes: map['notes'],
      createdAt: map['created_at'] != null || map['createdAt'] != null
          ? DateTime.parse(map['created_at'] ?? map['createdAt']).toLocal()  // ← Added .toLocal()
          : null,
      sharedWithChat: map['shared_with_chat'] != false,
    );
  }

  PeriodEntry copyWith({
    String? id,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? flowIntensity,
    List<String>? symptoms,
    String? mood,
    String? notes,
    bool? sharedWithChat,
  }) {
    return PeriodEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      flowIntensity: flowIntensity ?? this.flowIntensity,
      symptoms: symptoms ?? this.symptoms,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
      sharedWithChat: sharedWithChat ?? this.sharedWithChat,
    );
  }
}