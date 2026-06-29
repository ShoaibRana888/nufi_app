// lib/features/profile/screens/settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/providers/theme_provider.dart';
import 'package:user_onboarding/data/services/notification_service.dart';
import 'package:user_onboarding/data/services/api/auth_api.dart';
import 'package:user_onboarding/data/managers/user_manager.dart';
import 'package:user_onboarding/features/auth/screens/login_screens.dart';
import 'package:user_onboarding/features/profile/screens/notification_settings_page.dart';
import 'package:user_onboarding/features/notifications/screens/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  final UserProfile userProfile;

  const SettingsPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _dataSync = true;
  String _selectedUnits = 'Metric';

  Future<void> _scheduleNotifications() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scheduling notifications...'),
            ],
          ),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final profileJson = prefs.getString('user_profile');

      if (userId == null || profileJson == null) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Please log in first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userProfile = jsonDecode(profileJson);
      final notificationService = NotificationService();

      // Initialize
      try {
        await notificationService.initialize();
        print('✅ Initialized');
      } catch (e) {
        print('⚠️ Init warning: $e');
      }

      // Schedule notifications (they will override old ones with same ID)
      int successCount = 0;
      
      try {
        await notificationService.scheduleMealNotifications(userId, userProfile);
        final mealsCount = userProfile['daily_meals_count'] ?? userProfile['dailyMealsCount'] ?? 3;
        successCount += (mealsCount is int ? mealsCount : (mealsCount as num).toInt());
      } catch (e) {
        print('⚠️ Meals error: $e');
      }

      try {
        await notificationService.scheduleExerciseNotification(userId);
        successCount++;
      } catch (e) {
        print('⚠️ Exercise error: $e');
      }

      try {
        await notificationService.scheduleWaterNotifications(userId);
        successCount += 2;
      } catch (e) {
        print('⚠️ Water error: $e');
      }

      try {
        await notificationService.scheduleSleepNotification(userId, userProfile);
        successCount++;
      } catch (e) {
        print('⚠️ Sleep error: $e');
      }

      try {
        await notificationService.scheduleSupplementNotification(userId);
        successCount++;
      } catch (e) {
        print('⚠️ Supplement error: $e');
      }

      // Save timestamp
      await prefs.setString(
        'notifications_last_scheduled_$userId',
        DateTime.now().toIso8601String(),
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Scheduled $successCount notifications!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        _showSuccessDialog(successCount);
      }
    } catch (e) {
      print('❌ Error: $e');
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString().substring(0, 50)}...'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('✅ Success!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scheduled $count notifications',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('Next notifications:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• 8:00 AM - Breakfast'),
              const Text('• 8:30 AM - Supplement'),
              const Text('• 9:00 AM - Sleep Log'),
              const Text('• 10:00 AM - Water'),
              const Text('• 1:00 PM - Lunch'),
              const Text('• 4:00 PM - Water'),
              const Text('• 6:00 PM - Exercise'),
              const Text('• 7:00 PM - Dinner'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 What happens next:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('• Notifications will appear at these times'),
                    Text('• Check your notification panel when they fire'),
                    Text('• If app restarts, they will persist'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // ⭐ SIMPLE FIX BUTTON - No complex widget
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notification_important, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Notification Setup',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click the button below to schedule your daily health reminders.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _scheduleNotifications,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.notifications_active),
                    label: const Text(
                      'SCHEDULE NOTIFICATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          _buildSection(
            'Notifications',
            [
              _buildSwitchTile(
                'Push Notifications',
                'Receive workout reminders and updates',
                _pushNotifications,
                (value) => setState(() => _pushNotifications = value),
              ),
              _buildSwitchTile(
                'Email Notifications',
                'Get weekly progress reports via email',
                _emailNotifications,
                (value) => setState(() => _emailNotifications = value),
              ),
              _buildTile(
                'Notification Preferences',
                'Customize your reminder times',
                Icons.notifications_active,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationSettingsPage(
                        userId: widget.userProfile.id,
                      ),
                    ),
                  );
                },
              ),
              _buildTile(
                'View Notifications',
                'See all your notifications',
                Icons.notifications,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(
                        userId: widget.userProfile.id,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          _buildSection(
            'Data & Privacy',
            [
              _buildSwitchTile(
                'Data Synchronization',
                'Sync your data across devices',
                _dataSync,
                (value) => setState(() => _dataSync = value),
              ),
              _buildTile(
                'Export Data',
                'Download your health data',
                Icons.download,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data export coming soon!')),
                  );
                },
              ),
            ],
          ),
          _buildSection(
            'Preferences',
            [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => _buildDropdownTile(
                  'Theme',
                  themeProvider.label,
                  ['Light', 'Dark', 'System'],
                  (value) {
                    if (value != null) themeProvider.setFromLabel(value);
                  },
                ),
              ),
              _buildDropdownTile(
                'Units',
                _selectedUnits,
                ['Metric', 'Imperial'],
                (value) => setState(() => _selectedUnits = value!),
              ),
            ],
          ),
          _buildSection(
            'Support',
            [
              _buildTile(
                'Help Center',
                'Get help and support',
                Icons.help,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help center coming soon!')),
                  );
                },
              ),
              _buildTile(
                'Send Feedback',
                'Share your thoughts with us',
                Icons.feedback,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Feedback form coming soon!')),
                  );
                },
              ),
            ],
          ),
          _buildSection(
            'Account',
            [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete your account and all your data',
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: _confirmAndDeleteAccount,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteAccount() async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool canDelete = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Account'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your account and all your data — '
                    'meals, workouts, sleep, water, weight, supplements, period logs, '
                    'and chat history. This action cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type DELETE to confirm:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        canDelete = value.trim().toUpperCase() == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      canDelete ? () => Navigator.pop(dialogContext, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.shade100,
                  ),
                  child: const Text('Delete Forever'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await _performAccountDeletion();
    }
  }

  Future<void> _performAccountDeletion() async {
    // Capture context-bound objects before any async gaps.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting your account...'),
          ],
        ),
      ),
    );

    try {
      final userId = widget.userProfile.id;
      if (userId.isEmpty) {
        throw Exception('No user ID found');
      }

      // Delete everything on the backend first.
      await AuthApi().deleteAccount(userId);

      // Then wipe all local state.
      await UserManager.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      navigator.pop(); // close loading dialog

      // Send the user back to login, clearing the whole navigation stack.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      navigator.pop(); // close loading dialog
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    void Function(bool) onChanged,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildDropdownTile(
    String title,
    String value,
    List<String> options,
    void Function(String?) onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}