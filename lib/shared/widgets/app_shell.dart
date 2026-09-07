import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;
    final isLoggedIn = session != null;
    final isDesigner = isLoggedIn && (profile?.isPatternDesigner ?? false);

    final items = <_NavItem>[
      const _NavItem(route: '/', label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
      if (isLoggedIn)
        const _NavItem(route: '/saved', label: 'Saved', icon: Icons.bookmark_outline, selectedIcon: Icons.bookmark_rounded),
      if (isLoggedIn)
        const _NavItem(route: '/mine', label: 'Mine', icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded),
      const _NavItem(route: '/profile', label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person_rounded),
      const _NavItem(route: '/settings', label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded),
    ];

    int selectedIndex = 0;
    for (var i = 0; i < items.length; i++) {
      final route = items[i].route;
      if (route == '/') {
        if (location == '/' || location.isEmpty) selectedIndex = i;
      } else if (location.startsWith(route)) {
        selectedIndex = i;
      }
    }
    if (location.startsWith('/login') || location.startsWith('/reset-password')) {
      selectedIndex = items.indexWhere((e) => e.route == '/profile');
      if (selectedIndex < 0) selectedIndex = 0;
    }

    // Keep a visible gap between the floating bar and the system gesture / nav bar.
    final bottomGap = MediaQuery.viewPaddingOf(context).bottom + 16;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 28, height: 28),
            const SizedBox(width: 4),
            const Text('Pattern Hunt'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
          if (isDesigner)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Submit',
              onPressed: () => context.go('/submit'),
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottomGap),
        child: _LiquidGlassNavBar(
          items: items,
          selectedIndex: selectedIndex.clamp(0, items.length - 1),
          onSelected: (index) => context.go(items[index].route),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// iOS-style floating liquid glass nav: heavy blur, tinted glass, specular rim.
class _LiquidGlassNavBar extends StatelessWidget {
  const _LiquidGlassNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _radius = 30.0;

  /// Rec.709 saturation boost applied after blur for a “wet glass” look.
  static const _saturation = 1.55;

  static ImageFilter get _glassFilter {
    final s = _saturation;
    final inv = 1 - s;
    // Luminance weights (Rec. 709)
    const r = 0.2126;
    const g = 0.7152;
    const b = 0.0722;
    final matrix = <double>[
      inv * r + s, inv * g, inv * b, 0, 0,
      inv * r, inv * g + s, inv * b, 0, 0,
      inv * r, inv * g, inv * b + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
    return ImageFilter.compose(
      outer: ImageFilter.blur(sigmaX: 56, sigmaY: 56, tileMode: TileMode.clamp),
      inner: ColorFilter.matrix(matrix),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useSimpleBlur = MediaQuery.highContrastOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: useSimpleBlur
              ? ImageFilter.blur(sigmaX: 24, sigmaY: 24)
              : _glassFilter,
          child: Stack(
            children: [
              // Glass body tint — translucent so blurred content shows through.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.52),
                        AppColors.primary.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.34),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              // Specular highlight along the top rim.
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                height: 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(_radius)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.75),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _GlassNavItem(
                          item: items[i],
                          selected: i == selectedIndex,
                          onTap: () => onSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
              // Glass edge stroke.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(
                        width: 1.25,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                ),
              ),
              // Soft inner bottom shade for depth.
              Positioned(
                left: 1,
                right: 1,
                bottom: 1,
                height: 14,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_radius)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavItem extends StatelessWidget {
  const _GlassNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.55) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: selected
                ? Border.all(color: Colors.white.withValues(alpha: 0.7))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryStrong.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: AppColors.accent,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: AppColors.accent,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
