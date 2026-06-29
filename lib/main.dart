// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:user_onboarding/providers/user_provider.dart';
import 'package:user_onboarding/providers/theme_provider.dart';
import 'package:user_onboarding/config/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/features/splash/screens/splash_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:user_onboarding/data/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 
import 'package:user_onboarding/services/fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [FCM] Background message received');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ FLUTTER ERROR: ${details.exception}');
    print('📍 Stack trace: ${details.stack}');
  };
  
  try {
    print('🚀 Starting app initialization...');
    
    // Initialize timezone
    print('🌍 Initializing timezones...');
    tz.initializeTimeZones();

    // Initialize Firebase with options
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');


    // Background message handling relies on a native/service-worker handler.
    // On web it needs a configured service worker + VAPID key, so skip it.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Initialize FCM Service (no-op on web)
    print('🔔 Initializing FCM Service...');
    final fcmService = FCMService();
    await fcmService.initialize();
    print('✅ FCM Service initialized successfully');

    // Set timezone
    _setTimezone();

    // Load environment variables
    print('📝 Loading environment variables...');
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded');

    // Initialize Supabase
    print('🗄️ Initializing Supabase...');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print('✅ Supabase initialized successfully');

    

    // Initialize notification service
    print('🔔 Initializing Notification Service...');
    await NotificationService().initialize();
    print('✅ Notification Service initialized');

    print('🎉 All services initialized successfully, launching app...');

    // Run the app
    runApp(const MyApp());
    
  } catch (e, stackTrace) {
    print('❌ CRITICAL ERROR during initialization: $e');
    print('📍 Stack trace: $stackTrace');
    
    // Show error screen
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Failed to Initialize App',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Note: This won't actually restart the app
                      // User needs to manually restart
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Restart Required'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _setTimezone() {
  final String timeZoneName = DateTime.now().timeZoneName;
  try {
    if (timeZoneName.isNotEmpty && timeZoneName != 'UTC') {
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        print('🌍 Timezone set to: $timeZoneName');
      } catch (e) {
        final location = _findClosestTimezone(timeZoneName);
        tz.setLocalLocation(location);
        print('🌍 Timezone set to: ${location.name}');
      }
    } else {
      tz.setLocalLocation(tz.local);
      print('🌍 Timezone set to: ${tz.local.name}');
    }
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('UTC'));
    print('⚠️ Timezone set to UTC (fallback)');
  }
}

tz.Location _findClosestTimezone(String timeZoneName) {
  final Map<String, String> timezoneMap = {
    'PKT': 'Asia/Karachi',
    'PST': 'America/Los_Angeles',
    'EST': 'America/New_York',
    'CST': 'America/Chicago',
    'MST': 'America/Denver',
    'IST': 'Asia/Kolkata',
    'GMT': 'Europe/London',
    'CET': 'Europe/Paris',
    'JST': 'Asia/Tokyo',
  };

  if (timezoneMap.containsKey(timeZoneName)) {
    try {
      return tz.getLocation(timezoneMap[timeZoneName]!);
    } catch (e) {
      // Continue to fallback
    }
  }

  return tz.getLocation('UTC');
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Nufitionist',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}