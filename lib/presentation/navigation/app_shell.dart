import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'transport_mode_fab.dart';

/// Main application shell with bottom navigation and central transport FAB.
///
/// Features animated operator theme transitions (Metro Red vs Bus Emerald)
/// and custom designer navigation bar iconography.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  /// The routed page content.
  final Widget child;

  /// Active navigation tab index (0-3).
  final int currentIndex;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  void _onTabSelected(int index) {
    final path = switch (index) {
      0 => '/',
      1 => '/saved-trips',
      2 => '/alerts',
      3 => '/settings',
      _ => '/',
    };
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final transportMode = ref.watch(transportModeProvider);
    final isBus = transportMode == TransportMode.bus;
    final activeTheme = AppTheme.themeFor(isBus: isBus);

    return AnimatedTheme(
      data: activeTheme,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      child: Scaffold(
        body: widget.child,
        extendBody: true,

        // ── Central Transport Mode FAB ─────────────────────────────────────
        floatingActionButton: const TransportModeFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        // ── Designer Bottom Navigation Bar ─────────────────────────────────
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          padding: EdgeInsets.zero,
          height: 68,
          elevation: 10,
          color: activeTheme.colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left side: Inicio + Viajes
              _NavBarItem(
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore_rounded,
                label: 'Inicio',
                isSelected: widget.currentIndex == 0,
                onTap: () => _onTabSelected(0),
              ),
              _NavBarItem(
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
                label: 'Viajes',
                isSelected: widget.currentIndex == 1,
                onTap: () => _onTabSelected(1),
              ),

              // Center gap for FAB
              const SizedBox(width: 64),

              // Right side: Alertas + Cuenta
              _NavBarItem(
                icon: Icons.notifications_none_rounded,
                selectedIcon: Icons.notifications_active_rounded,
                label: 'Alertas',
                isSelected: widget.currentIndex == 2,
                onTap: () => _onTabSelected(2),
              ),
              _NavBarItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Cuenta',
                isSelected: widget.currentIndex == 3,
                onTap: () => _onTabSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom navigation bar item with pill highlight and spring scale animation.
class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final unselectedColor = theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    key: ValueKey(isSelected),
                    color: isSelected ? primaryColor : unselectedColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? primaryColor : unselectedColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
