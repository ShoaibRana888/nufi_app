// lib/data/services/notification_service_MINIMAL.dart
// ⭐ MINIMAL VERSION - Guaranteed to work without crashes

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:user_onboarding/features/tracking/screens/meal_logging_page.dart';
import 'package:user_onboarding/features/tracking/screens/activity_logging_menu.dart';
import 'package:user_onboarding/features/notifications/screens/notifications_screen.dart';
import 'package:user_onboarding/data/models/notification_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static const String backendUrl = 'https://health-ai-backend-i28b.onrender.com';
  
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Notification IDs
  static const int mealNotificationIdBase = 1000; 
  static const int exerciseNotificationId = 2000;
  static const int waterNotificationId1 = 3000;
  static const int waterNotificationIdBase = 3000;
  static const int waterNotificationId2 = 3001;
  static const int sleepNotificationId = 4000;
  static const int supplementNotificationId = 5000;
  static const int weightNotificationId = 6000;
  static const int stepMilestone50Id = 7000;
  static const int stepMilestone100Id = 7001;

  Future<void> initialize() async {
    // flutter_local_notifications has no web implementation and this method uses
    // dart:io Platform checks, which throw on web. Skip on web so startup does
    // not fall into the error screen.
    if (kIsWeb) {
      print('🔔 [INIT] Web platform detected — skipping notification setup');
      return;
    }

    print('🔔 [INIT] Starting notification service initialization...');

    tz.initializeTimeZones();
    
    // Auto-detect timezone
    final String currentTimeZone = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      print('✅ [INIT] Timezone set to: $currentTimeZone');
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
      print('⚠️ [INIT] Using UTC timezone');
    }
    
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Create ONE main channel with correct settings
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'health_reminders',
            'Health Reminders',
            description: 'Daily health tracking reminders',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );

        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
        
        print('✅ [INIT] Notification channel created');
      }
    }

    print('✅ [INIT] Notification service initialized');
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      final exactAlarmGranted = await androidImpl?.requestExactAlarmsPermission();
      
      print('📱 Permissions - Notification: $granted, Exact Alarm: $exactAlarmGranted');
      return granted ?? false;
    }
    return true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload == null) return;
    
    try {
      final data = jsonDecode(payload);
      final String type = data['type'] ?? '';
      print('📱 Notification tapped - Type: $type');
      _handleNotificationNavigation(type, data);
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  void _handleNotificationNavigation(String type, Map<String, dynamic> data) async {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) return;

    UserProfile? userProfile;
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        userProfile = UserProfile.fromMap(jsonDecode(profileJson));
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }

    if (userProfile == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
      );
      return;
    }

    switch (type.toLowerCase()) {
      case 'breakfast':
      case 'lunch':
      case 'dinner':
      case 'snack':
      case 'meal':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => EnhancedMealLoggingPage(userProfile: userProfile!),
          ),
        );
        break;
      default:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ActivityLoggingMenu(userProfile: userProfile!),
          ),
        );
        break;
    }
  }

  Future<void> scheduleAllNotifications(String userId, Map<String, dynamic> userProfile) async {
    print('📱 [SCHEDULE] Starting for user: $userId');
    print('👤 [SCHEDULE] User profile data: ${userProfile.keys.toList()}');
    
    // Load user preferences
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString('notification_prefs_$userId');
    
    NotificationPreferences notifPrefs;
    if (prefsJson != null) {
      notifPrefs = NotificationPreferences.fromJson(jsonDecode(prefsJson));
    } else {
      notifPrefs = NotificationPreferences(); // Default preferences
    }
    
    // If notifications are disabled globally, cancel all and return
    if (!notifPrefs.enabled) {
      print('🔕 Notifications disabled by user');
      await cancelAllNotifications();
      return;
    }
    
    await cancelAllNotifications();
    
    // ⭐ Schedule based on user preferences AND user profile data
    if (notifPrefs.mealReminders) {
      await scheduleMealNotificationsWithUserData(userId, userProfile, notifPrefs);
    }
    
    if (notifPrefs.exerciseReminders) {
      // Check if user has workout preferences
      final preferredWorkouts = userProfile['preferred_workouts'] ?? userProfile['preferredWorkouts'];
      if (preferredWorkouts != null && (preferredWorkouts as List).isNotEmpty) {
        await scheduleExerciseNotificationWithPrefs(userId, notifPrefs);
      } else {
        print('⚠️ [EXERCISE] Skipped - user has no preferred workouts');
      }
    }
    
    if (notifPrefs.waterReminders) {
      await scheduleWaterNotificationsWithUserData(userId, userProfile, notifPrefs);
    }
    
    if (notifPrefs.sleepReminders) {
      await scheduleSleepNotificationWithUserData(userId, userProfile);
    }
    
    if (notifPrefs.supplementReminders) {
      // Only schedule if user has medical conditions or takes supplements
      final medicalConditions = userProfile['medical_conditions'] ?? userProfile['medicalConditions'] ?? [];
      if ((medicalConditions as List).isNotEmpty) {
        await scheduleSupplementNotification(userId);
      } else {
        print('⚠️ [SUPPLEMENT] Skipped - user has no medical conditions');
      }
    }
    
    if (notifPrefs.weightReminders) {
      // Only if user has weight goal
      final weightGoal = userProfile['weight_goal'] ?? userProfile['weightGoal'];
      if (weightGoal != null && weightGoal.toString().isNotEmpty && weightGoal != 'maintain') {
        await scheduleWeightReminderNotification(userId);
      } else {
        print('⚠️ [WEIGHT] Skipped - user has no active weight goal');
      }
    }
    
    final pending = await getPendingNotifications();
    print('✅ [SCHEDULE] Complete! ${pending.length} notifications scheduled');
  }

  /// Schedule meal notifications using user's custom times
  Future<void> scheduleMealNotificationsWithUserData(
    String userId, 
    Map<String, dynamic> userProfile,
    NotificationPreferences prefs,
  ) async {
    // Get user's actual daily meals count
    final dailyMealsCount = userProfile['daily_meals_count'] ?? 
                            userProfile['dailyMealsCount'] ?? 
                            3;
    
    print('🍽️ [MEALS] User eats $dailyMealsCount meals per day');
    
    if (dailyMealsCount == 1) {
      // One meal a day (OMAD)
      await _scheduleNotification(
        id: mealNotificationIdBase + 0,
        title: '🍽️ Meal Reminder',
        body: 'Time to log your daily meal!',
        hour: prefs.lunchHour, // Use lunch time for single meal
        minute: prefs.lunchMinute,
        userId: userId,
      );
      print('✅ [MEALS] Scheduled 1 meal notification');
      
    } else if (dailyMealsCount == 2) {
      // Two meals a day (16:8 intermittent fasting common)
      await _scheduleNotification(
        id: mealNotificationIdBase + 0,
        title: '🍳 First Meal Reminder',
        body: 'Time to log your first meal!',
        hour: prefs.lunchHour, // Use lunch time for first meal
        minute: prefs.lunchMinute,
        userId: userId,
      );
      
      await _scheduleNotification(
        id: mealNotificationIdBase + 1,
        title: '🌙 Second Meal Reminder',
        body: 'Time to log your second meal!',
        hour: prefs.dinnerHour,
        minute: prefs.dinnerMinute,
        userId: userId,
      );
      print('✅ [MEALS] Scheduled 2 meal notifications');
      
    } else if (dailyMealsCount == 3) {
      // Standard 3 meals
      await _scheduleNotification(
        id: mealNotificationIdBase + 0,
        title: '🍳 Breakfast Reminder',
        body: 'Time to log your breakfast!',
        hour: prefs.breakfastHour,
        minute: prefs.breakfastMinute,
        userId: userId,
      );
      
      await _scheduleNotification(
        id: mealNotificationIdBase + 1,
        title: '🍽️ Lunch Reminder',
        body: 'Time to log your lunch!',
        hour: prefs.lunchHour,
        minute: prefs.lunchMinute,
        userId: userId,
      );
      
      await _scheduleNotification(
        id: mealNotificationIdBase + 2,
        title: '🌙 Dinner Reminder',
        body: 'Time to log your dinner!',
        hour: prefs.dinnerHour,
        minute: prefs.dinnerMinute,
        userId: userId,
      );
      print('✅ [MEALS] Scheduled 3 meal notifications');
      
    } else if (dailyMealsCount >= 4) {
      // 4+ meals (small frequent meals)
      final mealTimes = [
        {'name': 'Breakfast', 'hour': prefs.breakfastHour, 'minute': prefs.breakfastMinute},
        {'name': 'Morning Snack', 'hour': 10, 'minute': 30},
        {'name': 'Lunch', 'hour': prefs.lunchHour, 'minute': prefs.lunchMinute},
        {'name': 'Afternoon Snack', 'hour': 15, 'minute': 30},
        {'name': 'Dinner', 'hour': prefs.dinnerHour, 'minute': prefs.dinnerMinute},
        {'name': 'Evening Snack', 'hour': 20, 'minute': 30},
      ];
      
      // Schedule only the number of meals the user wants
      for (int i = 0; i < dailyMealsCount && i < mealTimes.length; i++) {
        await _scheduleNotification(
          id: mealNotificationIdBase + i,
          title: '🍽️ ${mealTimes[i]['name']} Reminder',
          body: 'Time to log your meal!',
          hour: mealTimes[i]['hour'] as int,
          minute: mealTimes[i]['minute'] as int,
          userId: userId,
        );
      }
      print('✅ [MEALS] Scheduled $dailyMealsCount meal notifications');
    }
  }
  
  /// Schedule exercise notification using user's custom time
  Future<void> scheduleExerciseNotificationWithPrefs(
    String userId,
    NotificationPreferences prefs,
  ) async {
    await _scheduleNotification(
      id: exerciseNotificationId,
      title: '💪 Exercise Reminder',
      body: 'Don\'t forget to log your workout!',
      hour: prefs.exerciseHour,
      minute: prefs.exerciseMinute,
      userId: userId,
    );
    
    print('✅ [EXERCISE] Scheduled at ${prefs.exerciseHour}:${prefs.exerciseMinute}');
  }
  
  /// Schedule water notifications based on user's frequency preference
  Future<void> scheduleWaterNotificationsWithUserData(
    String userId,
    Map<String, dynamic> userProfile,
    NotificationPreferences prefs,
  ) async {
    // Get user's water goal
    final waterGoalGlasses = userProfile['water_intake_glasses'] ?? 
                            userProfile['waterIntakeGlasses'] ?? 
                            8;
    
    print('💧 [WATER] User goal: $waterGoalGlasses glasses/day');
    print('💧 [WATER] Reminder frequency: every ${prefs.waterReminderFrequency} hours');
    
    // Schedule water reminders throughout the day
    // Start at 8 AM, end at 10 PM (awake hours)
    int notificationId = waterNotificationIdBase;
    int hour = 8;
    int reminderCount = 0;
    
    while (hour <= 22) {
      await _scheduleNotification(
        id: notificationId++,
        title: '💧 Hydration Check',
        body: waterGoalGlasses >= 10 
          ? 'Stay hydrated! Goal: $waterGoalGlasses glasses'
          : 'Remember to log your water intake!',
        hour: hour,
        minute: 0,
        userId: userId,
      );
      
      hour += prefs.waterReminderFrequency;
      reminderCount++;
    }
    
    print('✅ [WATER] Scheduled $reminderCount water reminders');
  }
  
  /// Schedule weekly weight reminder (Mondays at 8 AM)
  Future<void> scheduleWeightReminderNotification(String userId) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8, // 8 AM
      0,
    );
    
    // Find next Monday
    while (scheduledDate.weekday != DateTime.monday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    await _notificationsPlugin.zonedSchedule(
      weightNotificationId,
      '⚖️ Weekly Weigh-In',
      'Time for your weekly weight check!',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_reminders',
          'Health Reminders',
          channelDescription: 'Health reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: jsonEncode({
        'type': 'weight',
        'userId': userId,
      }),
    );
    
    _logNotificationToDatabase(
      userId: userId,
      title: '⚖️ Weekly Weigh-In',
      body: 'Time for your weekly weight check!',
      type: 'weight',
    );
    
    print('✅ [WEIGHT] Scheduled for Mondays at 8:00 AM');
  }

  Future<void> scheduleSleepNotificationWithUserData(
    String userId, 
    Map<String, dynamic> userProfile,
  ) async {
    // Get user's wake time to schedule sleep log reminder
    final wakeupTime = userProfile['wakeup_time'] ?? 
                      userProfile['wakeupTime'] ?? 
                      '06:00';
    
    // Parse wake time
    final timeParts = wakeupTime.toString().split(':');
    final wakeHour = int.tryParse(timeParts[0]) ?? 6;
    final wakeMinute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
    
    // Schedule sleep log reminder 30 minutes after wake time
    final reminderHour = (wakeHour + (wakeMinute >= 30 ? 1 : 0)) % 24;
    final reminderMinute = (wakeMinute + 30) % 60;
    
    await _scheduleNotification(
      id: sleepNotificationId,
      title: '😴 Sleep Log Reminder',
      body: 'How was your sleep last night? Log it now!',
      hour: reminderHour,
      minute: reminderMinute,
      userId: userId,
    );
    
    print('✅ [SLEEP] Scheduled at $reminderHour:${reminderMinute.toString().padLeft(2, '0')} (30min after wake time)');
  }


  Future<void> scheduleMealNotifications(String userId, Map<String, dynamic> userProfile) async {
    print('🍽️ [MEALS] Scheduling notifications');
    
    final int mealsPerDay = userProfile['daily_meals_count'] ?? 
                            userProfile['dailyMealsCount'] ?? 
                            3;
    
    List<Map<String, dynamic>> mealTimes = _getMealTimes(mealsPerDay);
    
    for (int i = 0; i < mealTimes.length; i++) {
      final mealTime = mealTimes[i];
      await _scheduleNotification(
        id: mealNotificationIdBase + i,
        title: '🍽️ ${mealTime['name']} Reminder',
        body: 'Time to log your ${mealTime['name'].toLowerCase()}!',
        hour: mealTime['hour'],
        minute: mealTime['minute'],
        userId: userId,
      );
    }
  }

  List<Map<String, dynamic>> _getMealTimes(int mealsPerDay) {
    if (mealsPerDay == 2) {
      return [
        {'name': 'First Meal', 'hour': 11, 'minute': 0},
        {'name': 'Second Meal', 'hour': 18, 'minute': 0},
      ];
    } else if (mealsPerDay == 3) {
      return [
        {'name': 'Breakfast', 'hour': 8, 'minute': 0},
        {'name': 'Lunch', 'hour': 13, 'minute': 0},
        {'name': 'Dinner', 'hour': 19, 'minute': 0},
      ];
    } else if (mealsPerDay == 4) {
      return [
        {'name': 'Breakfast', 'hour': 8, 'minute': 0},
        {'name': 'Lunch', 'hour': 12, 'minute': 30},
        {'name': 'Snack', 'hour': 15, 'minute': 30},
        {'name': 'Dinner', 'hour': 19, 'minute': 0},
      ];
    } else if (mealsPerDay >= 5) {
      return [
        {'name': 'Breakfast', 'hour': 8, 'minute': 0},
        {'name': 'Snack 1', 'hour': 10, 'minute': 30},
        {'name': 'Lunch', 'hour': 13, 'minute': 0},
        {'name': 'Snack 2', 'hour': 16, 'minute': 0},
        {'name': 'Dinner', 'hour': 19, 'minute': 0},
      ];
    }
    
    return [
      {'name': 'Breakfast', 'hour': 8, 'minute': 0},
      {'name': 'Lunch', 'hour': 13, 'minute': 0},
      {'name': 'Dinner', 'hour': 19, 'minute': 0},
    ];
  }

  Future<void> scheduleExerciseNotification(String userId) async {
    await _scheduleNotification(
      id: exerciseNotificationId,
      title: '💪 Exercise Reminder',
      body: 'Don\'t forget to log your workout!',
      hour: 18,
      minute: 0,
      userId: userId,
    );
  }

  Future<void> scheduleWaterNotifications(String userId) async {
    await _scheduleNotification(
      id: waterNotificationId1,
      title: '💧 Hydration Check',
      body: 'Remember to log your water intake!',
      hour: 10,
      minute: 0,
      userId: userId,
    );
    
    await _scheduleNotification(
      id: waterNotificationId2,
      title: '💧 Stay Hydrated',
      body: 'Time to log your water!',
      hour: 16,
      minute: 0,
      userId: userId,
    );
  }

  Future<void> scheduleSleepNotification(String userId, Map<String, dynamic> userProfile) async {
    await _scheduleNotification(
      id: sleepNotificationId,
      title: '😴 Sleep Log Reminder',
      body: 'How was your sleep last night?',
      hour: 9,
      minute: 0,
      userId: userId,
    );
  }

  Future<void> scheduleSupplementNotification(String userId) async {
    await _scheduleNotification(
      id: supplementNotificationId,
      title: '💊 Supplement Reminder',
      body: 'Time to take your supplements!',
      hour: 8,
      minute: 30,
      userId: userId,
    );
  }

  // ⭐ MINIMAL NOTIFICATION - Only required parameters
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String userId,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      print('⏰ [SCHEDULE] ID $id at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');

      // ⭐ MINIMAL settings - only what's required
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'health_reminders',  // Use the channel we created
            'Health Reminders',
            channelDescription: 'Daily health tracking reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({'type': 'reminder', 'user_id': userId}),
      );

      // Log to database (non-blocking)
      _logNotificationToDatabase(
        userId: userId,
        title: title,
        body: body,
        type: 'reminder',
      ).catchError((e) => print('⚠️ DB log failed: $e'));

      print('✅ [SCHEDULE] ID $id scheduled successfully');
    } catch (e) {
      print('❌ [SCHEDULE ERROR] ID $id failed: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? userId,        
    String type = 'test',
  }) async {
    print('🔔 [IMMEDIATE] Showing: $title');
    
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_reminders',
          'Health Reminders',
          channelDescription: 'Health reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    if (userId != null) {
      _logNotificationToDatabase(
        userId: userId,
        title: title,
        body: body,
        type: type,
      ).catchError((e) => print('⚠️ DB log failed: $e'));
    }
  }

  Future<String?> _logNotificationToDatabase({
    required String userId,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/notifications/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'title': title,
          'message': body,
          'type': type,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['notification']?['id'];
      }
      return null;
    } catch (e) {
      print('❌ Error logging notification: $e');
      return null;
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print('🔕 All notifications cancelled');
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  Future<void> showTestNotification() async {
    await showImmediateNotification(
      id: 999,
      title: '🧪 Test Notification',
      body: 'If you see this, notifications are working!',
    );
  }

  // Get unread notification count from backend
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/notifications/unread/$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // Show milestone notification (for achievements like step goals)
  Future<void> showMilestoneNotification({
    required int id,
    required String title,
    required String body,
    required String userId,
    required String milestoneType,
  }) async {
    print('🎉 [MILESTONE] Showing: $title');
    
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_reminders',
          'Health Reminders',
          channelDescription: 'Milestone achievements',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Log to database
    await _logNotificationToDatabase(
      userId: userId,
      title: title,
      body: body,
      type: milestoneType,
    );
  }
}