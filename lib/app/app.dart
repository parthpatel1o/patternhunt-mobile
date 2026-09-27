import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/signup_welcome.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_theme.dart';
import '../shared/widgets/app_snack_bar.dart';
import 'router.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class PatternHuntApp extends ConsumerStatefulWidget {
  const PatternHuntApp({super.key});

  @override
  ConsumerState<PatternHuntApp> createState() => _PatternHuntAppState();
}

class _PatternHuntAppState extends ConsumerState<PatternHuntApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(personalStateProvider.notifier).reconcileLoaded();
    }
  }

  Future<void> _maybeShowSignupWelcome(WidgetRef ref) async {
    final inMemory = ref.read(pendingSignupWelcomeProvider);
    final persisted = await consumePendingSignupWelcome();
    if (!inMemory && !persisted) return;

    ref.read(pendingSignupWelcomeProvider.notifier).state = false;
    showAppSnackBarOn(
      scaffoldMessengerKey.currentState,
      message: 'Email confirmed — welcome to Pattern Hunt!',
    );
  }

  @override
  Widget build(BuildContext context) {
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
      title: 'Pattern Hunt',
      theme: AppTheme.light(),
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
