import 'package:flutter/material.dart';

import 'screens/account_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/home_feed.dart';
import 'screens/my_orders_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/public_votes_screen.dart';
import 'screens/quick_create_flow.dart';
import 'widgets/auth_widgets.dart'
    show authPrimary;
import 'widgets/liquid_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      endDrawer: HomeDrawer(onSelectTab: (i) => setState(() => _navIndex = i)),
      body: LiveNotificationListener(
        child: SafeArea(
          bottom: false,
          child: switch (_navIndex) {
            0 => HomeFeed(onOpenAccount: () => setState(() => _navIndex = 4)),
            1 => const PublicVotesScreen(),
            3 => const MyOrdersScreen(),
            4 => const AccountScreen(),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
      floatingActionButton: const _AiAssistantFab(),
      bottomNavigationBar: LiquidGlassNavBar(
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == 2) {
            openQuickCreateFlow(context);
          } else {
            setState(() => _navIndex = index);
          }
        },
      ),
    );
  }
}

/// Bouton flottant de l'assistant IA (recommandations d'événements),
/// accessible depuis tous les onglets de l'accueil.
class _AiAssistantFab extends StatelessWidget {
  const _AiAssistantFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'ai-assistant',
      tooltip: 'Assistant IA',
      backgroundColor: authPrimary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
      ),
      child: const Icon(Icons.auto_awesome),
    );
  }
}
