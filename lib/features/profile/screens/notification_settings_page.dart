// lib/features/profile/screens/notification_settings_page.dart
// FINAL VERSION - Read-only meal count, no redundancy, single source of truth

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/notification_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/notification_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationSettingsPage extends StatefulWidget {
  final String userId;
  final UserProfile? userProfile;

  const NotificationSettingsPage({
    Key? key,
    required this.userId,
    this.userProfile,
  }) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const String backendUrl = 'https://health-ai-backend-i28b.onrender.com';
  
  late NotificationPreferences _prefs;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isSaving = false;
  int _scheduledCount = 0;

  @override
  void initState() {
    super.initState();
    _userProfile = widget.userProfile;
    _loadUserProfile();
    _loadPreferences();
    _loadScheduledCount();
  }

  Future<void> _loadUserProfile() async {
    if (_userProfile != null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      
      if (profileJson != null) {
        _userProfile = UserProfile.fromMap(jsonDecode(profileJson));
        setState(() {});
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/notification-preferences/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _prefs = NotificationPreferences.fromJson(data['preferences']);
      } else {
        await _loadFromLocalStorage();
      }
    } catch (e) {
      print('Error loading from backend: $e, falling back to local storage');
      await _loadFromLocalStorage();
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString('notification_prefs_${widget.userId}');
    
    if (prefsJson != null) {
      _prefs = NotificationPreferences.fromJson(jsonDecode(prefsJson));
    } else {
      _prefs = NotificationPreferences();
    }
  }

  Future<void> _loadScheduledCount() async {
    try {
      final notificationService = NotificationService();
      final pending = await notificationService.getPendingNotifications();
      setState(() {
        _scheduledCount = pending.length;
      });
    } catch (e) {
      print('Error loading scheduled count: $e');
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'notification_prefs_${widget.userId}',
        jsonEncode(_prefs.toJson()),
      );
      
      try {
        await http.post(
          Uri.parse('$backendUrl/notification-preferences/save'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': widget.userId,
            ..._prefs.toJson(),
          }),
        ).timeout(const Duration(seconds: 10));
        print('✅ Preferences saved to backend');
      } catch (e) {
        print('⚠️ Could not save to backend: $e (but saved locally)');
      }
      
      if (_prefs.enabled) {
        await _rescheduleNotifications();
      } else {
        await NotificationService().cancelAllNotifications();
      }
      
      await _loadScheduledCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Settings saved! $_scheduledCount notifications scheduled'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: _viewScheduledNotifications,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error saving notification preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() => _isSaving = false);
  }

  Future<void> _rescheduleNotifications() async {
    try {
      final notificationService = NotificationService();
      await notificationService.cancelAllNotifications();
      
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      
      if (profileJson != null) {
        final userProfileMap = jsonDecode(profileJson);
        await notificationService.scheduleAllNotifications(widget.userId, userProfileMap);
        print('✅ Notifications rescheduled with new preferences');
      }
    } catch (e) {
      print('❌ Error rescheduling notifications: $e');
    }
  }

  Future<void> _sendTestNotification() async {
    final notificationService = NotificationService();
    
    await notificationService.showImmediateNotification(
      id: 999,
      title: '🎉 Test Notification',
      body: 'Your notifications are working perfectly!',
      userId: widget.userId,  
      type: 'test',  
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test notification sent!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _viewScheduledNotifications() async {
    final notificationService = NotificationService();
    final pending = await notificationService.getPendingNotifications();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scheduled Notifications (${pending.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: pending.isEmpty
              ? const Text('No notifications scheduled')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final notif = pending[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text('${notif.id}'),
                      ),
                      title: Text(
                        notif.title ?? 'Notification',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        notif.body ?? '',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults?'),
        content: const Text('This will reset all notification settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _prefs = NotificationPreferences();
      });
      await _savePreferences();
    }
  }

  String _getUserContextInfo() {
    if (_userProfile == null) return '';
    
    final List<String> info = [];
    
    final mealCount = _userProfile!.dailyMealsCount ?? 3;
    info.add('$mealCount meals/day');
    
    final waterGoal = _userProfile!.waterIntakeGlasses ?? 8;
    info.add('$waterGoal glasses water');
    
    if (_userProfile!.wakeupTime != null && _userProfile!.wakeupTime!.isNotEmpty) {
      info.add('Wake: ${_userProfile!.wakeupTime}');
    }
    
    return info.join(' • ');
  }

  bool _isFeatureApplicable(String feature) {
    if (_userProfile == null) return true;
    
    switch (feature) {
      case 'exercise':
        final workouts = _userProfile!.preferredWorkouts ?? [];
        return workouts.isNotEmpty;
      
      case 'supplement':
        final conditions = _userProfile!.medicalConditions ?? [];
        return conditions.isNotEmpty;
      
      case 'weight':
        final goal = _userProfile!.weightGoal ?? '';
        return goal.isNotEmpty && goal != 'maintain';
      
      default:
        return true;
    }
  }

  /// ⭐ Get smart meal label based on user's meal count
  String _getMealLabel(int mealIndex) {
    final mealCount = _userProfile?.dailyMealsCount ?? 3;
    
    if (mealCount == 1) {
      return 'Meal Time';
    } else if (mealCount == 2) {
      return mealIndex == 0 ? 'First Meal Time' : 'Second Meal Time';
    } else if (mealCount == 3) {
      // Use traditional names for 3 meals
      return ['Breakfast Time', 'Lunch Time', 'Dinner Time'][mealIndex];
    } else {
      // For 4+ meals, use meal numbers
      return 'Meal ${mealIndex + 1} Time';
    }
  }

  /// ⭐ Get meal time preference based on index
  TimeOfDay _getMealTime(int mealIndex) {
    switch (mealIndex) {
      case 0:
        return TimeOfDay(hour: _prefs.breakfastHour, minute: _prefs.breakfastMinute);
      case 1:
        return TimeOfDay(hour: _prefs.lunchHour, minute: _prefs.lunchMinute);
      case 2:
        return TimeOfDay(hour: _prefs.dinnerHour, minute: _prefs.dinnerMinute);
      default:
        return TimeOfDay(hour: 8, minute: 0);
    }
  }

  /// ⭐ Update meal time preference
  void _updateMealTime(int mealIndex, TimeOfDay time) {
    setState(() {
      switch (mealIndex) {
        case 0:
          _prefs.breakfastHour = time.hour;
          _prefs.breakfastMinute = time.minute;
          break;
        case 1:
          _prefs.lunchHour = time.hour;
          _prefs.lunchMinute = time.minute;
          break;
        case 2:
          _prefs.dinnerHour = time.hour;
          _prefs.dinnerMinute = time.minute;
          break;
      }
    });
  }

  /// ⭐ Navigate to profile settings to edit meal count
  void _navigateToProfileSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please update meal count in your Profile Settings'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
    
    // TODO: Navigate to profile settings page if you have the route
    // Navigator.pushNamed(context, '/profile-settings');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notification Settings'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userMealCount = _userProfile?.dailyMealsCount ?? 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _savePreferences,
            tooltip: 'Save changes',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Profile Context Card
          if (_userProfile != null && _getUserContextInfo().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Your Profile',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getUserContextInfo(),
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notifications will be personalized based on your profile',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Status Card
          if (_scheduledCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$_scheduledCount notifications scheduled',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _viewScheduledNotifications,
                    child: const Text('VIEW'),
                  ),
                ],
              ),
            ),

          // Master Toggle
          _buildSection(
            'Enable Notifications',
            [
              SwitchListTile(
                title: const Text('All Notifications'),
                subtitle: Text(
                  _prefs.enabled 
                      ? 'Notifications are enabled' 
                      : 'Notifications are disabled',
                ),
                value: _prefs.enabled,
                onChanged: (value) {
                  setState(() => _prefs.enabled = value);
                },
                activeColor: Colors.blue,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Notification Types
          _buildSection(
            'Notification Types',
            [
              _buildSwitchTileWithContext(
                '🍽️ Meal Reminders',
                'Get reminded to log your meals',
                'You eat $userMealCount meal${userMealCount > 1 ? 's' : ''}/day',
                _prefs.mealReminders,
                _prefs.enabled,
                (value) => setState(() => _prefs.mealReminders = value),
              ),
              
              _buildSwitchTileWithContext(
                '💪 Exercise Reminders',
                'Stay motivated to workout',
                !_isFeatureApplicable('exercise')
                  ? 'No workouts in profile - will be skipped'
                  : null,
                _prefs.exerciseReminders,
                _prefs.enabled,
                (value) => setState(() => _prefs.exerciseReminders = value),
              ),
              
              _buildSwitchTileWithContext(
                '💧 Water Reminders',
                'Stay hydrated throughout the day',
                _userProfile != null
                  ? 'Goal: ${_userProfile!.waterIntakeGlasses ?? 8} glasses/day'
                  : null,
                _prefs.waterReminders,
                _prefs.enabled,
                (value) => setState(() => _prefs.waterReminders = value),
              ),
              
              _buildSwitchTileWithContext(
                '😴 Sleep Reminders',
                'Track your sleep quality',
                _userProfile != null && _userProfile!.wakeupTime != null
                  ? 'Reminder at ${_userProfile!.wakeupTime}'
                  : null,
                _prefs.sleepReminders,
                _prefs.enabled,
                (value) => setState(() => _prefs.sleepReminders = value),
              ),
              
              _buildSwitchTileWithContext(
                '💊 Supplement Reminders',
                'Remember to take supplements',
                !_isFeatureApplicable('supplement')
                  ? 'No medical conditions - will be skipped'
                  : null,
                _prefs.supplementReminders,
                _prefs.enabled,
                (value) => setState(() => _prefs.supplementReminders = value),
              ),
              
              _buildSwitchTileWithContext(
                '⚖️ Weight Check Reminders',
                'Weekly weigh-in reminder',
                !_isFeatureApplicable('weight')
                  ? 'No weight goal - will be skipped'
                  : 'Goal: ${_userProfile?.weightGoal ?? ""}',
                _prefs.weightReminders,
                _prefs.enabled,
                (value) => setState(() => _prefs.weightReminders = value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ⭐ Meal Times - Read-only count with link to edit
          if (_prefs.enabled && _prefs.mealReminders)
            _buildSection(
              'Meal Reminder Times',
              [
                // Info banner with link to profile
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You eat $userMealCount meal${userMealCount > 1 ? 's' : ''} per day. Only $userMealCount reminder${userMealCount > 1 ? 's' : ''} will be scheduled.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _navigateToProfileSettings,
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              'Edit meal count in Profile Settings',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Show only the meal time pickers user needs
                ...List.generate(
                  userMealCount,
                  (index) => _buildTimePicker(
                    _getMealLabel(index),
                    _getMealTime(index),
                    (time) => _updateMealTime(index, time),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Exercise Time
          if (_prefs.enabled && _prefs.exerciseReminders)
            _buildSection(
              'Exercise Reminder Time',
              [
                _buildTimePicker(
                  'Exercise Time',
                  TimeOfDay(hour: _prefs.exerciseHour, minute: _prefs.exerciseMinute),
                  (time) {
                    setState(() {
                      _prefs.exerciseHour = time.hour;
                      _prefs.exerciseMinute = time.minute;
                    });
                  },
                ),
              ],
            ),

          const SizedBox(height: 16),

          // Water Frequency
          if (_prefs.enabled && _prefs.waterReminders)
            _buildSection(
              'Water Reminder Frequency',
              [
                ListTile(
                  title: const Text('Remind me every'),
                  subtitle: Text('${_prefs.waterReminderFrequency} hour${_prefs.waterReminderFrequency > 1 ? 's' : ''}'),
                  trailing: DropdownButton<int>(
                    value: _prefs.waterReminderFrequency,
                    items: [1, 2, 3, 4, 6].map((hours) {
                      return DropdownMenuItem(
                        value: hours,
                        child: Text('$hours hour${hours > 1 ? 's' : ''}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _prefs.waterReminderFrequency = value);
                      }
                    },
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Test Button
          ElevatedButton.icon(
            onPressed: _sendTestNotification,
            icon: const Icon(Icons.notifications_active),
            label: const Text('Send Test Notification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 12),

          // View Scheduled Button
          OutlinedButton.icon(
            onPressed: _viewScheduledNotifications,
            icon: const Icon(Icons.list),
            label: Text('View $_scheduledCount Scheduled Notifications'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 16),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Smart Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Notifications are automatically personalized based on your profile. '
                  'Only relevant reminders matching your lifestyle will be scheduled. '
                  'Update your profile to change meal count or other settings.',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTileWithContext(
    String title,
    String subtitle,
    String? contextInfo,
    bool value,
    bool enabled,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (contextInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              contextInfo,
              style: TextStyle(
                fontSize: 12,
                color: contextInfo.contains('will be skipped') 
                  ? Colors.orange 
                  : Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeColor: Colors.blue,
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onTimeSelected,
  ) {
    return ListTile(
      title: Text(label),
      trailing: InkWell(
        onTap: () async {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: time,
          );
          if (pickedTime != null) {
            onTimeSelected(pickedTime);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue),
          ),
          child: Text(
            time.format(context),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}