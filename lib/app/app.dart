import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/auth/signup_welcome.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PatternHuntApp extends ConsumerWidget {
  const PatternHuntApp({super.key});

  Future<void> _maybeShowSignupWelcome(WidgetRef ref) async {
    final inMemory = ref.read(pendingSignupWelcomeProvider);
    final persisted = await consumePendingSignupWelcome();
    if (!inMemory && !persisted) return;

    ref.read(pendingSignupWelcomeProvider.notifier).state = false;
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Email confirmed — welcome to PatternHunt!')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (previous, next) {
      next.whenData((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          ref.read(passwordRecoveryProvider.notifier).state = true;
          router.go('/reset-password');
          return;
        }
        if (state.event == AuthChangeEvent.signedIn && state.session != null) {
          _maybeShowSignupWelcome(ref);
        }
      });
    });

    return MaterialApp.router(
      title: 'PatternHunt',
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
