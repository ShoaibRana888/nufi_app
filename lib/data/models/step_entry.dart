// lib/data/models/step_entry.dart
class StepEntry {
  final String? id;
  final String userId;
  final DateTime date;
  final int steps;
  final int goal;
  final double caloriesBurned;
  final double distanceKm;
  final int activeMinutes;
  final String sourceType; // 'manual', 'health_app', 'pedometer'
  final DateTime? lastSynced;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool sharedWithChat;

  StepEntry({
    this.id,
    required this.userId,
    required this.date,
    required this.steps,
    required this.goal,
    this.caloriesBurned = 0.0,
    this.distanceKm = 0.0,
    this.activeMinutes = 0,
    this.sourceType = 'manual',
    this.lastSynced,
    this.createdAt,
    this.updatedAt,
    this.sharedWithChat = true,
  });

  StepEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    int? steps,
    int? goal,
    double? caloriesBurned,
    double? distanceKm,
    int? activeMinutes,
    String? sourceType,
    DateTime? lastSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? sharedWithChat,
  }) {
    return StepEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      goal: goal ?? this.goal,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceKm: distanceKm ?? this.distanceKm,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      sourceType: sourceType ?? this.sourceType,
      lastSynced: lastSynced ?? this.lastSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sharedWithChat: sharedWithChat ?? this.sharedWithChat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,  
      'date': date.toIso8601String(),  
      'steps': steps,
      'goal': goal,
      'calories_burned': caloriesBurned,  
      'distance_km': distanceKm,          
      'active_minutes': activeMinutes,   
      'source_type': sourceType,          
      'last_synced': lastSynced?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'shared_with_chat': sharedWithChat,
    };
  }

  factory StepEntry.fromMap(Map<String, dynamic> map) {
    try {
      return StepEntry(
        id: map['id']?.toString(),
        userId: map['user_id']?.toString() ?? map['userId']?.toString() ?? '',
        date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()).toLocal(), 
        steps: (map['steps'] ?? 0) is int 
            ? map['steps'] 
            : int.tryParse(map['steps'].toString()) ?? 0,
        goal: (map['goal'] ?? 10000) is int 
            ? map['goal'] 
            : int.tryParse(map['goal'].toString()) ?? 10000,
        caloriesBurned: (map['calories_burned'] ?? map['caloriesBurned'] ?? 0.0).toDouble(),
        distanceKm: (map['distance_km'] ?? map['distanceKm'] ?? 0.0).toDouble(),
        activeMinutes: (map['active_minutes'] ?? map['activeMinutes'] ?? 0) is int 
            ? (map['active_minutes'] ?? map['activeMinutes'])
            : int.tryParse((map['active_minutes'] ?? map['activeMinutes'] ?? 0).toString()) ?? 0,
        sourceType: map['source_type']?.toString() ?? map['sourceType']?.toString() ?? 'manual',
        lastSynced: map['last_synced'] != null || map['lastSynced'] != null
            ? DateTime.tryParse(map['last_synced']?.toString() ?? map['lastSynced']?.toString() ?? '')?.toLocal() 
            : null,
        createdAt: map['created_at'] != null || map['createdAt'] != null
            ? DateTime.tryParse(map['created_at']?.toString() ?? map['createdAt']?.toString() ?? '')?.toLocal() 
            : null,
        updatedAt: map['updated_at'] != null || map['updatedAt'] != null
            ? DateTime.tryParse(map['updated_at']?.toString() ?? map['updatedAt']?.toString() ?? '')?.toLocal()
            : null,
        sharedWithChat: map['shared_with_chat'] != false,
      );
    } catch (e) {
      print('Error parsing StepEntry from map: $e');
      print('Map data: $map');
      rethrow;
    }
  }
}