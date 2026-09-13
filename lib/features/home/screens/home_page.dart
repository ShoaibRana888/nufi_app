// lib/features/home/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/features/home/screens/dashboard_home.dart';
import 'package:user_onboarding/features/chat/screens/chat_page.dart';
import 'package:user_onboarding/features/profile/screens/profile_page.dart';
import 'package:user_onboarding/providers/user_provider.dart';
import 'package:user_onboarding/utils/profile_update_notifier.dart';

class HomePage extends StatefulWidget {
  final UserProfile userProfile;
  
  const HomePage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late PageController _pageController;
  late UserProfile _currentUserProfile;
  late StreamSubscription<UserProfile> _profileSubscription;
  late StreamSubscription<void> _refreshSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _currentUserProfile = widget.userProfile;
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Listen to profile updates
    _profileSubscription = ProfileUpdateNotifier().profileUpdates.listen((profile) {
      if (mounted) {
        setState(() {
          _currentUserProfile = profile;
        });
      }
    });
    
    // Listen to refresh requests
    _refreshSubscription = ProfileUpdateNotifier().refreshRequests.listen((_) {
      if (mounted) {
        _refreshProfile();
      }
    });
    
    // Initial load
    _refreshProfile();
  }
  
  @override
  void dispose() {
    _profileSubscription.cancel();
    _refreshSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      print('🔄 App resumed, refreshing home page data...');
      _refreshProfile();
    }
  }
  
  Future<void> _refreshProfile() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.refreshProfile();
    
    if (userProvider.userProfile != null && mounted) {
      setState(() {
        _currentUserProfile = userProvider.userProfile!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        // Use provider's profile if available, otherwise use current
        final profile = userProvider.userProfile ?? _currentUserProfile;
        
        return Scaffold(
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: [
              DashboardHome(userProfile: profile),
              ChatPage(userProfile: profile),
              ProfilePage(userProfile: profile),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.psychology),
                label: 'AI Coach',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}