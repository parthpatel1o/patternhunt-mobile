import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/mine/edit_pattern_screen.dart';
import '../../features/mine/mine_screen.dart';
import '../../features/pattern/pattern_detail_screen.dart';
import '../../features/profile/creator_screen.dart';
import '../../features/saved/board_detail_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/submit/submit_screen.dart';
import '../../shared/widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Notifies GoRouter when auth changes without recreating the router instance.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final notifier = _RouterRefresh();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loggingIn = state.matchedLocation == '/login';
      final recovery = ref.read(passwordRecoveryProvider);
      if (recovery && state.matchedLocation != '/reset-password') {
        return '/reset-password';
      }
      if (session == null &&
          (['/submit', '/saved', '/profile', '/mine'].contains(state.matchedLocation) ||
              state.matchedLocation.startsWith('/mine/'))) {
        return '/login';
      }
      if (session != null && state.matchedLocation == '/submit') {
        final profileAsync = ref.read(profileProvider);
        if (profileAsync.isLoading) return null;
        if (profileAsync.valueOrNull != null && !profileAsync.valueOrNull!.isPatternDesigner) {
          return '/profile';
        }
      }
      if (session != null && loggingIn && !recovery) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),
          GoRoute(path: '/submit', builder: (context, state) => const SubmitScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const SettingsScreen()),
          GoRoute(path: '/settings', redirect: (context, _) => '/profile'),
          GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
          GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
        ],
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/mine', builder: (context, state) => const MineScreen()),
      GoRoute(
        path: '/mine/:id/edit',
        builder: (context, state) => EditPatternScreen(patternId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/saved/:boardId',
        builder: (context, state) => BoardDetailScreen(boardId: state.pathParameters['boardId']!),
      ),
      GoRoute(
        path: '/pattern/:id',
        builder: (context, state) => PatternDetailScreen(patternId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/creator/:slug',
        builder: (context, state) => CreatorScreen(slug: state.pathParameters['slug']!),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
