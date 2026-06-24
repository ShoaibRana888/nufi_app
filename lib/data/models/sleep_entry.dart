// lib/data/models/sleep_entry.dart
class SleepEntry {
  final String? id;
  final String userId;
  final DateTime date;
  final DateTime? bedtime;
  final DateTime? wakeTime;
  final double totalHours;
  final double qualityScore;
  final double deepSleepHours;
  final List<String> sleepIssues;
  final String? notes;
  final DateTime createdAt;
  final bool sharedWithChat;

  @override
  String toString() {
    return 'SleepEntry(id: $id, userId: $userId, date: $date, totalHours: $totalHours)';
  }

  SleepEntry({
    this.id,
    required this.userId,
    required this.date,
    this.bedtime,
    this.wakeTime,
    required this.totalHours,
    required this.qualityScore,
    required this.deepSleepHours,
    this.sleepIssues = const [],
    this.notes,
    required this.createdAt,
    this.sharedWithChat = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date.toIso8601String(),
      'bedtime': bedtime?.toIso8601String(),
      'wake_time': wakeTime?.toIso8601String(),
      'total_hours': totalHours,
      'quality_score': qualityScore,
      'deep_sleep_hours': deepSleepHours,
      'sleep_issues': sleepIssues,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'shared_with_chat': sharedWithChat,
    };
  }

  factory SleepEntry.fromMap(Map<String, dynamic> map) {
    // Get userId and ensure it's not null
    final String? userIdValue = map['user_id']?.toString() ?? map['userId']?.toString();
    if (userIdValue == null || userIdValue.isEmpty) {
      throw ArgumentError('userId is required but was not found in map: $map');
    }

    // Better date parsing with timezone conversion
    DateTime entryDate;
    if (map['date'] is String) {
      entryDate = DateTime.parse(map['date']).toLocal();  // ← Added .toLocal()
    } else if (map['date'] is DateTime) {
      entryDate = (map['date'] as DateTime).toLocal();  // ← Added .toLocal()
    } else {
      entryDate = DateTime.now();
    }

    // Better bedtime/wake time parsing with timezone conversion
    DateTime? bedtime;
    DateTime? wakeTime;

    if (map['bedtime'] != null) {
      try {
        if (map['bedtime'] is String) {
          bedtime = DateTime.parse(map['bedtime']).toLocal();  // ← Added .toLocal()
        } else if (map['bedtime'] is DateTime) {
          bedtime = (map['bedtime'] as DateTime).toLocal();  // ← Added .toLocal()
        }
      } catch (e) {
        print('Error parsing bedtime: $e');
      }
    }

    if (map['wake_time'] != null) {
      try {
        if (map['wake_time'] is String) {
          wakeTime = DateTime.parse(map['wake_time']).toLocal();  // ← Added .toLocal()
        } else if (map['wake_time'] is DateTime) {
          wakeTime = (map['wake_time'] as DateTime).toLocal();  // ← Added .toLocal()
        }
      } catch (e) {
        print('Error parsing wake_time: $e');
      }
    }

    // Parse sleep_issues properly
    List<String> sleepIssuesList = [];
    if (map['sleep_issues'] != null) {
      if (map['sleep_issues'] is List) {
        sleepIssuesList = List<String>.from(map['sleep_issues']);
      } else if (map['sleep_issues'] is String) {
        final issuesString = map['sleep_issues'] as String;
        if (issuesString.isNotEmpty) {
          sleepIssuesList = issuesString.split(',').map((s) => s.trim()).toList();
        }
      }
    }

    return SleepEntry(
      id: map['id']?.toString(),
      userId: userIdValue,
      date: entryDate,
      bedtime: bedtime,
      wakeTime: wakeTime,
      totalHours: (map['total_hours'] ?? map['totalHours'] ?? 0).toDouble(),
      qualityScore: (map['quality_score'] ?? map['qualityScore'] ?? 0).toDouble(),
      deepSleepHours: (map['deep_sleep_hours'] ?? map['deepSleepHours'] ?? 0).toDouble(),
      sleepIssues: sleepIssuesList,
      notes: map['notes']?.toString(),
      sharedWithChat: map['shared_with_chat'] != false,
      createdAt: map['created_at'] != null || map['createdAt'] != null
          ? (map['created_at'] ?? map['createdAt']) is String 
              ? DateTime.parse(map['created_at'] ?? map['createdAt']).toLocal()  // ← Added .toLocal()
              : (map['created_at'] ?? map['createdAt'] as DateTime).toLocal()  // ← Added .toLocal()
          : DateTime.now(),
    );
  }

  SleepEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? bedtime,
    DateTime? wakeTime,
    double? totalHours,
    double? qualityScore,
    double? deepSleepHours,
    List<String>? sleepIssues,
    String? notes,
    DateTime? createdAt,
    bool? sharedWithChat,
  }) {
    return SleepEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      totalHours: totalHours ?? this.totalHours,
      qualityScore: qualityScore ?? this.qualityScore,
      deepSleepHours: deepSleepHours ?? this.deepSleepHours,
      sleepIssues: sleepIssues ?? this.sleepIssues,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      sharedWithChat: sharedWithChat ?? this.sharedWithChat,
    );
  }
}