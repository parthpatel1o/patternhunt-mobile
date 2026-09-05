import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';

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

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      if (isLoggedIn)
        const NavigationDestination(icon: Icon(Icons.bookmark_outline), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
      if (isDesigner)
        const NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Submit'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ];

    final routes = <String>[
      '/',
      if (isLoggedIn) '/saved',
      if (isDesigner) '/submit',
      '/profile',
    ];

    int selectedIndex = 0;
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i];
      if (route == '/') {
        if (location == '/' || location.isEmpty) selectedIndex = i;
      } else if (location.startsWith(route)) {
        selectedIndex = i;
      }
    }
    if (location.startsWith('/login') || location.startsWith('/reset-password')) {
      selectedIndex = routes.indexOf('/profile');
    }

    void onTap(int index) {
      context.go(routes[index]);
    }

    return Scaffold(
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
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
        onDestinationSelected: onTap,
        destinations: destinations,
      ),
    );
  }
}
