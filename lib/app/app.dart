import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/providers/providers.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class PatternHuntApp extends ConsumerWidget {
  const PatternHuntApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    ref.listen(authStateProvider, (previous, next) {
      next.whenData((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          ref.read(passwordRecoveryProvider.notifier).state = true;
          router.go('/reset-password');
        }
      });
    });

    return MaterialApp.router(
      title: 'PatternHunt',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
