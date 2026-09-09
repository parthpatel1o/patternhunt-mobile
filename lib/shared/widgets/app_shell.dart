import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../features/search/search_overlay.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Stable key so search can expand from the AppBar icon bounds.
  static final searchButtonKey = GlobalKey();

  static bool _isImmersive(String location) {
    return location.startsWith('/login') ||
        location.startsWith('/reset-password') ||
        location.startsWith('/hunt');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;
    final isLoggedIn = session != null;
    final isDesigner = isLoggedIn && (profile?.isPatternDesigner ?? false);

    // Non-designer: Home | Hunt | Saved | Profile
    // Designer:     Home | Hunt | Saved | Mine | Profile
    // Logged out:   Home | Hunt | Profile
    final items = <_NavItem>[
      const _NavItem(route: '/', label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
      const _NavItem(route: '/hunt', label: 'Hunt', icon: Icons.explore_outlined, selectedIcon: Icons.explore_rounded),
      if (isLoggedIn)
        const _NavItem(route: '/saved', label: 'Saved', icon: Icons.bookmark_outline, selectedIcon: Icons.bookmark_rounded),
      if (isDesigner)
        const _NavItem(route: '/mine', label: 'Mine', icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded),
      const _NavItem(route: '/profile', label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person_rounded),
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
    if (location.startsWith('/login') ||
        location.startsWith('/reset-password') ||
        location.startsWith('/submit') ||
        location.startsWith('/settings') ||
        location.startsWith('/insights')) {
      selectedIndex = items.indexWhere((e) => e.route == '/profile');
      if (selectedIndex < 0) selectedIndex = 0;
    }

    final hideBottomNav = location.startsWith('/login') || location.startsWith('/reset-password');
    final isProfileRoute =
        location.startsWith('/profile') || location.startsWith('/settings');
    // Logged-out profile embeds LoginScreen; skip AppBar so "Profile" isn't redundant.
    final hideAppBar = _isImmersive(location) || (isProfileRoute && !isLoggedIn);
    final isHome = location == '/' || location.isEmpty;
    final showHomeActions = isHome;
    final showSubmit = showHomeActions && isDesigner && !location.startsWith('/submit');
    final pageTitle = _titleForLocation(location);

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              title: isHome
                  ? Row(
                      children: [
                        Image.asset('assets/logo.png', width: 26, height: 26),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pattern Hunt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  height: 1.1,
                                  color: AppColors.accent,
                                ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      pageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            height: 1.1,
                            color: AppColors.foreground,
                          ),
                    ),
              titleSpacing: 16,
              actions: [
                if (showHomeActions) ...[
                  _HeaderCircleButton(
                    tooltip: 'Search',
                    circleKey: searchButtonKey,
                    onPressed: () {
                      final box = searchButtonKey.currentContext?.findRenderObject() as RenderBox?;
                      Rect? origin;
                      if (box != null && box.hasSize) {
                        origin = box.localToGlobal(Offset.zero) & box.size;
                      }
                      showPatternSearch(context, origin: origin);
                    },
                    background: AppColors.card,
                    border: AppColors.border,
                    child: const Icon(Icons.search, size: 20, color: AppColors.accent),
                  ),
                  if (showSubmit)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _HeaderSubmitButton(
                        onPressed: () => context.go('/submit'),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
              ],
            ),
      body: child,
      bottomNavigationBar: hideBottomNav
          ? null
          : _BrandBottomNav(
              items: items,
              selectedIndex: selectedIndex.clamp(0, items.length - 1),
              onSelected: (index) => context.go(items[index].route),
            ),
    );
  }

  static String _titleForLocation(String location) {
    if (location.startsWith('/hunt')) return 'Hunting Patterns';
    if (location.startsWith('/saved')) return 'Saved';
    if (location.startsWith('/mine')) return 'My patterns';
    if (location.startsWith('/profile') || location.startsWith('/settings')) {
      return 'Profile';
    }
    if (location.startsWith('/submit')) return 'Submit a pattern';
    if (location.startsWith('/insights')) return 'Insights';
    if (location.startsWith('/search')) return 'Search';
    return 'Pattern Hunt';
  }
}

class _HeaderSubmitButton extends StatelessWidget {
  const _HeaderSubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New pattern',
      child: Material(
        color: AppColors.card,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            height: 36,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text(
                    'New',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.tooltip,
    required this.onPressed,
    required this.background,
    required this.child,
    this.border,
    this.circleKey,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Color background;
  final Color? border;
  final Widget child;
  final GlobalKey? circleKey;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: _size + 8, height: _size + 8),
      icon: Container(
        key: circleKey,
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: border == null ? null : Border.all(color: border!),
        ),
        child: child,
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

class _BrandBottomNav extends StatelessWidget {
  const _BrandBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BrandNavItem(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandNavItem extends StatelessWidget {
  const _BrandNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 14 : 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.85) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  height: 1.1,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
