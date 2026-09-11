import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../features/saved/create_folder_dialog.dart';
import '../../features/search/search_overlay.dart';
import 'header_accent_button.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Stable key so search can expand from the AppBar icon bounds.
  static final searchButtonKey = GlobalKey();

  /// Branch index order must match [StatefulShellRoute] branches in router.dart.
  static const _branchByRoute = <String, int>{
    '/': 0,
    '/hunt': 1,
    '/saved': 2,
    '/mine': 3,
    '/profile': 4,
    '/submit': 5,
    '/insights': 6,
    '/settings': 7,
    '/login': 8,
    '/reset-password': 9,
  };

  static bool _isImmersive(String location) {
    return location.startsWith('/login') ||
        location.startsWith('/reset-password') ||
        location.startsWith('/hunt');
  }

  void _onTabSelected(int index, List<_NavItem> items) {
    final route = items[index].route;
    final branchIndex = _branchByRoute[route];
    if (branchIndex == null) return;
    navigationShell.goBranch(
      branchIndex,
      // Tapping the active tab returns to that tab’s root.
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.path;
    final isLoggedIn = session != null;
    final isDesigner = isLoggedIn && (profile?.isPatternDesigner ?? false);

    // Logged in:  Home | Hunt | Saved | Profile
    // Logged out: Home | Hunt | Profile
    // Designer tools (My patterns / Insights / Submit) live under Profile.
    final items = <_NavItem>[
      const _NavItem(route: '/', label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
      const _NavItem(route: '/hunt', label: 'Hunt', icon: Icons.explore_outlined, selectedIcon: Icons.explore_rounded),
      if (isLoggedIn)
        const _NavItem(route: '/saved', label: 'Saved', icon: Icons.bookmark_outline, selectedIcon: Icons.bookmark_rounded),
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
    // Designer destinations + auth surfaces highlight Profile.
    if (location.startsWith('/submit') ||
        location.startsWith('/insights') ||
        location.startsWith('/mine') ||
        location.startsWith('/login') ||
        location.startsWith('/reset-password') ||
        location.startsWith('/settings')) {
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
    final showNewFolder = isLoggedIn && location == '/saved';
    final showMineSubmit = isDesigner && location.startsWith('/mine');
    final showBackToProfile = location.startsWith('/mine') ||
        location.startsWith('/insights') ||
        location.startsWith('/submit') ||
        location.startsWith('/settings');
    final pageTitle = _titleForLocation(
      location,
      myPatternCount: location.startsWith('/mine')
          ? ref.watch(myPatternsProvider).valueOrNull?.length
          : null,
    );
    final useLargePageTitle = location.startsWith('/saved') ||
        location.startsWith('/mine') ||
        location.startsWith('/profile') ||
        location.startsWith('/settings') ||
        location.startsWith('/insights');

    final titleWidget = isHome
        ? Row(
            key: const ValueKey('title-home'),
            children: [
              Image.asset('assets/logo.png', width: 38, height: 38),
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
            key: ValueKey('title-$pageTitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: useLargePageTitle ? 22 : 17,
                  height: 1.1,
                  color: AppColors.foreground,
                ),
          );

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              leading: showBackToProfile
                  ? IconButton(
                      tooltip: 'Back to Profile',
                      onPressed: () => context.go('/profile'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  : null,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: titleWidget,
              ),
              titleSpacing: showBackToProfile ? 0 : 16,
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
                      child: HeaderAccentButton(
                        label: 'Submit',
                        icon: Icons.add_rounded,
                        tooltip: 'Submit a pattern',
                        onPressed: () => context.go('/submit'),
                      ),
                    ),
                  const SizedBox(width: 12),
                ],
                if (showNewFolder) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: HeaderAccentButton(
                      label: 'New folder',
                      icon: Icons.create_new_folder_outlined,
                      tooltip: 'New folder',
                      onPressed: () => showCreateFolderDialog(context, ref),
                    ),
                  ),
                ],
                if (showMineSubmit) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: HeaderAccentButton(
                      label: 'Submit',
                      icon: Icons.add_rounded,
                      tooltip: 'Submit a pattern',
                      onPressed: () => context.go('/submit'),
                    ),
                  ),
                ],
              ],
            ),
      body: navigationShell,
      bottomNavigationBar: hideBottomNav
          ? null
          : _BrandBottomNav(
              items: items,
              selectedIndex: selectedIndex.clamp(0, items.length - 1),
              onSelected: (index) => _onTabSelected(index, items),
            ),
    );
  }

  static String _titleForLocation(String location, {int? myPatternCount}) {
    if (location.startsWith('/hunt')) return 'Hunting Patterns';
    if (location.startsWith('/saved')) return 'Saved';
    if (location.startsWith('/mine')) {
      if (myPatternCount == null) return 'My patterns';
      return 'My patterns ($myPatternCount)';
    }
    if (location.startsWith('/profile')) return 'Profile';
    if (location.startsWith('/settings')) return 'Settings';
    if (location.startsWith('/submit')) return 'Submit a pattern';
    if (location.startsWith('/insights')) return 'Insights';
    if (location.startsWith('/search')) return 'Search';
    return 'Pattern Hunt';
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

  /// Comfortable destination width — 3 tabs get a bit more room; 4 tabs stay
  /// denser so they still fit the bar without crowding.
  static const double _maxItemWidthThree = 112;
  static const double _maxItemWidthFour = 88;
  static const double _barHeight = 64;
  static const double _sideInset = 8;

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
          height: _barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final available = (constraints.maxWidth - _sideInset * 2).clamp(0.0, double.infinity);
              final maxItemWidth =
                  items.length <= 3 ? _maxItemWidthThree : _maxItemWidthFour;
              final rowWidth = (items.length * maxItemWidth).clamp(0.0, available);

              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: rowWidth,
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
              );
            },
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
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 14 : 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.85) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    key: ValueKey(selected),
                    size: 26,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  height: 1.1,
                  letterSpacing: 0.1,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
