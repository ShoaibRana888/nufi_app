// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/data_manager.dart';
import 'package:user_onboarding/features/auth/screens/login_screens.dart';

class AppDrawer extends StatelessWidget {
  final UserProfile userProfile;
  final String currentSection; // 'home', 'chat', 'profile'

  const AppDrawer({
    Key? key,
    required this.userProfile,
    this.currentSection = 'home',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // User Profile Header
          _buildUserHeader(context),
          
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.home,
                  title: 'Home Dashboard',
                  onTap: () => _navigateToBottomTab(context, 0),
                  isSelected: currentSection == 'home',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.chat,
                  title: 'AI Coach Chat',
                  onTap: () => _navigateToBottomTab(context, 1),
                  isSelected: currentSection == 'chat',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.person,
                  title: 'Profile',
                  onTap: () => _navigateToBottomTab(context, 2),
                  isSelected: currentSection == 'profile',
                ),
                
                const Divider(),
                
                // Goal-specific sections
                _buildSectionHeader('Your Goal: ${userProfile.primaryGoal ?? 'Custom'}'),
                
                _buildDrawerItem(
                  context,
                  icon: Icons.monitor_weight,
                  title: 'Weight Tracking',
                  onTap: () => _showComingSoon(context, 'Weight Tracking'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.restaurant,
                  title: 'Meal Planning',
                  onTap: () => _showComingSoon(context, 'Meal Planning'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.fitness_center,
                  title: 'Workout Library',
                  onTap: () => _showComingSoon(context, 'Workout Library'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.analytics,
                  title: 'Progress Analytics',
                  onTap: () => _showComingSoon(context, 'Progress Analytics'),
                ),
                
                const Divider(),
                
                _buildDrawerItem(
                  context,
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () => _showComingSoon(context, 'Settings'),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.help,
                  title: 'Help & Support',
                  onTap: () => _showComingSoon(context, 'Help & Support'),
                ),
              ],
            ),
          ),
          
          // Logout Section
          const Divider(),
          _buildLogoutItem(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Text(
          userProfile.name.isNotEmpty 
              ? userProfile.name[0].toUpperCase()
              : 'U',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
      accountName: Text(
        userProfile.name,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      accountEmail: Text(
        userProfile.email,
        style: const TextStyle(fontSize: 14),
      ),
      otherAccountsPictures: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getGoalIcon(),
            color: Colors.blue,
            size: 20,
          ),
        ),
      ],
    );
  }

  IconData _getGoalIcon() {
    final goal = userProfile.primaryGoal?.toLowerCase() ?? '';
    if (goal.contains('lose')) return Icons.trending_down;
    if (goal.contains('gain')) return Icons.trending_up;
    if (goal.contains('muscle')) return Icons.fitness_center;
    return Icons.track_changes;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
    );
  }

  Widget _buildLogoutItem(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.logout,
        color: Colors.red,
      ),
      title: const Text(
        'Logout',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => _showLogoutDialog(context),
    );
  }

  void _navigateToBottomTab(BuildContext context, int tabIndex) {
    // Find the HomePage in the widget tree and switch tabs
    Navigator.of(context).popUntil((route) => route.isFirst);
    
    // You might need to implement a way to communicate with HomePage
    // For now, just close the drawer - the user can use bottom nav
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _performLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _performLogout(BuildContext context) async {
    try {
      Navigator.pop(context); // Close dialog
      
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Perform logout
      final dataManager = DataManager();
      await dataManager.logout();
      
      // Navigate to login screen and clear all routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}