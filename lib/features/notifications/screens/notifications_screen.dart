// lib/features/notifications/screens/notifications_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  final String? userId;

  const NotificationsScreen({super.key, this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> notifications = [];
  Map<String, List<Map<String, dynamic>>> groupedNotifications = {};
  bool isLoading = true;
  String? userId;
  String? errorMessage;
  final String backendUrl = 'https://health-ai-backend-i28b.onrender.com';
  bool isBackendWakingUp = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    print('🔍 [NotificationsScreen] Initializing...');
    
    userId = widget.userId;
    print('🔍 [NotificationsScreen] Widget userId: $userId');
    
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('user_id');
      print('🔍 [NotificationsScreen] SharedPreferences userId: $userId');
    }
    
    if (userId == null) {
      print('❌ [NotificationsScreen] No user ID available');
      setState(() {
        isLoading = false;
        errorMessage = 'User ID not found. Please log in again.';
      });
      return;
    }
    
    print('✅ [NotificationsScreen] Using userId: $userId');
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (userId == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'User ID is missing';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      isBackendWakingUp = false;
    });

    print('📡 [NotificationsScreen] Fetching notifications for userId: $userId');
    final url = '$backendUrl/notifications/$userId';
    print('📡 [NotificationsScreen] URL: $url');

    try {
      print('📡 [NotificationsScreen] Making HTTP request...');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 60),  // 60 seconds for sleeping backend
        onTimeout: () {
          print('⏱️ [NotificationsScreen] Request timed out after 30 seconds');
          setState(() {
            isBackendWakingUp = true;
          });
          throw TimeoutException('Backend is waking up. Please wait and retry in a moment.');
        },
      );

      print('📡 [NotificationsScreen] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifList = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        
        setState(() {
          notifications = notifList;
          groupedNotifications = _groupNotificationsByDate(notifications);
          isLoading = false;
          errorMessage = null;
          isBackendWakingUp = false;
        });

        print('✅ [NotificationsScreen] Loaded ${notifications.length} notifications');
      } else if (response.statusCode == 404) {
        print('⚠️ [NotificationsScreen] No notifications found (404)');
        setState(() {
          notifications = [];
          groupedNotifications = {};
          isLoading = false;
          errorMessage = null;
          isBackendWakingUp = false;
        });
      } else if (response.statusCode == 503) {
        print('⚠️ [NotificationsScreen] Backend is sleeping (503)');
        setState(() {
          isLoading = false;
          errorMessage = 'Backend is waking up. Please wait 30 seconds and try again.';
          isBackendWakingUp = true;
        });
      } else {
        print('❌ [NotificationsScreen] Failed: ${response.statusCode}');
        setState(() {
          notifications = [];
          groupedNotifications = {};
          isLoading = false;
          errorMessage = 'Failed to load notifications (${response.statusCode})';
          isBackendWakingUp = false;
        });
      }
    } catch (e) {
      print('❌ [NotificationsScreen] Error: $e');
      
      final isSleepingError = e.toString().contains('waking up') || 
                             e.toString().contains('timed out');
      
      setState(() {
        notifications = [];
        groupedNotifications = {};
        isLoading = false;
        errorMessage = isSleepingError 
            ? 'Backend is waking up (free tier). Please wait 30 seconds and retry.'
            : 'Network error: ${e.toString()}';
        isBackendWakingUp = isSleepingError;
      });

      if (mounted && !isSleepingError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupNotificationsByDate(
      List<Map<String, dynamic>> notifs) {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var notif in notifs) {
      try {
        final createdAt = DateTime.parse(notif['created_at']);
        final dateKey = _getDateKey(createdAt);

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(notif);
      } catch (e) {
        print('❌ Error parsing date: $e');
      }
    }

    return grouped;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (dateOnly.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$backendUrl/notifications/mark-read/$notificationId'),
      );
      
      if (response.statusCode == 200) {
        // Refresh the notification list
        await _loadNotifications();
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (userId == null) return;
    
    try {
      await http.put(
        Uri.parse('$backendUrl/notifications/mark-all-read/$userId'),
      );
      
      // ⭐ ADD THIS CHECK
      if (mounted) {
        await _loadNotifications();
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = notifications.any((n) => n['is_read'] == false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (hasUnread && !isLoading)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      isBackendWakingUp 
                        ? 'Waking up backend...'
                        : 'Loading notifications...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    if (isBackendWakingUp) ...[
                      const SizedBox(height: 8),
                      Text(
                        'This may take 30 seconds (free tier)',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isBackendWakingUp 
                                ? Icons.hourglass_empty 
                                : Icons.error_outline,
                            size: 64,
                            color: isBackendWakingUp 
                                ? Colors.orange[300] 
                                : Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isBackendWakingUp 
                                ? 'Backend is Waking Up' 
                                : 'Error',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (isBackendWakingUp) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Render free tier backends sleep after 15 minutes of inactivity. They take about 30 seconds to wake up.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadNotifications,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              isBackendWakingUp ? 'Retry Now' : 'Retry',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : notifications.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You\'ll see your reminders here',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: groupedNotifications.length,
                        itemBuilder: (context, index) {
                          final dateKey = groupedNotifications.keys.elementAt(index);
                          final dateNotifications = groupedNotifications[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  dateKey,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              ...dateNotifications.map((notification) {
                                final isRead = notification['is_read'] == true;
                                final createdAt = DateTime.parse(notification['created_at']);
                                final timeAgo = _getTimeAgo(createdAt);

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.white : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF6C63FF),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (!isRead) const SizedBox(width: 8),
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: _getNotificationColor(
                                                    notification['type'])
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(notification['type']),
                                            color: _getNotificationColor(
                                                notification['type']),
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      notification['title'] ?? 'Notification',
                                      style: TextStyle(
                                        fontWeight: isRead
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          notification['message'] ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          timeAgo,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      if (!isRead) {
                                        _markAsRead(notification['id']);
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        },
                      ),
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'meal':
      case 'breakfast':
      case 'lunch':
      case 'dinner':
        return Icons.restaurant;
      case 'water':
      case 'hydration':
        return Icons.water_drop;
      case 'exercise':
      case 'workout':
        return Icons.fitness_center;
      case 'sleep':
        return Icons.bedtime;
      case 'weight':
        return Icons.monitor_weight;
      case 'supplement':
        return Icons.medication;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'meal':
      case 'breakfast':
      case 'lunch':
      case 'dinner':
        return Colors.orange;
      case 'water':
      case 'hydration':
        return Colors.blue;
      case 'exercise':
      case 'workout':
        return Colors.purple;
      case 'sleep':
        return Colors.indigo;
      case 'weight':
        return Colors.green;
      case 'supplement':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}