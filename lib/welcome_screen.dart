import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_screen.dart';

/// 4-page scrollable onboarding, shown after the splash screen.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String imageAsset;
  final IconData fallbackIcon;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.fallbackIcon,
  });
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'Showcase your events',
      subtitle:
      'Publish your events and get them discovered by thousands of people around you.',
      imageAsset: 'assets/images/onboarding_1.jpg',
      fallbackIcon: Icons.storefront_outlined,
    ),
    _OnboardingPage(
      title: 'Buy or book your tickets',
      subtitle:
      'Book and pay for your tickets securely, directly from the app.',
      imageAsset: 'assets/images/onboarding_2.jpg',
      fallbackIcon: Icons.confirmation_number_outlined,
    ),
    _OnboardingPage(
      title: 'Vote online',
      subtitle:
      'Take part in votes and share your opinion on the events and artists you love.',
      imageAsset: 'assets/images/onboarding_3.jpg',
      fallbackIcon: Icons.how_to_vote_outlined,
    ),
    _OnboardingPage(
      title: 'Interact with events and the community',
      subtitle:
      'Chat, comment, and connect with other fans around every event.',
      imageAsset: 'assets/images/onboarding_4.jpg',
      fallbackIcon: Icons.groups_outlined,
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onNext() {
    if (_isLastPage) {
      _goToLogin();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            // --- "Skip" button top right ---
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: TextButton(
                  onPressed: _isLastPage ? null : _goToLogin,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isLastPage
                          ? Colors.transparent
                          : const Color(0xFF6B6B72),
                    ),
                  ),
                ),
              ),
            ),

            // --- Scrollable pages ---
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Column(
                    children: [
                      // --- Ambiance image, rounded corners ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SizedBox(
                            height: size.height * 0.38,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  page.imageAsset,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF0F2A6B)
                                                  .withOpacity(0.9),
                                              const Color(0xFFE30B4C)
                                                  .withOpacity(0.85),
                                            ],
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            page.fallbackIcon,
                                            color: Colors.white70,
                                            size: 56,
                                          ),
                                        ),
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.15),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            Text(
                              page.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A1A1E),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF6B6B72),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // --- Page indicators (dots) ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFE30B4C)
                          : const Color(0xFFE30B4C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // --- Next / Get Started button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE30B4C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isLastPage ? 'Get Started' : 'Next',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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