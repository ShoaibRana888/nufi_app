// lib/features/splash/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:user_onboarding/providers/user_provider.dart';
import 'package:user_onboarding/features/home/screens/home_page.dart';
import 'package:user_onboarding/features/auth/screens/login_screens.dart';
import 'package:user_onboarding/data/managers/user_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    _checkAuthStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    // Wait a bit to show splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Check if user is logged in
    final isLoggedIn = await UserManager.isLoggedIn();

    if (isLoggedIn) {
      // Load user profile
      await userProvider.loadUser();

      if (userProvider.userProfile != null && mounted) {
        // Navigate to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userProfile: userProvider.userProfile!),
          ),
        );
      } else {
        // If profile load failed, go to login
        _navigateToLogin();
      }
    } else {
      // Not logged in, go to login
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Nufitionist',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your personal health & nutrition coach',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
