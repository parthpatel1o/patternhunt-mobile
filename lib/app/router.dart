import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/login_redirect.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_motion.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/mine/edit_pattern_screen.dart';
import '../../features/mine/mine_screen.dart';
import '../../features/hunt/hunt_screen.dart';
import '../../features/insights/insights_screen.dart';
import '../../features/profile/creator_screen.dart';
import '../../features/saved/board_detail_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/profile_screen.dart';
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

Page<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.soft,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

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
      final next = state.uri.queryParameters['next'];
      if (recovery && state.matchedLocation != '/reset-password') {
        return '/reset-password';
      }
      if (session == null &&
          (['/submit', '/saved', '/mine', '/insights', '/settings'].contains(state.matchedLocation) ||
              state.matchedLocation.startsWith('/mine/') ||
              state.matchedLocation.startsWith('/saved/'))) {
        return loginLocation(next: state.uri.toString());
      }
      if (session != null &&
          (state.matchedLocation == '/insights' ||
              state.matchedLocation == '/mine' ||
              state.matchedLocation.startsWith('/mine/'))) {
        final profileAsync = ref.read(profileProvider);
        if (profileAsync.isLoading) return null;
        if (profileAsync.valueOrNull != null && !profileAsync.valueOrNull!.isPatternDesigner) {
          return '/profile';
        }
      }
      if (session != null && loggingIn && !recovery) {
        final safeNext = safeInternalPath(next);
        return safeNext ?? '/';
      }
      return null;
    },
    routes: [
      // Indexed stack keeps tab screens mounted so switches stay smooth.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) {
                  final q = state.uri.queryParameters['q'];
                  final patternId = state.uri.queryParameters['pattern'];
                  final category = state.uri.queryParameters['category'];
                  final period = state.uri.queryParameters['period'];
                  final free = state.uri.queryParameters['free'];
                  final freeOnly = free == '1' || free == 'true';
                  return _fadePage(
                    key: state.pageKey,
                    child: HomeScreen(
                      key: ValueKey(
                        'home-${q ?? ''}-${patternId ?? ''}-${category ?? ''}-${period ?? ''}-${freeOnly ? 'free' : 'all'}',
                      ),
                      initialQuery: q,
                      focusPatternId: patternId,
                      initialCategory: category,
                      initialPeriod: period,
                      initialFreeOnly: freeOnly,
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hunt',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const HuntScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/saved',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const SavedScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mine',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const MineScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/submit',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const SubmitScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const InsightsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const SettingsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/login',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: LoginScreen(
                    nextPath: state.uri.queryParameters['next'],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reset-password',
                pageBuilder: (context, state) => _fadePage(
                  key: state.pageKey,
                  child: const ResetPasswordScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(
        path: '/mine/:id/edit',
        builder: (context, state) => EditPatternScreen(patternId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/saved/:boardId',
        builder: (context, state) => BoardDetailScreen(boardId: state.pathParameters['boardId']!),
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
