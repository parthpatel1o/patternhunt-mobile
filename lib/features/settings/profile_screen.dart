import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/app_snack_bar.dart';
import '../auth/login_screen.dart';
import 'profile_widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _deleting = false;

  Future<void> _openLegal(String path) async {
    final uri = Uri.parse('${Env.siteUrl}$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showAppSnackBar(context, message: 'Could not open $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final profileAsync = ref.watch(profileProvider);

    if (session == null) {
      return const LoginScreen(nextPath: '/profile');
    }

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (profile) {
        final isDesigner = profile?.isPatternDesigner ?? false;
        final isFoundingMember = profile?.isFoundingMember ?? false;
        final displayName = (profile?.displayName?.trim().isNotEmpty ?? false)
            ? profile!.displayName!.trim()
            : null;
        final email = profile?.email;
        final initialSource = displayName ?? email ?? '?';
        final initial = initialSource.isEmpty
            ? '?'
            : initialSource.substring(0, 1).toUpperCase();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
          children: [
            ProfileIdentityCard(
              initial: initial,
              title: displayName ?? 'Your account',
              email: email,
              isDesigner: isDesigner,
              isFoundingMember: isFoundingMember,
            ),
            if (isDesigner) ...[
              const SizedBox(height: 16),
              const ProfileSectionLabel('Designer'),
              const SizedBox(height: 8),
              ProfileNavCard(
                children: [
                  ProfileNavTile(
                    icon: Icons.grid_view_rounded,
                    label: 'My patterns',
                    onTap: () => context.go('/mine'),
                  ),
                  ProfileNavTile(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    onTap: () => context.go('/insights'),
                    showDividerAbove: true,
                  ),
                  ProfileNavTile(
                    icon: Icons.add_rounded,
                    label: 'Submit a pattern',
                    onTap: () => context.go('/submit'),
                    showDividerAbove: true,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const ProfileSectionLabel('Account'),
            const SizedBox(height: 8),
            ProfileNavCard(
              children: [
                ProfileNavTile(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => context.go('/settings'),
                ),
                ProfileNavTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _openLegal('/privacy'),
                  showDividerAbove: true,
                ),
                ProfileNavTile(
                  icon: Icons.description_outlined,
                  label: 'Terms of Use',
                  onTap: () => _openLegal('/terms'),
                  showDividerAbove: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleting
                    ? null
                    : () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) context.go('/');
                      },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.foreground,
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.border),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _deleting ? null : _confirmDeleteAccount,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.destructive,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                child:
                    Text(_deleting ? 'Deleting account…' : 'Delete account'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.surface,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your Pattern Hunt account, saved boards, votes, and any patterns you submitted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(apiClientProvider).delete('/me');
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        showAppSnackBar(context, message: 'Your account has been deleted');
        context.go('/');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, message: e.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}
