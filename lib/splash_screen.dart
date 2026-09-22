import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'services/auth_service.dart';
import 'welcome_screen.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF0F2A6B);
  static const Color primaryRed = Color(0xFFE30B4C);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F7);
}

/// Startup ("Splash") screen — shown during the initial loading
/// (SharedPreferences check, session, etc.) before routing to
/// WelcomeScreen / LoginScreen / HomeScreen as defined in main.dart.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Redirects to HomeScreen if a session is already active, otherwise
    // to the onboarding flow. Capped at 2 seconds so the splash never
    // blocks the app if Firebase is slow to report the auth state.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final isSignedIn = AuthService.instance.currentUser != null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              isSignedIn ? const HomeScreen() : const WelcomeScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // --- Centered main content (logo + wordmark) ---
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- LOGO ---
                      Image.asset(
                        'assets/images/logo.png',
                        width: 220,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- Progress bar anchored at the bottom, independent of the center ---
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: FadeTransition(
                opacity: _fade,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor:
                        AppColors.primaryRed.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryRed,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}