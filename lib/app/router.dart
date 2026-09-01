import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/mine/mine_screen.dart';
import '../../features/pattern/pattern_detail_screen.dart';
import '../../features/profile/creator_screen.dart';
import '../../features/saved/board_detail_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/submit/submit_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  return GoRouter(
    initialLocation: '/',
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
        ],
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/mine', builder: (context, state) => const MineScreen()),
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
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final profile = ref.read(profileProvider).valueOrNull;
      if (session == null && ['/submit', '/saved', '/profile', '/mine'].contains(state.matchedLocation)) {
        return '/login';
      }
      if (session != null && state.matchedLocation == '/submit' && profile != null && !profile.isPatternDesigner) {
        return '/profile';
      }
      if (session != null && loggingIn) return '/';
      return null;
    },
  );
});
