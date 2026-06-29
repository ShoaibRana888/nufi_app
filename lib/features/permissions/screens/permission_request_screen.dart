// lib/features/permissions/screens/permission_request_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;
  
  const PermissionRequestScreen({
    Key? key,
    required this.onPermissionsGranted,
  }) : super(key: key);

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _microphoneGranted = false;
  bool _activityGranted = false;
  bool _notificationGranted = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isChecking = true);
    
    final micStatus = await Permission.microphone.status;
    final activityStatus = await Permission.activityRecognition.status;
    final notificationStatus = await Permission.notification.status;
    
    setState(() {
      _microphoneGranted = micStatus.isGranted;
      _activityGranted = activityStatus.isGranted;
      _notificationGranted = notificationStatus.isGranted;
      _isChecking = false;
    });
  }

  Future<void> _requestMicrophone() async {
    final status = await Permission.microphone.request();
    setState(() => _microphoneGranted = status.isGranted);
    
    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Microphone');
    }
  }

  Future<void> _requestActivityRecognition() async {
    final status = await Permission.activityRecognition.request();
    setState(() => _activityGranted = status.isGranted);
    
    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Activity Recognition');
    }
  }

  Future<void> _requestNotification() async {
    final status = await Permission.notification.request();
    setState(() => _notificationGranted = status.isGranted);
    
    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Notifications');
    }
  }

  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission'),
        content: Text(
          'This permission has been permanently denied. Please enable it in app settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  bool get _allPermissionsGranted =>
      _microphoneGranted && _activityGranted && _notificationGranted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isChecking
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Header
                    const Icon(
                      Icons.security,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Enable Permissions',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'To provide you with the best experience, we need access to the following:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    // Permission cards
                    _buildPermissionCard(
                      icon: Icons.mic,
                      title: 'Microphone',
                      description: 'Log meals and exercises using voice commands',
                      isGranted: _microphoneGranted,
                      onRequest: _requestMicrophone,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPermissionCard(
                      icon: Icons.directions_walk,
                      title: 'Activity Recognition',
                      description: 'Track your daily steps and physical activity',
                      isGranted: _activityGranted,
                      onRequest: _requestActivityRecognition,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPermissionCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      description: 'Receive reminders for meals, water, and workouts',
                      isGranted: _notificationGranted,
                      onRequest: _requestNotification,
                    ),
                    
                    const Spacer(),
                    
                    // Continue button
                    ElevatedButton(
                      onPressed: _allPermissionsGranted
                          ? widget.onPermissionsGranted
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Skip button
                    TextButton(
                      onPressed: widget.onPermissionsGranted,
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isGranted ? Colors.green : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          isGranted
              ? const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                )
              : ElevatedButton(
                  onPressed: onRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Allow'),
                ),
        ],
      ),
    );
  }
}