import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_widgets.dart' show authPrimary, authInk, authMuted;

/// Floating "liquid glass" bottom navigation bar (blurred, slightly
/// transparent) with a raised center button.
///
/// Order of the 5 sections: Events, My Orders, Post (center, raised red
/// button — opens the Organisations flow before letting the user post),
/// Posts, Account.
class LiquidGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _leftItems = [
    _NavItem(
      icon: Icons.event_outlined,
      activeIcon: Icons.event_rounded,
      label: 'Events',
    ),
    _NavItem(
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
      label: 'Orders',
    ),
  ];

  static const _rightItems = [
    _NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Posts',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Account',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.75),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildItem(_leftItems[0], 0)),
                      Expanded(child: _buildItem(_leftItems[1], 1)),
                      const SizedBox(width: 66),
                      Expanded(child: _buildItem(_rightItems[0], 3)),
                      Expanded(child: _buildItem(_rightItems[1], 4)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(bottom: 42, child: _buildCenterButton()),
        ],
      ),
    );
  }

  Widget _buildItem(_NavItem item, int index) {
    final active = currentIndex == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? item.activeIcon : item.icon,
            size: 22,
            color: active ? authPrimary : authMuted,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? authPrimary : authMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterButton() {
    final active = currentIndex == 2;
    return GestureDetector(
      onTap: () => onTap(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: authPrimary,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: authPrimary.withOpacity(0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 4),
          Text(
            'Post',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? authPrimary : authInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
